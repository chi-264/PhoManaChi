package dev.phomanachi.phomanachi.storage

import android.Manifest
import android.content.ContentUris
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.database.Cursor
import android.net.Uri
import android.os.Build
import android.os.CancellationSignal
import android.os.ParcelFileDescriptor
import android.os.Process
import android.provider.DocumentsContract
import android.provider.MediaStore
import java.io.Closeable
import java.io.FileNotFoundException
import java.io.IOException
import java.util.UUID
import java.util.concurrent.atomic.AtomicReference

/** All URIs originate from Android's picker or MediaStore, never from Dart arguments. */
class StorageAccess(private val context: Context) {
    data class Meta(val identity: StoragePolicy.Identity, val flags: Int, val directory: Boolean, val location: String)
    data class Entry(val id: String, val uri: Uri, val document: Boolean, val meta: Meta,
        var view: StorageFile, var hash: String? = null)
    private val resolver get() = context.contentResolver
    private val active = AtomicReference<Closeable?>()
    private val signal = AtomicReference<CancellationSignal?>()

    fun cancelRead() { runCatching { signal.get()?.cancel() }; runCatching { active.get()?.close() } }
    private fun Cursor.text(name: String): String? = getColumnIndex(name).takeIf { it >= 0 && !isNull(it) }?.let { getString(it) }
    private fun Cursor.number(name: String): Long? = getColumnIndex(name).takeIf { it >= 0 && !isNull(it) }?.let { getLong(it) }

    private fun <T> query(uri: Uri, columns: Array<String>, block: (Cursor) -> T): T {
        val cancellation = CancellationSignal()
        signal.set(cancellation)
        try { return (resolver.query(uri, columns, null, null, null, cancellation)
            ?: throw IOException("Provider returned no cursor")).use(block)
        } finally { signal.compareAndSet(cancellation, null) }
    }

    private val documentColumns = arrayOf(DocumentsContract.Document.COLUMN_DOCUMENT_ID,
        DocumentsContract.Document.COLUMN_DISPLAY_NAME, DocumentsContract.Document.COLUMN_MIME_TYPE,
        DocumentsContract.Document.COLUMN_SIZE, DocumentsContract.Document.COLUMN_LAST_MODIFIED, DocumentsContract.Document.COLUMN_FLAGS)

    private fun documentMeta(uri: Uri, cursor: Cursor, location: String): Meta {
        val id = cursor.text(DocumentsContract.Document.COLUMN_DOCUMENT_ID) ?: throw IOException("Missing document identity")
        val name = cursor.text(DocumentsContract.Document.COLUMN_DISPLAY_NAME) ?: throw IOException("Missing file name")
        val mime = cursor.text(DocumentsContract.Document.COLUMN_MIME_TYPE) ?: "application/octet-stream"
        require(!StoragePolicy.protectedPath(id)) { "Protected application-data location" }
        return Meta(StoragePolicy.Identity(uri.toString(), name, mime,
            cursor.number(DocumentsContract.Document.COLUMN_SIZE)?.takeIf { it >= 0 },
            cursor.number(DocumentsContract.Document.COLUMN_LAST_MODIFIED)?.takeIf { it > 0 }),
            cursor.number(DocumentsContract.Document.COLUMN_FLAGS)?.toInt() ?: 0,
            mime == DocumentsContract.Document.MIME_TYPE_DIR, location)
    }

    fun read(uri: Uri, document: Boolean, location: String): Meta? = try {
        if (document) query(uri, documentColumns) { c -> if (c.moveToFirst()) documentMeta(uri, c, location) else null }
        else query(uri, mediaColumns()) { c -> if (c.moveToFirst()) mediaMeta(uri, c) else null }
    } catch (_: FileNotFoundException) { null }

    fun entry(uri: Uri, document: Boolean, meta: Meta): Entry {
        require(uri.scheme == "content" && !meta.directory)
        val reason = when {
            meta.identity.size == null || meta.identity.modified == null -> "File identity metadata is incomplete."
            document && (meta.flags and DocumentsContract.Document.FLAG_PARTIAL != 0) -> "Partially downloaded documents are read-only in this scan."
            document && (meta.flags and DocumentsContract.Document.FLAG_VIRTUAL_DOCUMENT != 0) -> "Virtual documents are read-only in this scan."
            document && (meta.flags and DocumentsContract.Document.FLAG_SUPPORTS_DELETE == 0) -> "This provider does not support deleting this file."
            document && context.checkUriPermission(uri, Process.myPid(), Process.myUid(), Intent.FLAG_GRANT_WRITE_URI_PERMISSION) != PackageManager.PERMISSION_GRANTED -> "The selected access is read-only. Choose a folder or files with write access."
            else -> "The file will be checked again before deletion."
        }
        val supported = reason == "The file will be checked again before deletion."
        val id = UUID.randomUUID().toString()
        return Entry(id, uri, document, meta, StorageFile(id, meta.identity.name, meta.identity.mime,
            StoragePolicy.category(meta.identity.mime, meta.identity.name), meta.location,
            meta.identity.size, meta.identity.modified, supported, reason, null))
    }

