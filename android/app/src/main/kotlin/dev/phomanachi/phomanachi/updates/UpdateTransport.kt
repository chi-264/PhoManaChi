package dev.phomanachi.phomanachi.updates

import java.io.IOException
import java.io.ByteArrayOutputStream
import java.net.URL
import javax.net.ssl.HttpsURLConnection

class MissingReleaseException : IOException("No published update manifest was found on GitHub Releases yet.")

object UpdateTransport {
    fun open(url: String): HttpsURLConnection {
        var target = url
        repeat(6) {
            ReleasePolicy.validateTransportUrl(target)
            val connection = URL(target).openConnection() as HttpsURLConnection
            connection.instanceFollowRedirects = false
            connection.connectTimeout = 15_000
            connection.readTimeout = 30_000
            connection.setRequestProperty("User-Agent", "PhoManaChi-Updater")
            connection.setRequestProperty("Accept", "application/octet-stream")
            try {
                when (connection.responseCode) {
                    200 -> return connection
                    301, 302, 303, 307, 308 -> {
                        val location = connection.getHeaderField("Location") ?: throw IOException("The release server returned an incomplete redirect.")
                        target = URL(URL(target), location).toExternalForm()
                        connection.disconnect()
                    }
                    404 -> throw MissingReleaseException()
                    else -> throw IOException("The release server could not serve the update (HTTP ${connection.responseCode}).")
                }
            } catch (error: Exception) {
                connection.disconnect()
                throw error
            }
        }
        throw IOException("Too many redirects from the release server.")
    }

    fun readManifest(): String {
        val connection = open(ReleasePolicy.MANIFEST_URL)
        try {
            return connection.inputStream.use { stream ->
                val output = ByteArrayOutputStream()
                val buffer = ByteArray(4096)
                while (true) {
                    val count = stream.read(buffer)
                    if (count < 0) break
                    require(output.size() + count <= 65_536) { "The update manifest is too large." }
                    output.write(buffer, 0, count)
                }
                output.toString("UTF-8")
            }
        } finally { connection.disconnect() }
    }
}
