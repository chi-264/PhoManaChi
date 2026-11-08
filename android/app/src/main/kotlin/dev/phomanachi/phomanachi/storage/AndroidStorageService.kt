package dev.phomanachi.phomanachi.storage

import android.Manifest
import android.app.Activity
import android.app.RecoverableSecurityException
import android.content.Intent
import android.content.IntentSender
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.os.StatFs
import android.os.SystemClock
import android.provider.DocumentsContract
import android.provider.MediaStore
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import org.json.JSONArray
import org.json.JSONObject
import java.util.UUID
import java.util.concurrent.CancellationException
import java.util.concurrent.atomic.AtomicBoolean

/** One session/job at a time. Opaque native IDs and expiring reviews bound every delete. */
class AndroidStorageService(private val activity: Activity, private val changed: () -> Unit) : StorageHostApi {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
    private val access = StorageAccess(activity)
    private val lock = Any()
    private val busy = AtomicBoolean(false)
    private val canceled = AtomicBoolean(false)
    private val prefs = activity.getSharedPreferences("storage_results", Activity.MODE_PRIVATE)
    private val entries = linkedMapOf<String, StorageAccess.Entry>()
    private val groups = linkedMapOf<String, Set<String>>()
    private var permission: CompletableDeferred<Boolean>? = null
    private var authorization: CompletableDeferred<Boolean>? = null
    private var previousPhase = ScanPhase.IDLE
    private var picker = 0
    private var lastScan: (() -> Unit)? = null
    private var review: Review? = null
    private data class Review(val value: CleanupReview, val hashes: Map<String, String>, val expiresElapsed: Long)
    private var state = StorageSnapshot(1, null, ScanPhase.IDLE, "No access selected", System.currentTimeMillis(),
        emptyList(), 0, 0, 0, emptyList(), null, false, false, restoreReport())

    private fun update(block: (StorageSnapshot) -> StorageSnapshot) { synchronized(lock) { state = block(state) } }
    private fun notifyState() { scope.launch { changed() } }
    private fun checkCanceled() { if (canceled.get()) throw CancellationException("Operation canceled") }
    override suspend fun getState(): StorageSnapshot = synchronized(lock) { state.copy(busy = busy.get()) }
    private fun message(text: String) { update { it.copy(message = text) }; notifyState() }
    private fun issue(text: String, failed: Boolean = false) { update { it.copy(
        issues = (it.issues + text).distinct().take(20),
        failedFiles = it.failedFiles + if (failed) 1 else 0,
        warningCount = it.warningCount + if (failed) 0 else 1) } }

    private fun reserve(): Boolean {
        if (review != null) { message("Close the cleanup review before starting another operation."); return false }
        if (!busy.compareAndSet(false, true)) return false
        canceled.set(false)
        return true
    }

    private fun choose(folder: Boolean): StorageSnapshot {
        if (!reserve()) return synchronized(lock) { state.copy(busy = busy.get()) }
        previousPhase = state.phase
        picker = if (folder) 61001 else 61002
        update { it.copy(phase = ScanPhase.CHOOSING, message = "Choose the access you want to scan.") }
        try {
            val intent = Intent(if (folder) Intent.ACTION_OPEN_DOCUMENT_TREE else Intent.ACTION_OPEN_DOCUMENT)
                .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
                .putExtra(Intent.EXTRA_LOCAL_ONLY, true)
            if (!folder) intent.addCategory(Intent.CATEGORY_OPENABLE).setType("*/*").putExtra(Intent.EXTRA_ALLOW_MULTIPLE, true)
            activity.startActivityForResult(intent, picker)
        } catch (_: Exception) { busy.set(false); update { it.copy(phase = previousPhase, message = "Android's picker is unavailable. No files were changed.") } }
        return synchronized(lock) { state.copy(busy = busy.get()) }
    }
    override suspend fun chooseFolder() = choose(true)
    override suspend fun chooseFiles() = choose(false)
    override suspend fun rescan(): StorageSnapshot {
        val scan = lastScan
        if (scan == null) { message("Choose a folder, files, or media access first."); return getState() }
        if (reserve()) scan()
        return getState()
    }