    fun selected(uris: List<Uri>, emit: (Entry) -> Boolean, issue: (String) -> Unit, check: () -> Unit) {
        val seen = hashSetOf<String>()
        for (uri in uris) {
            check()
            if (!seen.add(uri.toString())) continue
            try {
                require(uri.scheme == "content" && DocumentsContract.isDocumentUri(context, uri)) { "Unsupported document provider" }
                val meta = read(uri, true, "Selected files · ${uri.authority}") ?: throw IOException("File unavailable")
                if (!emit(entry(uri, true, meta))) return
            } catch (e: Exception) { check(); issue("A selected document could not be read or is protected.") }
        }
    }

    fun tree(tree: Uri, emit: (Entry) -> Boolean, issue: (String) -> Unit, check: () -> Unit) {
        require(tree.scheme == "content" && DocumentsContract.isTreeUri(tree))
        val rootId = DocumentsContract.getTreeDocumentId(tree)
        require(!StoragePolicy.protectedPath(rootId)) { "Protected application-data folder" }
        val root = DocumentsContract.buildDocumentUriUsingTree(tree, rootId)
        val label = read(root, true, "Selected folder")?.identity?.name ?: "Selected folder"
        val queue = ArrayDeque<Triple<String, String, Int>>()
        queue.add(Triple(rootId, label, 0))
        val visited = hashSetOf<String>()
        while (queue.isNotEmpty()) {
            check()
            val (id, path, depth) = queue.removeFirst()
            if (!visited.add(id)) continue
            if (visited.size > StoragePolicy.MAX_DIRECTORIES || depth > StoragePolicy.MAX_DEPTH) { issue("Folder traversal limit reached. Choose a narrower folder."); continue }
            try {
                query(DocumentsContract.buildChildDocumentsUriUsingTree(tree, id), documentColumns) { c ->
                    while (c.moveToNext()) {
                        check()
                        try {
                            val childId = c.text(DocumentsContract.Document.COLUMN_DOCUMENT_ID) ?: throw IOException("Missing identity")
                            val uri = DocumentsContract.buildDocumentUriUsingTree(tree, childId)
                            val meta = documentMeta(uri, c, path)
                            if (meta.directory) {
                                if (queue.size + visited.size >= StoragePolicy.MAX_DIRECTORIES) issue("Folder traversal limit reached. Choose a narrower folder.")
                                else queue.add(Triple(childId, "$path/${meta.identity.name}", depth + 1))
                            }
                            else if (!emit(entry(uri, true, meta))) return@query false
                        } catch (e: Exception) { check(); issue("A document is unreadable or in a protected location.") }
                    }
                    true
                }.let { if (!it) return }
            } catch (e: Exception) { check(); issue("A folder could not be enumerated. Access may have changed.") }
        }
    }

    private fun mediaColumns(): Array<String> = (listOf(MediaStore.MediaColumns._ID, MediaStore.MediaColumns.DISPLAY_NAME,
        MediaStore.MediaColumns.MIME_TYPE, MediaStore.MediaColumns.SIZE, MediaStore.MediaColumns.DATE_MODIFIED) +
        if (Build.VERSION.SDK_INT >= 30) listOf(MediaStore.MediaColumns.RELATIVE_PATH, MediaStore.MediaColumns.GENERATION_MODIFIED)
        else if (Build.VERSION.SDK_INT >= 29) listOf(MediaStore.MediaColumns.RELATIVE_PATH) else emptyList()).toTypedArray()

