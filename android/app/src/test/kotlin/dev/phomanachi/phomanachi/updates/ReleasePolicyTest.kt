package dev.phomanachi.phomanachi.updates

import org.junit.Assert.*
import org.junit.Test

class ReleasePolicyTest {
    private val sha = "a".repeat(64)
    private val asset = "https://github.com/chi-264/PhoManaChi/releases/download/v0.3.0/phomanachi.apk"
    private fun manifest(url: String = asset, code: Long = 3, hash: String = sha, size: Long = 1024) = ReleasePolicy.validateRelease(code, "0.3.0", "Storage milestone", "Notes", url, hash, size, 28)

    @Test fun validRelease() { manifest() }
    @Test fun rejectInsecureOrForeignDownloads() {
        for (url in listOf(asset.replace("https:", "http:"), asset.replace("chi-264", "someone-else"), asset.replace("github.com", "github.com.attacker.test"), "$asset?redirect=1", asset.replace("/v0.3.0/", "/../"))) {
            assertThrows(IllegalArgumentException::class.java) { manifest(url) }
        }
    }
    @Test fun rejectInvalidManifestFields() {
        assertThrows(IllegalArgumentException::class.java) { manifest(code = 0) }
        assertThrows(IllegalArgumentException::class.java) { manifest(hash = "bad") }
        assertThrows(IllegalArgumentException::class.java) { manifest(size = ReleasePolicy.MAX_APK_BYTES + 1) }
    }
    @Test fun secureRedirectsOnly() {
        ReleasePolicy.validateTransportUrl("https://release-assets.githubusercontent.com/file?signature=opaque")
        for (url in listOf("http://github.com/file", "https://attacker.test/file", "https://name@github.com/file")) {
            assertThrows(IllegalArgumentException::class.java) { ReleasePolicy.validateTransportUrl(url) }
        }
    }
    private fun archive(pkg: String = "dev.phomanachi.phomanachi", code: Long = 3, signers: Set<String> = setOf("original"), minSdk: Int = 28) = ReleasePolicy.validateArchive("dev.phomanachi.phomanachi", pkg, 2, code, 3, "0.3.0", "0.3.0", 34, minSdk, setOf("original"), signers)
    @Test fun validArchive() { archive() }
    @Test fun rejectWrongIdentityVersionSignerAndSdk() {
        assertThrows(IllegalArgumentException::class.java) { archive(pkg = "another.app") }
        assertThrows(IllegalArgumentException::class.java) { archive(code = 2) }
        assertThrows(IllegalArgumentException::class.java) { archive(signers = setOf("different")) }
        assertThrows(IllegalArgumentException::class.java) { archive(signers = emptySet()) }
        assertThrows(IllegalArgumentException::class.java) { archive(minSdk = 35) }
    }
    @Test fun downloadedApksDoNotHideNewerMilestones() {
        assertTrue(ReleasePolicy.shouldOfferDownloaded(3, 2, 3))
        assertTrue(ReleasePolicy.shouldOfferDownloaded(3, 2, null))
        assertFalse(ReleasePolicy.shouldOfferDownloaded(3, 2, 4))
        assertFalse(ReleasePolicy.shouldOfferDownloaded(3, 3, 3))
    }
    @Test fun notificationsAreOptInAndDeduplicated() {
        assertTrue(ReleasePolicy.shouldNotify(true, true, 3, 2, 0))
        assertFalse(ReleasePolicy.shouldNotify(true, true, 3, 2, 3))
        assertFalse(ReleasePolicy.shouldNotify(false, true, 3, 2, 0))
        assertFalse(ReleasePolicy.shouldNotify(true, false, 3, 2, 0))
        assertFalse(ReleasePolicy.shouldNotify(true, true, 2, 2, 0))
    }
}