    override suspend fun scanMedia(): StorageSnapshot {
        if (!reserve()) return getState()
        previousPhase = state.phase
        update { it.copy(phase = ScanPhase.CHOOSING, message = "Checking media access.") }
        val wanted = if (Build.VERSION.SDK_INT >= 33) listOf(Manifest.permission.READ_MEDIA_IMAGES,
            Manifest.permission.READ_MEDIA_VIDEO, Manifest.permission.READ_MEDIA_AUDIO) +
            if (Build.VERSION.SDK_INT >= 34) listOf(Manifest.permission.READ_MEDIA_VISUAL_USER_SELECTED) else emptyList()
            else listOf(Manifest.permission.READ_EXTERNAL_STORAGE)
        val missing = wanted.filter { activity.checkSelfPermission(it) != PackageManager.PERMISSION_GRANTED }
        if (missing.isEmpty()) beginScan("Accessible media library") { emit, issue, check -> access.media(emit, issue, check) }
        else {
            permission = CompletableDeferred()
            try {
                activity.requestPermissions(missing.toTypedArray(), 61003)
                scope.launch {
                    permission?.await()
                    permission = null
                    if (canceled.get()) finishPickerCanceled()
                    else if (access.hasMediaAccess()) beginScan("Accessible media library") { emit, issue, check -> access.media(emit, issue, check) }
                    else { busy.set(false); update { it.copy(phase = previousPhase, message = "Media access was not granted. Previous results were retained. Choose files or a folder instead.") }; notifyState() }
                }
            } catch (_: Exception) { permission = null; busy.set(false); update { it.copy(phase = previousPhase, message = "Media access could not be requested. Choose files or a folder instead.") } }
        }
        return getState()
    }

    private fun finishPickerCanceled() {
        picker = 0
        busy.set(false)
        update { it.copy(phase = previousPhase, message = "Selection canceled. Previous scan results were retained.") }
        notifyState()
    }

    fun onPermissionResult(code: Int) {
        if (code == 61003) permission?.complete(true)
        if (code == 61004) authorization?.complete(activity.checkSelfPermission(Manifest.permission.WRITE_EXTERNAL_STORAGE) == PackageManager.PERMISSION_GRANTED)
    }

    fun onActivityResult(code: Int, result: Int, data: Intent?) {
        if (code == 61005) { authorization?.complete(result == Activity.RESULT_OK); return }
        if (code != picker || picker == 0) return
        val chosen = picker
        picker = 0
        if (result != Activity.RESULT_OK || data == null || canceled.get()) { finishPickerCanceled(); return }
        if (chosen == 61001) {
            val uri = data.data ?: run { finishPickerCanceled(); return }
            beginScan("Selected folder") { emit, issue, check -> access.tree(uri, emit, issue, check) }
        } else {
            val uris = mutableListOf<Uri>()
            data.data?.let { uris.add(it) }
            data.clipData?.let { clip -> for (i in 0 until minOf(clip.itemCount, StoragePolicy.MAX_FILES + 1)) uris.add(clip.getItemAt(i).uri) }
            if (uris.isEmpty()) { finishPickerCanceled(); return }
            val truncated = (data.clipData?.itemCount ?: 0) > StoragePolicy.MAX_FILES + 1
            beginScan("Selected files") { emit, issue, check ->
                if (truncated) issue("Selection exceeded the scan limit. Some chosen files were not enumerated; choose fewer files.")
                access.selected(uris, emit, issue, check)
            }
        }
    }

