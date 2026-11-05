package dev.phomanachi.phomanachi.updates

import android.app.Activity
import android.app.NotificationManager
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.StatFs
import android.provider.Settings
import androidx.core.content.FileProvider
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.File
import java.util.concurrent.atomic.AtomicBoolean
import javax.net.ssl.HttpsURLConnection

class AndroidUpdateService(private val activity: Activity) : UpdateHostApi {
    private val core = UpdateCore(activity.applicationContext)
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private val downloading = downloadSlot
    private val canceled = AtomicBoolean(false)
    @Volatile private var activeRelease: UpdateRelease? = null
    @Volatile private var bytes = 0L
    @Volatile private var connection: HttpsURLConnection? = null
    private var permissionResult: CompletableDeferred<Unit>? = null

    override suspend fun getStatus(): UpdateStatus = withContext(Dispatchers.IO) { core.status(activeRelease, bytes) }
    override suspend fun checkForUpdates(): UpdateStatus = withContext(Dispatchers.IO) {
        if (downloading.get()) getStatus() else core.check()
    }

    fun onResume() {
        scope.launch {
            runCatching { UpdateSchedule.configure(activity, core.automaticChecks) }.onFailure { core.setError("Android could not schedule background checks. Manual checking is still available.") }
            if (core.automaticChecks && !downloading.get() && System.currentTimeMillis() - core.lastAttempt >= 15 * 60 * 1000) {
                core.check()
                UpdateBridge.notifyChanged()
            }
        }
    }

    override suspend fun setAutomaticChecks(enabled: Boolean): UpdateStatus = withContext(Dispatchers.IO) {
        core.preferences.edit().putBoolean("automatic_checks", enabled).apply()
        try { UpdateSchedule.configure(activity, enabled) }
        catch (_: Exception) {
            core.preferences.edit().putBoolean("automatic_checks", false).apply()
            core.setError("Android could not enable scheduled checks. Please retry; manual checking remains available.")
            return@withContext getStatus()
        }
        if (enabled) { core.ensureChannel(); core.check() }
        else { activity.getSystemService(NotificationManager::class.java).cancel(UpdateCore.NOTIFICATION_ID); getStatus() }
    }

    override suspend fun requestNotificationPermission(): UpdateStatus {
        withContext(Dispatchers.Main) {
            core.ensureChannel()
            if (Build.VERSION.SDK_INT >= 33 && activity.checkSelfPermission(android.Manifest.permission.POST_NOTIFICATIONS) != android.content.pm.PackageManager.PERMISSION_GRANTED) {
                check(permissionResult == null) { "A notification permission request is already open." }
                val pending = CompletableDeferred<Unit>()
                permissionResult = pending
                try {
                    activity.requestPermissions(arrayOf(android.Manifest.permission.POST_NOTIFICATIONS), PERMISSION_REQUEST)
                    pending.await()
                } finally { permissionResult = null }
            }
        }
        return getStatus()
    }

    fun onPermissionResult(requestCode: Int) { if (requestCode == PERMISSION_REQUEST) permissionResult?.complete(Unit) }

    override suspend fun openNotificationSettings() = withContext(Dispatchers.Main) {
        activity.startActivity(Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).putExtra(Settings.EXTRA_APP_PACKAGE, activity.packageName))
    }

    override suspend fun downloadUpdate(): UpdateStatus = withContext(Dispatchers.IO) {
        if (!downloading.compareAndSet(false, true)) return@withContext getStatus()
        canceled.set(false)
        var temporary: File? = null
        try {
            val release = core.latest ?: throw IllegalArgumentException("Check for a published update first.")
            require(release.versionCode > core.installed.longVersionCode) { "This milestone is already installed." }
            require(release.minSdk <= Build.VERSION.SDK_INT) { "This update requires a newer Android version." }
            val part = File(core.directory, "download.part")
            temporary = part
            part.delete()
            require(StatFs(core.directory.absolutePath).availableBytes > release.sizeBytes + 16 * 1024 * 1024) { "There is not enough free internal storage for this APK." }
            activeRelease = release; bytes = 0L; core.setError(null)
            val remote = UpdateTransport.open(release.apkUrl)
            connection = remote
            remote.inputStream.use { input -> part.outputStream().use { output ->
                val buffer = ByteArray(64 * 1024)
                while (true) {
                    check(!canceled.get()) { "Download canceled." }
                    val count = input.read(buffer)
                    if (count < 0) break
                    bytes += count
                    require(bytes <= release.sizeBytes) { "The download is larger than the published APK size." }
                    output.write(buffer, 0, count)
                }
            } }
            check(!canceled.get()) { "Download canceled." }
            core.verifyApk(part, release)
            check(!canceled.get()) { "Download canceled." }
            val target = core.apkFile(release)
            target.delete()
            check(part.renameTo(target)) { "Could not store the verified APK." }
            core.saveDownloaded(release)
            core.directory.listFiles()?.filter { it != target }?.forEach { it.delete() }
        } catch (error: Exception) {
            temporary?.delete()
            core.setError(when {
                canceled.get() -> "Download canceled. No installation was started."
                error is IllegalArgumentException -> error.message ?: "The downloaded APK failed verification."
                else -> "Could not download and verify the APK. Check your connection, available storage, and retry."
            })
        } finally {
            connection?.disconnect(); connection = null
            activeRelease = null; downloading.set(false)
        }
        getStatus()
    }

    override suspend fun cancelDownload(): UpdateStatus {
        canceled.set(true); connection?.disconnect()
        return getStatus()
    }

    override suspend fun requestInstall(): UpdateStatus {
        val release = withContext(Dispatchers.IO) {
            try {
                val ready = core.downloaded ?: throw IllegalArgumentException("Download and verify the update first.")
                core.verifyApk(core.apkFile(ready), ready)
                core.setError(null)
                ready
            } catch (error: Exception) {
                core.clearDownloaded()
                core.setError(if (error is IllegalArgumentException) error.message else "The update could not be verified for installation. Download it again.")
                null
            }
        } ?: return getStatus()
        return withContext(Dispatchers.Main) {
            try {
                if (!activity.packageManager.canRequestPackageInstalls()) {
                    activity.startActivity(Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES, Uri.parse("package:${activity.packageName}")))
                    getStatus().copy(phase = "installPermissionRequired")
                } else {
                    val uri = FileProvider.getUriForFile(activity, "${activity.packageName}.updates", core.apkFile(release))
                    activity.startActivity(Intent(Intent.ACTION_VIEW).setDataAndType(uri, "application/vnd.android.package-archive").addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION))
                    getStatus().copy(phase = "installerOpened")
                }
            } catch (_: Exception) {
                core.setError("Android could not open the installation flow. Check your installation permission and retry.")
                getStatus()
            }
        }
    }

    fun dispose() {
        canceled.set(true); connection?.disconnect(); permissionResult?.complete(Unit); scope.cancel()
    }

    companion object {
        const val PERMISSION_REQUEST = 50142
        private val downloadSlot = AtomicBoolean(false)
    }
}
