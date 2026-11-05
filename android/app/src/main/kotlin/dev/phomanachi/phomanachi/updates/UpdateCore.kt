package dev.phomanachi.phomanachi.updates

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageInfo
import android.content.pm.PackageManager
import android.os.Build
import dev.phomanachi.phomanachi.MainActivity
import dev.phomanachi.phomanachi.R
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import org.json.JSONObject
import java.io.File
import java.security.MessageDigest

@Suppress("DEPRECATION")
class UpdateCore(val context: Context) {
    val preferences = context.getSharedPreferences("milestone_updates", Context.MODE_PRIVATE)
    val directory = File(context.filesDir, "updates").apply { mkdirs() }
    val installed: PackageInfo get() = context.packageManager.getPackageInfo(context.packageName, PackageManager.GET_SIGNING_CERTIFICATES)
    val automaticChecks: Boolean get() = preferences.getBoolean("automatic_checks", false)
    val lastChecked: Long? get() = preferences.getLong("last_checked", 0L).takeIf { it > 0L }
    val lastAttempt: Long get() = preferences.getLong("last_attempt", 0L)
    val error: String? get() = preferences.getString("last_error", null)
    val latest: UpdateRelease? get() = cached("latest_release")
    val downloaded: UpdateRelease? get() = cached("downloaded_release")?.takeIf { apkFile(it).isFile && apkFile(it).length() == it.sizeBytes }

    fun apkFile(release: UpdateRelease) = File(directory, "update-${release.versionCode}.apk")
    fun setError(message: String?) { preferences.edit().putString("last_error", message).apply() }
    fun clearDownloaded() {
        cached("downloaded_release")?.let { apkFile(it).delete() }
        preferences.edit().remove("downloaded_release").apply()
    }
    fun saveDownloaded(release: UpdateRelease) { preferences.edit().putString("downloaded_release", encode(release)).apply() }

    suspend fun check(): UpdateStatus = checkMutex.withLock {
        preferences.edit().putLong("last_attempt", System.currentTimeMillis()).apply()
        try {
            val release = decode(UpdateTransport.readManifest())
            preferences.edit().putString("latest_release", encode(release)).putLong("last_checked", System.currentTimeMillis()).remove("last_error").apply()
            notifyIfNeeded(release)
        } catch (cancelled: CancellationException) { throw cancelled }
        catch (_: MissingReleaseException) {
            preferences.edit().putLong("last_checked", System.currentTimeMillis()).apply()
            setError(if (latest == null) null else "The latest release manifest is currently unavailable. Retry later.")
        } catch (_: org.json.JSONException) {
            setError("The published update metadata is invalid. Please retry after the release is corrected.")
        } catch (invalid: IllegalArgumentException) {
            setError(invalid.message ?: "Invalid update metadata. Installation was not offered.")
        } catch (_: Exception) {
            setError("Could not check updates. Check your connection and retry.")
        }
        status()
    }

    fun status(activeRelease: UpdateRelease? = null, bytes: Long = 0): UpdateStatus {
        val info = installed
        val published = latest
        if (published?.versionCode?.let { it <= info.longVersionCode } == true) context.getSystemService(NotificationManager::class.java).cancel(NOTIFICATION_ID)
        val cachedDownload = downloaded
        if (cachedDownload != null && cachedDownload.versionCode <= info.longVersionCode) clearDownloaded()
        val verified = cachedDownload?.takeIf { ReleasePolicy.shouldOfferDownloaded(it.versionCode, info.longVersionCode, published?.takeIf { release -> release.minSdk <= Build.VERSION.SDK_INT }?.versionCode) }
        val release = activeRelease ?: verified ?: published
        val newer = release != null && release.versionCode > info.longVersionCode
        val phase = when {
            activeRelease != null -> "downloading"
            verified != null -> "ready"
            newer && release.minSdk > Build.VERSION.SDK_INT -> "incompatible"
            newer -> "available"
            error != null -> "failed"
            lastChecked == null -> "idle"
            release == null -> "noRelease"
            else -> "upToDate"
        }
        return UpdateStatus(
            installedVersionCode = info.longVersionCode,
            installedVersionName = info.versionName ?: "Unknown",
            phase = phase,
            automaticChecksEnabled = automaticChecks,
            notificationsAllowed = notificationsAllowed(),
            canInstallPackages = context.packageManager.canRequestPackageInstalls(),
            downloadedBytes = if (verified != null && activeRelease == null) verified.sizeBytes else bytes,
            lastCheckedMillis = lastChecked,
            release = release,
            errorMessage = error,
        )
    }

