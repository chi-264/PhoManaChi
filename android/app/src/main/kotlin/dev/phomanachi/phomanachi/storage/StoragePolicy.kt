package dev.phomanachi.phomanachi.storage

import java.io.InputStream
import java.security.MessageDigest
import java.util.concurrent.CancellationException

object StoragePolicy {
    const val MAX_FILES = 5000
    const val MAX_DIRECTORIES = 1000
    const val MAX_DEPTH = 32
    const val MAX_SELECTION = 100
    const val REVIEW_LIFETIME_MS = 10 * 60 * 1000L
    const val LARGE_FILE_BYTES = 100 * 1024 * 1024L

    data class Identity(val key: String, val name: String, val mime: String, val size: Long?, val modified: Long?)
    fun sameFile(a: Identity, b: Identity) = a == b && a.size != null && a.modified != null

    fun candidateIds(sizes: Map<String, Long?>): Set<String> = sizes.entries.filter { it.value != null && it.value!! >= 0 }
        .groupBy { it.value }.values.filter { it.size > 1 }.flatten().map { it.key }.toSet()

    fun duplicateGroups(values: Map<String, Pair<Long?, String?>>): List<Set<String>> = values.entries
        .filter { it.value.first != null && it.value.first!! >= 0 && it.value.second?.matches(Regex("[0-9a-f]{64}")) == true }
        .groupBy { it.value }.values.filter { it.size > 1 }.map { group -> group.map { it.key }.toSet() }

    fun category(mime: String, name: String): String = when {
        mime.startsWith("image/") -> "Images"
        mime.startsWith("video/") -> "Videos"
        mime.startsWith("audio/") -> "Audio"
        mime == "application/pdf" || mime.startsWith("text/") || name.substringAfterLast('.', "").lowercase() in setOf("doc", "docx", "xls", "xlsx", "ppt", "pptx", "odt", "epub") -> "Documents"
        name.substringAfterLast('.', "").lowercase() in setOf("zip", "rar", "7z", "tar", "gz") -> "Archives"
        name.endsWith(".apk", true) -> "APKs"
        else -> "Other"
    }

    fun protectedPath(value: String): Boolean {
        val path = value.lowercase().replace('\\', '/').substringAfter(':').trim('/')
        return listOf("android/data", "android/obb", "android/media/dev.phomanachi.phomanachi").any { path == it || path.startsWith("$it/") }
    }

    /** Bounded memory; content must still have the reviewed byte count. */
    fun digest(input: InputStream, expectedBytes: Long, canceled: () -> Boolean = { false }): String {
        require(expectedBytes >= 0)
        val digest = MessageDigest.getInstance("SHA-256")
        val buffer = ByteArray(64 * 1024)
        var bytes = 0L
        var emptyReads = 0
        while (true) {
            if (canceled()) throw CancellationException("Operation canceled")
            val read = input.read(buffer)
            if (read < 0) break
            if (read == 0) { check(++emptyReads < 100) { "Provider stopped returning data" }; continue }
            emptyReads = 0
            bytes += read
            check(bytes <= expectedBytes) { "File grew while being read" }
            digest.update(buffer, 0, read)
        }
        check(bytes == expectedBytes) { "File size changed while being read" }
        return digest.digest().joinToString("") { "%02x".format(it) }
    }

    fun validateSelection(job: String?, requestedJob: String, ids: List<String>, known: Set<String>, groups: Map<String, Set<String>>) {
        require(job != null && job == requestedJob) { "This scan has been replaced. Review the current files." }
        require(ids.isNotEmpty() && ids.size <= MAX_SELECTION && ids.toSet().size == ids.size) { "Select between 1 and $MAX_SELECTION distinct files." }
        require(known.containsAll(ids)) { "Selection includes files outside this scan." }
        val selected = ids.toSet()
        require(groups.values.none { it.isNotEmpty() && selected.containsAll(it) }) { "Keep at least one file from each duplicate group." }
    }

    fun outcome(reportedDeleted: Boolean, absent: Boolean?): String = when {
        reportedDeleted && absent == true -> "deleted"
        !reportedDeleted && absent == false -> "failed"
        else -> "unverified"
    }
}
