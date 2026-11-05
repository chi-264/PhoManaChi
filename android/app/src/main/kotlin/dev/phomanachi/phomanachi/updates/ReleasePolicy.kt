package dev.phomanachi.phomanachi.updates

import java.net.URI

/** Pure policy shared by manifest parsing, download, and installer validation. */
object ReleasePolicy {
    const val REPOSITORY = "chi-264/PhoManaChi"
    const val MANIFEST_URL = "https://github.com/$REPOSITORY/releases/latest/download/update.json"
    const val MAX_APK_BYTES = 1024L * 1024 * 1024
    private val downloadPrefix = "/$REPOSITORY/releases/download/"
    private val redirectHosts = setOf("github.com", "release-assets.githubusercontent.com", "objects.githubusercontent.com", "github-releases.githubusercontent.com")

    fun validateRelease(versionCode: Long, versionName: String, title: String, notes: String, apkUrl: String, sha256: String, sizeBytes: Long, minSdk: Long) {
        require(versionCode in 1..2_100_000_000L) { "Invalid release version code." }
        require(versionName.isNotBlank() && versionName.length <= 64) { "Invalid release version name." }
        require(title.isNotBlank() && title.length <= 160 && notes.length <= 16000) { "Invalid release notes." }
        require(sha256.matches(Regex("[a-fA-F0-9]{64}"))) { "The release is missing a valid SHA-256 checksum." }
        require(sizeBytes in 1..MAX_APK_BYTES) { "Invalid APK size." }
        require(minSdk in 28..100) { "Invalid Android compatibility information." }
        val uri = URI(apkUrl)
        require(uri.scheme == "https" && uri.host == "github.com" && uri.userInfo == null && uri.port == -1 && uri.query == null && uri.fragment == null) { "APK must come from this project's HTTPS GitHub Releases." }
        require(uri.path.startsWith(downloadPrefix) && uri.path.endsWith("/phomanachi.apk") && uri.path.split('/').none { it == "." || it == ".." }) { "APK URL is outside the trusted release repository." }
        val remainder = uri.path.removePrefix(downloadPrefix)
        require(remainder.split('/').size == 2 && remainder.substringBefore('/').isNotBlank()) { "Invalid release asset path." }
    }

    fun validateTransportUrl(url: String) {
        val uri = URI(url)
        require(uri.scheme == "https" && uri.host in redirectHosts && uri.userInfo == null && (uri.port == -1 || uri.port == 443)) { "Untrusted update redirect or insecure connection." }
    }

    fun validateArchive(expectedPackage: String, archivePackage: String?, installedCode: Long, archiveCode: Long, expectedCode: Long, expectedName: String, archiveName: String?, deviceSdk: Int, archiveMinSdk: Int, installedSigners: Set<String>, archiveSigners: Set<String>) {
        require(archivePackage == expectedPackage) { "The downloaded APK belongs to another application." }
        require(archiveCode == expectedCode && archiveCode > installedCode && archiveName == expectedName) { "The APK version does not match the release or is not newer." }
        require(archiveMinSdk <= deviceSdk) { "The APK requires a newer Android version." }
        require(installedSigners.isNotEmpty() && archiveSigners == installedSigners) { "The APK signing certificate does not match this installed app." }
    }

    fun shouldOfferDownloaded(downloadedCode: Long, installedCode: Long, latestCompatibleCode: Long?): Boolean = downloadedCode > installedCode && (latestCompatibleCode == null || downloadedCode >= latestCompatibleCode)

    fun shouldNotify(enabled: Boolean, allowed: Boolean, releaseCode: Long, installedCode: Long, lastNotifiedCode: Long): Boolean = enabled && allowed && releaseCode > installedCode && releaseCode > lastNotifiedCode
}