    fun decode(text: String): UpdateRelease {
        val data = JSONObject(text)
        fun number(key: String): Long {
            val value = data.get(key)
            require(value is Number && value.toDouble().isFinite() && value.toDouble() == value.toLong().toDouble()) { "Invalid integer in release metadata." }
            return value.toLong()
        }
        fun string(key: String): String {
            val value = data.get(key)
            require(value is String) { "Invalid text in release metadata." }
            return value
        }
        require(number("schema_version") == 1L && string("package_name") == context.packageName) { "Unsupported update manifest or application identity." }
        val release = UpdateRelease(number("version_code"), string("version_name"), string("title"), string("notes"), string("apk_url"), string("sha256").lowercase(), number("size_bytes"), number("min_sdk"))
        ReleasePolicy.validateRelease(release.versionCode, release.versionName, release.title, release.notes, release.apkUrl, release.sha256, release.sizeBytes, release.minSdk)
        return release
    }

    private fun cached(key: String): UpdateRelease? = preferences.getString(key, null)?.let { runCatching { decode(it) }.getOrNull() }

    private fun encode(release: UpdateRelease): String = JSONObject().apply {
        put("schema_version", 1); put("package_name", context.packageName)
        put("version_code", release.versionCode); put("version_name", release.versionName)
        put("title", release.title); put("notes", release.notes); put("apk_url", release.apkUrl)
        put("sha256", release.sha256); put("size_bytes", release.sizeBytes); put("min_sdk", release.minSdk)
    }.toString()

    fun verifyApk(file: File, release: UpdateRelease) {
        FileIntegrity.verify(file, release.sizeBytes, release.sha256)
        val archive = context.packageManager.getPackageArchiveInfo(file.absolutePath, PackageManager.GET_SIGNING_CERTIFICATES)
            ?: throw IllegalArgumentException("The downloaded file is not a readable Android APK.")
        val current = installed
        fun certificates(info: PackageInfo): Set<String> = info.signingInfo?.apkContentsSigners?.map { signature ->
            MessageDigest.getInstance("SHA-256").digest(signature.toByteArray()).joinToString("") { "%02x".format(it) }
        }?.toSet() ?: emptySet()
        ReleasePolicy.validateArchive(context.packageName, archive.packageName, current.longVersionCode, archive.longVersionCode, release.versionCode, release.versionName, archive.versionName, Build.VERSION.SDK_INT, archive.applicationInfo?.minSdkVersion ?: Int.MAX_VALUE, certificates(current), certificates(archive))
    }

    fun ensureChannel() {
        context.getSystemService(NotificationManager::class.java).createNotificationChannel(NotificationChannel(CHANNEL, "Milestone updates", NotificationManager.IMPORTANCE_DEFAULT).apply { description = "A notification when a newer Phone Manager milestone is available." })
    }

    fun notificationsAllowed(): Boolean {
        if (Build.VERSION.SDK_INT >= 33 && context.checkSelfPermission(android.Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) return false
        val manager = context.getSystemService(NotificationManager::class.java)
        return manager.areNotificationsEnabled() && manager.getNotificationChannel(CHANNEL)?.importance != NotificationManager.IMPORTANCE_NONE
    }

    fun notifyIfNeeded(release: UpdateRelease) {
        if (release.minSdk > Build.VERSION.SDK_INT || !ReleasePolicy.shouldNotify(automaticChecks, notificationsAllowed(), release.versionCode, installed.longVersionCode, preferences.getLong("last_notified", 0L))) return
        ensureChannel()
        val intent = Intent(context, MainActivity::class.java).putExtra(OPEN_UPDATES, true).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        val pending = PendingIntent.getActivity(context, NOTIFICATION_ID, intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val notification = android.app.Notification.Builder(context, CHANNEL).setSmallIcon(R.drawable.ic_update)
            .setContentTitle("Phone Manager ${release.versionName} is available")
            .setContentText(release.title).setStyle(android.app.Notification.BigTextStyle().bigText("${release.title}\nTap to review this milestone and download the update."))
            .setContentIntent(pending).setAutoCancel(true).build()
        try {
            context.getSystemService(NotificationManager::class.java).notify(NOTIFICATION_ID, notification)
            preferences.edit().putLong("last_notified", release.versionCode).apply()
        } catch (_: SecurityException) { /* Permission may be revoked between the check and post. */ }
    }

    companion object {
        const val CHANNEL = "milestone_updates"
        const val NOTIFICATION_ID = 1042
        const val OPEN_UPDATES = "dev.phomanachi.OPEN_UPDATES"
        private val checkMutex = Mutex()
    }
}