    private fun beginScan(label: String, enumerate: ((StorageAccess.Entry) -> Boolean, (String) -> Unit, () -> Unit) -> Unit) {
        lastScan = { beginScan(label, enumerate) }
        val job = UUID.randomUUID().toString()
        synchronized(lock) {
            entries.clear(); groups.clear(); review = null
            state = StorageSnapshot(1, job, ScanPhase.SCANNING, label, System.currentTimeMillis(), emptyList(), 0, 0, 0, emptyList(), null, true, false, state.cleanup)
        }
        notifyState()
        scope.launch(Dispatchers.IO) {
            val seen = hashSetOf<String>()
            try {
                enumerate({ entry ->
                    checkCanceled()
                    val key = if (entry.document) "${entry.uri.authority}:${DocumentsContract.getDocumentId(entry.uri)}" else entry.uri.toString()
                    if (!seen.add(key)) true
                    else if (entries.size >= StoragePolicy.MAX_FILES) { issue("Scan limit of ${StoragePolicy.MAX_FILES} files reached. Choose a narrower scope."); false }
                    else {
                        synchronized(lock) { entries[entry.id] = entry }
                        if (entries.size % 32 == 0) publishFiles()
                        true
                    }
                }, { issue(it) }, ::checkCanceled)
                publishFiles()
                checkCanceled()
                update { it.copy(phase = ScanPhase.HASHING, message = "Comparing same-size files with SHA-256.") }
                notifyState()
                val candidateIds = StoragePolicy.candidateIds(entries.mapValues { it.value.meta.identity.size })
                val candidates = entries.values.filter { it.id in candidateIds && it.meta.identity.modified != null }
                for (entry in candidates) {
                    checkCanceled()
                    try {
                        entry.hash = access.hash(entry, canceled::get)
                        update { it.copy(hashedFiles = it.hashedFiles + 1) }
                    } catch (e: Exception) {
                        checkCanceled()
                        entry.view = entry.view.copy(deleteSupported = false, deleteReason = "File changed or could not be read. Rescan before cleanup.")
                        issue("A same-size file could not be verified and was excluded from duplicate groups.", true)
                    }
                }
                val matching = StoragePolicy.duplicateGroups(entries.mapValues { it.value.meta.identity.size to it.value.hash })
                synchronized(lock) {
                    matching.forEachIndexed { index, ids ->
                        val group = (index + 1).toString()
                        groups[group] = ids
                        ids.forEach { id -> entries[id]?.let { it.view = it.view.copy(duplicateGroup = group) } }
                    }
                }
                publishFiles()
                update { it.copy(phase = when { it.files.isEmpty() && it.failedFiles + it.warningCount > 0 -> ScanPhase.FAILED; it.failedFiles + it.warningCount > 0 -> ScanPhase.PARTIAL; else -> ScanPhase.COMPLETED },
                    message = "Scan finished. No files were deleted.", observedAtMillis = System.currentTimeMillis()) }
            } catch (_: CancellationException) {
                publishFiles(); update { it.copy(phase = ScanPhase.CANCELED, message = "Scan canceled. Partial results are read-only; rescan before cleanup.") }
            } catch (_: Exception) {
                publishFiles(); update { it.copy(phase = ScanPhase.FAILED, message = "This storage scope could not be scanned. Access may be denied or revoked. Choose access again.") }
            } finally { busy.set(false); notifyState() }
        }
    }

    private fun publishFiles() { synchronized(lock) { state = state.copy(files = entries.values.map { it.view }) } }

    override suspend fun cancelOperation(): StorageSnapshot {
        canceled.set(true)
        scope.launch(Dispatchers.IO) { access.cancelRead() }
        authorization?.complete(false)
        permission?.complete(false)
        if (picker != 0) message("Cancel requested. Close Android's picker to return; no scan will start.")
        else message("Stopping at the next safe boundary. Files already verified as deleted remain reported.")
        return getState()
    }

