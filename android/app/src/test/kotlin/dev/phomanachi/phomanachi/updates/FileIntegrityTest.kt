package dev.phomanachi.phomanachi.updates

import java.io.File
import java.security.MessageDigest
import org.junit.Assert.assertThrows
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder

class FileIntegrityTest {
    @get:Rule val temporary = TemporaryFolder()
    private val original = "APK fixture".toByteArray()
    private val digest = MessageDigest.getInstance("SHA-256").digest(original).joinToString("") { "%02x".format(it) }
    private fun file(bytes: ByteArray = original): File = temporary.newFile().apply { writeBytes(bytes) }
    @Test fun acceptsMatchingBytes() { FileIntegrity.verify(file(), original.size.toLong(), digest) }
    @Test fun rejectsSameLengthTampering() { assertThrows(IllegalArgumentException::class.java) { FileIntegrity.verify(file(original.copyOf().apply { this[0] = 0 }), original.size.toLong(), digest) } }
    @Test fun rejectsTruncatedDownload() { assertThrows(IllegalArgumentException::class.java) { FileIntegrity.verify(file(original.copyOf(2)), original.size.toLong(), digest) } }
}