    private fun mediaMeta(uri: Uri, c: Cursor): Meta {
        val name = c.text(MediaStore.MediaColumns.DISPLAY_NAME) ?: throw IOException("Missing file name")
        val path = c.text(MediaStore.MediaColumns.RELATIVE_PATH) ?: "Indexed media"
        require(!StoragePolicy.protectedPath(path))
        val key = "$uri:${c.number(MediaStore.MediaColumns.GENERATION_MODIFIED) ?: "legacy"}"
        return Meta(StoragePolicy.Identity(key, name, c.text(MediaStore.MediaColumns.MIME_TYPE) ?: "application/octet-stream",
            c.number(MediaStore.MediaColumns.SIZE)?.takeIf { it >= 0 },
            c.number(MediaStore.MediaColumns.DATE_MODIFIED)?.takeIf { it > 0 }?.times(1000)), 0, false, "MediaStore · $path")
    }

    fun hasMediaAccess(): Boolean {
        fun allowed(p: String) = context.checkSelfPermission(p) == PackageManager.PERMISSION_GRANTED
        return if (Build.VERSION.SDK_INT < 33) allowed(Manifest.permission.READ_EXTERNAL_STORAGE)
        else allowed(Manifest.permission.READ_MEDIA_IMAGES) || allowed(Manifest.permission.READ_MEDIA_VIDEO) ||
            allowed(Manifest.permission.READ_MEDIA_AUDIO) || (Build.VERSION.SDK_INT >= 34 && allowed(Manifest.permission.READ_MEDIA_VISUAL_USER_SELECTED))
    }

    fun media(emit: (Entry) -> Boolean, issue: (String) -> Unit, check: () -> Unit) {
        fun allowed(permission: String) = context.checkSelfPermission(permission) == PackageManager.PERMISSION_GRANTED
        val legacy = Build.VERSION.SDK_INT < 33 && allowed(Manifest.permission.READ_EXTERNAL_STORAGE)
        val partial = Build.VERSION.SDK_INT >= 34 && allowed(Manifest.permission.READ_MEDIA_VISUAL_USER_SELECTED)
        val collections = listOf(
            MediaStore.Images.Media.EXTERNAL_CONTENT_URI to (legacy || partial || (Build.VERSION.SDK_INT >= 33 && allowed(Manifest.permission.READ_MEDIA_IMAGES))),
            MediaStore.Video.Media.EXTERNAL_CONTENT_URI to (legacy || partial || (Build.VERSION.SDK_INT >= 33 && allowed(Manifest.permission.READ_MEDIA_VIDEO))),
            MediaStore.Audio.Media.EXTERNAL_CONTENT_URI to (legacy || (Build.VERSION.SDK_INT >= 33 && allowed(Manifest.permission.READ_MEDIA_AUDIO))))
        if (collections.none { it.second }) throw SecurityException("Media access was not granted. Choose files or a folder instead.")
        if (collections.any { !it.second } || partial && (!allowed(Manifest.permission.READ_MEDIA_IMAGES) || !allowed(Manifest.permission.READ_MEDIA_VIDEO))) issue("Media access is limited to the collections or selected items Android allows.")
        for ((collection, permitted) in collections) {
            check()
            if (!permitted) continue
            try {
                val complete = query(collection, mediaColumns()) { c ->
                    while (c.moveToNext()) {
                        check()
                        try {
                            val id = c.number(MediaStore.MediaColumns._ID) ?: throw IOException("Missing media identity")
                            val uri = ContentUris.withAppendedId(collection, id)
                            if (!emit(entry(uri, false, mediaMeta(uri, c)))) return@query false
                        } catch (e: Exception) { check(); issue("An indexed media item could not be read.") }
                    }
                    true
                }
                if (!complete) return
            } catch (e: Exception) { check(); issue("A media collection could not be queried. Retry access from Storage.") }
        }
    }

    fun hash(entry: Entry, canceled: () -> Boolean): String {
        val before = read(entry.uri, entry.document, entry.meta.location) ?: throw IOException("File is gone")
        check(StoragePolicy.sameFile(entry.meta.identity, before.identity)) { "File changed since scanning" }
        val cancellation = CancellationSignal()
        signal.set(cancellation)
        val fd = try { resolver.openFileDescriptor(entry.uri, "r", cancellation) ?: throw IOException("File cannot be opened") }
            finally { signal.compareAndSet(cancellation, null) }
        val stream = ParcelFileDescriptor.AutoCloseInputStream(fd)
        active.set(stream)
        val hash = try { stream.use { StoragePolicy.digest(it, requireNotNull(entry.meta.identity.size), canceled) } }
            finally { active.compareAndSet(stream, null) }
        val after = read(entry.uri, entry.document, entry.meta.location) ?: throw IOException("File is gone")
        check(StoragePolicy.sameFile(before.identity, after.identity)) { "File changed while reading" }
        return hash
    }
}