    override suspend fun prepareCleanup(jobId: String, fileIds: List<String>): CleanupReview {
        check(reserve()) { "An operation or review is already active." }
        try {
            return withContext(Dispatchers.IO) {
                check(state.phase == ScanPhase.COMPLETED || state.phase == ScanPhase.PARTIAL) { "Complete a fresh scan before cleanup." }
                check(!state.requiresRescan) { "Rescan before another cleanup review." }
                StoragePolicy.validateSelection(state.jobId, jobId, fileIds, entries.keys, groups)
                val chosen = fileIds.map { requireNotNull(entries[it]) }
                check(chosen.all { it.view.deleteSupported }) { "A selected file does not support safe deletion. Refresh the scan." }
                val preparing = CleanupReport(UUID.randomUUID().toString(), System.currentTimeMillis(), CleanupPhase.PREPARING, chosen.size.toLong(), 0, 0, 0, 0, 0, null, null, emptyList(), "Checking the exact selected files and retained copies.")
                update { it.copy(cleanup = preparing, message = null) }; notifyState()
                val hashes = mutableMapOf<String, String>()
                for (entry in chosen) {
                    checkCanceled()
                    val hash = access.hash(entry, canceled::get)
                    check(entry.hash == null || entry.hash == hash) { "A duplicate changed since scanning. Rescan before cleanup." }
                    hashes[entry.id] = hash
                }
                for (group in chosen.mapNotNull { it.view.duplicateGroup }.distinct()) {
                    checkCanceled()
                    val keepers = groups[group].orEmpty() - fileIds.toSet()
                    check(keepers.any { id ->
                        try { val e = requireNotNull(entries[id]); val hash = access.hash(e, canceled::get); if (hash == e.hash) { hashes[id] = hash; true } else false }
                        catch (e: Exception) { checkCanceled(); false }
                    }) { "A retained duplicate copy is no longer verifiable. Rescan before cleanup." }
                }
                checkCanceled()
                val value = CleanupReview(UUID.randomUUID().toString(), jobId, System.currentTimeMillis() + StoragePolicy.REVIEW_LIFETIME_MS,
                    chosen.map { it.view }, chosen.sumOf { requireNotNull(it.meta.identity.size) })
                review = Review(value, hashes, SystemClock.elapsedRealtime() + StoragePolicy.REVIEW_LIFETIME_MS)
                update { it.copy(cleanup = preparing.copy(phase = CleanupPhase.IDLE, message = "Review prepared. Nothing has been deleted.")) }
                value
            }
        } catch (error: Exception) {
            update { it.copy(cleanup = it.cleanup?.copy(phase = if (canceled.get()) CleanupPhase.CANCELED else CleanupPhase.FAILED,
                message = "Review could not be completed. Nothing was deleted. Rescan if access or files changed.")) }
            throw error
        } finally { busy.set(false); notifyState() }
    }

    override suspend fun discardReview(reviewId: String): StorageSnapshot {
        if (review?.value?.reviewId == reviewId && !busy.get()) review = null
        return getState()
    }

    override suspend fun confirmCleanup(reviewId: String): StorageSnapshot {
        val prepared = review ?: throw IllegalStateException("No cleanup review is active.")
        check(prepared.value.reviewId == reviewId && prepared.value.jobId == state.jobId) { "Review does not match the current scan." }
        if (SystemClock.elapsedRealtime() > prepared.expiresElapsed) { review = null; throw IllegalStateException("Review expired. Review these files again.") }
        check(busy.compareAndSet(false, true)) { "Another operation is active." }
        review = null // One-use token: repeat calls cannot delete again.
        canceled.set(false)
        scope.launch(Dispatchers.IO) { cleanup(prepared) }
        return getState()
    }

    private fun freeBytes(): Long? = runCatching { StatFs(Environment.getDataDirectory().absolutePath).availableBytes }.getOrNull()

    private suspend fun authorize(sender: IntentSender): Boolean {
        checkCanceled()
        update { it.copy(cleanup = it.cleanup?.copy(phase = CleanupPhase.AWAITING_AUTHORIZATION, message = "Confirm access in Android. Files will be rechecked after returning.")) }
        notifyState()
        val answer = CompletableDeferred<Boolean>()
        withContext(Dispatchers.Main) {
            authorization = answer
            try { activity.startIntentSenderForResult(sender, 61005, null, 0, 0, 0) }
            catch (_: Exception) { answer.complete(false) }
        }
        return try { answer.await() } finally { authorization = null }
    }

    private suspend fun legacyWrite(): Boolean {
        if (Build.VERSION.SDK_INT != 28 || activity.checkSelfPermission(Manifest.permission.WRITE_EXTERNAL_STORAGE) == PackageManager.PERMISSION_GRANTED) return true
        val answer = CompletableDeferred<Boolean>()
        update { it.copy(cleanup = it.cleanup?.copy(phase = CleanupPhase.AWAITING_AUTHORIZATION, message = "Android 9 requires write access for selected media deletion.")) }
        withContext(Dispatchers.Main) { authorization = answer; activity.requestPermissions(arrayOf(Manifest.permission.WRITE_EXTERNAL_STORAGE), 61004) }
        return try { answer.await() } finally { authorization = null }
    }

