package dev.phomanachi.phomanachi.updates

import java.io.File
import java.security.MessageDigest

object FileIntegrity {
    fun verify(file: File, size: Long, sha256: String) {
        require(file.length() == size) { "The downloaded APK size does not match the release." }
        val digest = MessageDigest.getInstance("SHA-256")
        file.inputStream().use { stream ->
            val buffer = ByteArray(64 * 1024)
            while (true) {
                val count = stream.read(buffer)
                if (count < 0) break
                digest.update(buffer, 0, count)
            }
        }
        require(digest.digest().joinToString("") { "%02x".format(it) } == sha256) { "The APK checksum does not match. Download it again." }
    }
}
