package dev.phomanachi.phomanachi.storage

import org.junit.Assert.*
import org.junit.Test
import java.io.ByteArrayInputStream
import java.io.InputStream
import java.util.concurrent.CancellationException

class StoragePolicyTest {
    @Test fun identityChangesAndUnknownMetadataFailClosed() {
        val first = StoragePolicy.Identity("provider:file", "a.txt", "text/plain", 3, 1000)
        assertTrue(StoragePolicy.sameFile(first, first.copy()))
        for (other in listOf(first.copy(key = "other"), first.copy(name = "renamed"), first.copy(size = 4), first.copy(modified = 1001), first.copy(size = null), first.copy(mime = "image/png"))) assertFalse(StoragePolicy.sameFile(first, other))
        assertFalse(StoragePolicy.sameFile(first.copy(modified = null), first.copy(modified = null)))
    }
    @Test fun sizePrefilterSkipsSingletonsAndUnknownSizes() {
        assertEquals(setOf("a", "b"), StoragePolicy.candidateIds(mapOf("a" to 3L, "b" to 3L, "c" to 5L, "d" to null)))
    }
    @Test fun duplicatesNeedSameSizeAndVerifiedContentNotNames() {
        val sha = "a".repeat(64)
        assertEquals(listOf(setOf("a", "b")), StoragePolicy.duplicateGroups(mapOf("a" to (3L to sha), "b" to (3L to sha), "c" to (4L to sha), "d" to (3L to "b".repeat(64)), "e" to (3L to null))))
    }
    @Test fun digestMatchesSha256AndChecksByteCount() {
        assertEquals("ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad", StoragePolicy.digest(ByteArrayInputStream("abc".toByteArray()), 3))
        assertThrows(IllegalStateException::class.java) { StoragePolicy.digest(ByteArrayInputStream(byteArrayOf(1)), 2) }
        assertThrows(IllegalStateException::class.java) { StoragePolicy.digest(ByteArrayInputStream(byteArrayOf(1, 2)), 1) }
    }
    @Test fun digestUsesBoundedReadsAndSupportsCancellation() {
        var reads = 0
        val input = object : InputStream() {
            override fun read(): Int = error("Must use bounded bulk reads")
            override fun read(b: ByteArray, off: Int, len: Int): Int {
                assertTrue(len <= 64 * 1024); reads++; b[off] = 1; return 1
            }
        }
        assertThrows(CancellationException::class.java) { StoragePolicy.digest(input, 10) { reads >= 2 } }
        assertEquals(2, reads)
    }
    @Test fun nativeReviewRejectsUnknownReplacedRepeatedAndExcessiveSelections() {
        val known = (0..101).map { "f$it" }.toSet()
        StoragePolicy.validateSelection("job", "job", listOf("f0"), known, emptyMap())
        for (ids in listOf(emptyList(), listOf("f0", "f0"), listOf("foreign"), known.toList()))
            assertThrows(IllegalArgumentException::class.java) { StoragePolicy.validateSelection("job", "job", ids, known, emptyMap()) }
        assertThrows(IllegalArgumentException::class.java) { StoragePolicy.validateSelection("replacement", "old", listOf("f0"), known, emptyMap()) }
    }
    @Test fun everyKnownDuplicateGroupMustRetainACopy() {
        val groups = mapOf("g" to setOf("a", "b"))
        StoragePolicy.validateSelection("job", "job", listOf("b"), setOf("a", "b"), groups)
        assertThrows(IllegalArgumentException::class.java) { StoragePolicy.validateSelection("job", "job", listOf("a", "b"), setOf("a", "b"), groups) }
    }
    @Test fun deletionRequiresProviderConfirmationAndVerifiedAbsence() {
        assertEquals("deleted", StoragePolicy.outcome(true, true))
        assertEquals("failed", StoragePolicy.outcome(false, false))
        for (absent in listOf(false, null)) assertEquals("unverified", StoragePolicy.outcome(true, absent))
        assertEquals("unverified", StoragePolicy.outcome(false, true))
    }
    @Test fun protectedAppDataAndCategoriesAreExplicit() {
        for (path in listOf("primary:Android/data", "primary:Android/obb/sub/file", "Android/media/dev.phomanachi.phomanachi/test")) assertTrue(StoragePolicy.protectedPath(path))
        assertFalse(StoragePolicy.protectedPath("primary:Pictures/Android wallpaper.png"))
        assertEquals("Images", StoragePolicy.category("image/png", "photo"))
        assertEquals("Documents", StoragePolicy.category("application/pdf", "file"))
        assertEquals("Archives", StoragePolicy.category("application/octet-stream", "BACKUP.ZIP"))
        assertEquals("Other", StoragePolicy.category("application/octet-stream", "unknown"))
    }
}