    private fun validRetainer(entry: StorageAccess.Entry, prepared: Review): Boolean {
        val group = entry.view.duplicateGroup ?: return true
        return groups[group].orEmpty().any { id ->
            if (prepared.value.files.any { it.id == id }) false
            else try { val e = requireNotNull(entries[id]); access.hash(e, canceled::get) == prepared.hashes[id] && prepared.hashes[id] != null }
                catch (error: Exception) { checkCanceled(); false }
        }
    }

    private fun verify(entry: StorageAccess.Entry, prepared: Review) {
        checkCanceled()
        check(validRetainer(entry, prepared)) { "Retained duplicate copy changed or is unavailable." }
        val fresh = access.read(entry.uri, entry.document, entry.meta.location) ?: throw IllegalStateException("File is no longer available.")
        check(access.entry(entry.uri, entry.document, fresh).view.deleteSupported) { "Delete access is no longer available." }
        check(access.hash(entry, canceled::get) == prepared.hashes[entry.id]) { "File content changed after review." }
    }

    private fun delete(entry: StorageAccess.Entry): Boolean = if (entry.document)
        DocumentsContract.deleteDocument(activity.contentResolver, entry.uri)
        else activity.contentResolver.delete(entry.uri, null, null) == 1

    private suspend fun cleanup(prepared: Review) {
        val chosen = prepared.value.files.map { requireNotNull(entries[it.id]) }
        var report = CleanupReport(UUID.randomUUID().toString(), System.currentTimeMillis(), CleanupPhase.DELETING, chosen.size.toLong(), 0, 0, 0, 0, 0, freeBytes(), null, emptyList(), "Deletion is in progress. Each result is checked separately.")
        fun publish() { update { it.copy(cleanup = report) }; persist(report); notifyState() }
        publish()
        try {
            val media = chosen.filter { !it.document }
            if (media.isNotEmpty()) {
                val granted = if (Build.VERSION.SDK_INT >= 30) authorize(MediaStore.createWriteRequest(activity.contentResolver, media.map { it.uri }).intentSender) else legacyWrite()
                if (!granted) { canceled.set(true); throw CancellationException("Android authorization canceled") }
            }
            for (entry in chosen) {
                checkCanceled()
                var outcome: String
                var detail: String
                var attempted = false
                try {
                    verify(entry, prepared)
                    checkCanceled()
                    val deleted = try { attempted = true; delete(entry) } catch (error: SecurityException) {
                        if (Build.VERSION.SDK_INT == 29 && error is RecoverableSecurityException) {
                            attempted = false
                            if (!authorize(error.userAction.actionIntent.intentSender)) { canceled.set(true); throw CancellationException("Android authorization canceled") }
                            verify(entry, prepared)
                            checkCanceled()
                            attempted = true
                            delete(entry)
                        } else throw error
                    }
                    val absent = runCatching { access.read(entry.uri, entry.document, entry.meta.location) == null }.getOrNull()
                    outcome = StoragePolicy.outcome(deleted, absent)
                    detail = when(outcome) { "deleted" -> "Provider confirmed deletion and the file is no longer returned."; "failed" -> "Provider did not delete this file."; else -> "Deletion or absence could not be verified. Rescan before any retry." }
                } catch (error: CancellationException) { throw error }
                catch (_: IllegalStateException) { outcome = if (attempted) "unverified" else "skipped"; detail = if (attempted) "Provider returned an ambiguous result after deletion was requested. Rescan before retrying." else "Identity, content, access, or retained-copy checks changed. File was not deleted by this attempt." }
                catch (_: Exception) { outcome = if (attempted) "unverified" else "failed"; detail = "Provider access or deletion could not be verified. Choose access again and rescan before retrying." }
                report = report.copy(phase = CleanupPhase.DELETING,
                    deleted = report.deleted + if (outcome == "deleted") 1 else 0,
                    skipped = report.skipped + if (outcome == "skipped") 1 else 0,
                    failed = report.failed + if (outcome == "failed") 1 else 0,
                    unverified = report.unverified + if (outcome == "unverified") 1 else 0,
                    deletedBytes = report.deletedBytes + if (outcome == "deleted") requireNotNull(entry.meta.identity.size) else 0,
                    items = report.items + CleanupItem(entry.id, entry.view.name, outcome, detail))
                if (outcome == "deleted") synchronized(lock) { entries.remove(entry.id) }
                publishFiles(); publish()
            }
            report = report.copy(phase = when { report.deleted == report.requested -> CleanupPhase.COMPLETED; report.deleted > 0 -> CleanupPhase.PARTIAL; else -> CleanupPhase.FAILED }, message = "Cleanup finished. Only verified deletions count toward deleted bytes.")
        } catch (_: CancellationException) {
            val remaining = chosen.filter { entry -> report.items.none { it.fileId == entry.id } }
            report = report.copy(phase = CleanupPhase.CANCELED, skipped = report.skipped + remaining.size,
                items = report.items + remaining.map { CleanupItem(it.id, it.view.name, "skipped", "Canceled before deletion was requested for this file.") },
                message = "Cleanup canceled. Remaining files were not requested for deletion; already verified results are retained.")
        } catch (_: Exception) {
            val remaining = chosen.filter { entry -> report.items.none { it.fileId == entry.id } }
            report = report.copy(phase = CleanupPhase.FAILED, failed = report.failed + remaining.size,
                items = report.items + remaining.map { CleanupItem(it.id, it.view.name, "failed", "Cleanup stopped before deletion was requested for this file.") },
                message = "Cleanup could not continue. Review the confirmed results and rescan before retrying.")
        } finally {
            report = report.copy(internalFreeAfter = freeBytes())
            update { it.copy(requiresRescan = true) }
            publish(); busy.set(false); notifyState()
        }
    }

    override suspend fun forgetScan(): StorageSnapshot {
        check(!busy.get()) { "Stop the current operation first." }
        review = null
        lastScan = null
        synchronized(lock) { entries.clear(); groups.clear(); state = state.copy(jobId = null, phase = ScanPhase.IDLE,
            scopeLabel = "No access selected", files = emptyList(), hashedFiles = 0, failedFiles = 0, warningCount = 0,
            issues = emptyList(), requiresRescan = false, message = "Scan results cleared. No files were deleted.") }
        return getState()
    }

    private fun persist(r: CleanupReport) {
        prefs.edit().putString("report", JSONObject().put("id", r.operationId).put("phase", r.phase.name)
            .put("time", r.startedAtMillis)
            .put("requested", r.requested).put("deleted", r.deleted).put("skipped", r.skipped).put("failed", r.failed)
            .put("unverified", r.unverified).put("bytes", r.deletedBytes).put("before", r.internalFreeBefore)
            .put("after", r.internalFreeAfter).put("message", r.message)
            .put("items", JSONArray().also { array -> r.items.forEach { array.put(JSONObject().put("id", it.fileId).put("name", it.name).put("outcome", it.outcome).put("message", it.message)) } }).toString()).apply()
    }

    private fun restoreReport(): CleanupReport? = runCatching {
        val raw = prefs.getString("report", null) ?: return@runCatching null
        val json = JSONObject(raw)
        val phase = CleanupPhase.valueOf(json.getString("phase"))
        val interrupted = phase in listOf(CleanupPhase.DELETING, CleanupPhase.AWAITING_AUTHORIZATION, CleanupPhase.PREPARING)
        val items = json.optJSONArray("items") ?: JSONArray()
        CleanupReport(json.getString("id"), json.optLong("time", 0), if (interrupted) CleanupPhase.INTERRUPTED else phase, json.getLong("requested"),
            json.getLong("deleted"), json.getLong("skipped"), json.getLong("failed"),
            json.getLong("unverified") + if (interrupted) json.getLong("requested") - items.length() else 0,
            json.getLong("bytes"), if (json.has("before")) json.getLong("before") else null,
            if (json.has("after")) json.getLong("after") else null,
            (0 until items.length()).map { val x = items.getJSONObject(it); CleanupItem(x.getString("id"), x.getString("name"), x.getString("outcome"), x.getString("message")) },
            if (interrupted) "Previous cleanup was interrupted. Only recorded confirmations are counted; remaining outcomes are unverified. Nothing will resume automatically." else json.getString("message"))
    }.getOrNull()

    fun dispose() { canceled.set(true); access.cancelRead(); authorization?.complete(false); permission?.complete(false); scope.cancel() }
}
