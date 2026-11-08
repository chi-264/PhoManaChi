package dev.phomanachi.phomanachi.apps

import android.Manifest
import android.app.Activity
import android.app.NotificationManager
import android.app.admin.DevicePolicyManager
import android.content.ActivityNotFoundException
import android.content.ComponentName
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.content.pm.PackageInfo
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Process
import android.os.UserManager
import android.provider.Settings
import android.provider.Telephony
import android.telecom.TelecomManager
import androidx.core.app.NotificationManagerCompat
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.ensureActive
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.File
import kotlin.coroutines.coroutineContext

@Suppress("DEPRECATION")
class AndroidAppsService(private val activity: Activity, private val changed: () -> Unit) : AppsHostApi {
    private val pm get() = activity.packageManager
    private val prefs = activity.getSharedPreferences("app_actions", Activity.MODE_PRIVATE)
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
    private val requestCode = 60143
    private var inFlight = false

    init {
        // Process death loses the original callback. Retain the request, never invent success.
        if (prefs.getString("phase", null) == AppActionPhase.REQUESTED.name) {
            save(prefs.getString("package", "")!!, AppActionPhase.UNVERIFIED,
                "The previous uninstall request has no confirmed result. Refresh the list to review its current state.")
        }
    }

    private fun result(pkg: String, phase: AppActionPhase, message: String) =
        AppActionResult(pkg, phase, message, System.currentTimeMillis())

    private fun save(pkg: String, phase: AppActionPhase, message: String): AppActionResult {
        val value = result(pkg, phase, message)
        prefs.edit().putString("package", pkg).putString("phase", phase.name)
            .putString("message", message).putLong("time", value.checkedAtMillis).apply()
        return value
    }

    override suspend fun getLastAction(): AppActionResult? {
        val phase = prefs.getString("phase", null) ?: return null
        return AppActionResult(prefs.getString("package", "")!!, AppActionPhase.valueOf(phase),
            prefs.getString("message", "")!!, prefs.getLong("time", 0))
    }

    override suspend fun clearLastAction() { if (!inFlight) prefs.edit().clear().apply() }

    private fun packageInfo(pkg: String, flags: Int = 0): PackageInfo? {
        require(AppPolicy.validPackage(pkg)) { "Invalid package identifier." }
        return try { pm.getPackageInfo(pkg, flags) } catch (_: PackageManager.NameNotFoundException) { null }
    }

    private fun record(p: PackageInfo): ApplicationRecord {
        val a = requireNotNull(p.applicationInfo)
        return ApplicationRecord(p.packageName,
            runCatching { a.loadLabel(pm).toString().take(200) }.getOrDefault(p.packageName),
            p.versionName, p.longVersionCode,
            a.flags and (ApplicationInfo.FLAG_SYSTEM or ApplicationInfo.FLAG_UPDATED_SYSTEM_APP) != 0,
            a.enabled, p.firstInstallTime, p.lastUpdateTime)
    }

    override suspend fun getInventory(): ApplicationInventory = withContext(Dispatchers.IO) {
        val packages = pm.getInstalledPackages(0)
        val apps = mutableListOf<ApplicationRecord>()
        var skipped = 0
        for (p in packages) {
            coroutineContext.ensureActive()
            runCatching { record(p) }.onSuccess { apps.add(it) }.onFailure { skipped++ }
        }
        ApplicationInventory(1, System.currentTimeMillis(), apps.sortedBy { it.label.lowercase() },
            if (skipped > 0) listOf("$skipped visible app records could not be read. Refresh to retry.") else emptyList())
    }

    private fun settingsIntent(pkg: String) = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.fromParts("package", pkg, null))
    private fun uninstallIntent(pkg: String) = Intent(Intent.ACTION_UNINSTALL_PACKAGE, Uri.fromParts("package", pkg, null))
        .putExtra(Intent.EXTRA_RETURN_RESULT, true)
    private fun systemIntent(intent: Intent): Intent? {
        val info = pm.resolveActivity(intent, PackageManager.MATCH_DEFAULT_ONLY or PackageManager.MATCH_SYSTEM_ONLY)?.activityInfo ?: return null
        if (!info.enabled || !info.exported) return null
        return Intent(intent).setComponent(ComponentName(info.packageName, info.name))
    }
    private fun resolves(intent: Intent) = runCatching { systemIntent(intent) != null }.getOrDefault(false)

    private fun environmentFacts(pkg: String): AppPolicy.Facts {
        var known = true
        val restricted = runCatching {
            val users = requireNotNull(activity.getSystemService(UserManager::class.java))
            users.hasUserRestriction(UserManager.DISALLOW_UNINSTALL_APPS) || users.hasUserRestriction(UserManager.DISALLOW_APPS_CONTROL)
        }.getOrElse { known = false; false }
        return AppPolicy.Facts(userRestricted = restricted, protectionKnown = known,
            permission = activity.checkSelfPermission(Manifest.permission.REQUEST_DELETE_PACKAGES) == PackageManager.PERMISSION_GRANTED,
            handler = resolves(uninstallIntent(pkg)))
    }

    private fun uninstallCapability(p: PackageInfo): AppCapability {
        val app = record(p)
        val environment = environmentFacts(p.packageName)
        var known = environment.protectionKnown
        val essential = runCatching {
            val home = pm.resolveActivity(Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_HOME), PackageManager.MATCH_DEFAULT_ONLY)?.activityInfo?.packageName
            val keyboard = Settings.Secure.getString(activity.contentResolver, Settings.Secure.DEFAULT_INPUT_METHOD)?.substringBefore('/')
            val dialer = activity.getSystemService(TelecomManager::class.java)?.defaultDialerPackage
            val sms = Telephony.Sms.getDefaultSmsPackage(activity)
            p.packageName in listOfNotNull(home, keyboard, dialer, sms)
        }.getOrElse { known = false; false }
        val admin = runCatching {
            val manager = requireNotNull(activity.getSystemService(DevicePolicyManager::class.java))
            manager.activeAdmins?.any { it.packageName == p.packageName } == true
        }.getOrElse { known = false; false }
        val policy = AppPolicy.uninstall(environment.copy(
            ownApp = p.packageName == activity.packageName, systemApp = app.systemApp,
            coreUid = (p.applicationInfo?.uid ?: 0) % 100000 < Process.FIRST_APPLICATION_UID,
            essentialDefault = essential, activeAdmin = admin, protectionKnown = known))
        return AppCapability("uninstall", "Uninstall", policy.first, policy.second)
    }

    private fun settingsCapability(pkg: String): AppCapability {
        val available = resolves(settingsIntent(pkg))
        return AppCapability("appSettings", "Android app settings",
            if (available) AccessState.AVAILABLE else AccessState.UNSUPPORTED,
            if (available) "Manage permissions, storage, defaults, and supported controls in Android settings." else "Android app settings are unavailable on this device.")
    }

    override suspend fun getDetails(packageName: String): ApplicationDetails? = withContext(Dispatchers.IO) {
        val p = packageInfo(packageName, PackageManager.GET_PERMISSIONS) ?: return@withContext null
        val a = requireNotNull(p.applicationInfo)
        val permissions = (p.requestedPermissions ?: emptyArray()).mapIndexed { i, name ->
            val granted = ((p.requestedPermissionsFlags?.getOrNull(i) ?: 0) and PackageInfo.REQUESTED_PERMISSION_GRANTED) != 0
            AppPermission(name, runCatching { pm.getPermissionInfo(name, 0).loadLabel(pm).toString().take(200) }.getOrDefault(name), granted)
        }.sortedBy { it.name }
        val installer = runCatching {
            if (Build.VERSION.SDK_INT >= 30) pm.getInstallSourceInfo(packageName).installingPackageName else pm.getInstallerPackageName(packageName)
        }.getOrNull()
        val bytes = runCatching {
            (listOfNotNull(a.sourceDir) + (a.splitSourceDirs?.toList() ?: emptyList())).sumOf {
                val file = File(it)
                check(file.isFile && file.canRead())
                file.length()
            }.takeIf { it > 0 }
        }.getOrNull()
        ApplicationDetails(record(p), System.currentTimeMillis(), a.uid.toLong(), a.targetSdkVersion.toLong(),
            installer, bytes, permissions, listOf(settingsCapability(packageName), uninstallCapability(p)))
    }

    override suspend fun getCapabilities(): CapabilitySnapshot = withContext(Dispatchers.IO) {
        val settings = settingsCapability(activity.packageName)
        val notifications = runCatching { NotificationManagerCompat.from(activity).areNotificationsEnabled() &&
            activity.getSystemService(NotificationManager::class.java).getNotificationChannel("milestone_updates")?.importance != NotificationManager.IMPORTANCE_NONE
        }.getOrNull()
        val install = runCatching { pm.canRequestPackageInstalls() }.getOrNull()
        val inventory = runCatching { pm.getInstalledPackages(0); true }.getOrDefault(false)
        val uninstall = AppPolicy.uninstall(environmentFacts(activity.packageName))
        CapabilitySnapshot(1, System.currentTimeMillis(), listOf(
            AppCapability("inventory", "Visible applications", if (inventory) AccessState.AVAILABLE else AccessState.UNAVAILABLE,
                if (inventory) "Apps visible to Phone Manager in this Android profile. Other apps and profiles may be hidden." else "Android could not query the visible app list. Refresh to retry."),
            settings,
            AppCapability("uninstall", "User-confirmed uninstall", uninstall.first,
                if (uninstall.first == AccessState.AVAILABLE) "Availability is checked for each app. System, default, administrator, and Phone Manager apps are protected." else uninstall.second),
            AppCapability("notifications", "Milestone notifications", when (notifications) { true -> AccessState.AVAILABLE; false -> AccessState.PERMISSION_REQUIRED; null -> AccessState.UNAVAILABLE },
                when (notifications) { true -> "Android allows milestone notifications. Enable automatic checks in App updates to receive them."; false -> "Notifications are blocked. Allow them in Android settings if you want milestone alerts."; null -> "Notification access could not be checked. Retry to refresh its state." }),
            AppCapability("installUpdates", "Install downloaded updates", when (install) { true -> AccessState.AVAILABLE; false -> AccessState.PERMISSION_REQUIRED; null -> AccessState.UNAVAILABLE },
                when (install) { null -> "Installation access could not be checked. Retry to refresh its state."; false -> "Allow Phone Manager to request installation of verified APK updates in Android settings. Every installation still requires your confirmation."; true -> "Android allows installation requests. Every APK installation still requires your confirmation." }),
            AppCapability("fileCleanup", "Storage analysis and cleanup", AccessState.AVAILABLE, "Choose files, a folder, or media access in Storage. Access and deletion support are checked per file; cleanup requires review and confirmation."),
            AppCapability("processControl", "Control other apps' processes", AccessState.RESTRICTED, "Standard Android access does not allow unrestricted control of other apps' processes."),
            AppCapability("advanced", "Advanced access", AccessState.UNSUPPORTED, "Shizuku and root actions are not enabled in this version.")))
    }

    override suspend fun openAppSettings(packageName: String): AppActionResult {
        val exists = withContext(Dispatchers.IO) { packageInfo(packageName) != null }
        if (!exists) return result(packageName, AppActionPhase.BLOCKED, "This app is no longer visible or installed. Refresh the list.")
        return launch(packageName, settingsIntent(packageName))
    }

    private fun launch(pkg: String, intent: Intent): AppActionResult = try {
        val resolved = systemIntent(intent)
        if (resolved == null) result(pkg, AppActionPhase.FAILED, "This Android settings screen is unavailable.") else {
            activity.startActivity(resolved)
            result(pkg, AppActionPhase.OPENED, "Android settings opened. Changes are checked when you return.")
        }
    } catch (_: ActivityNotFoundException) {
        result(pkg, AppActionPhase.FAILED, "Android could not open this settings screen.")
    } catch (_: SecurityException) {
        result(pkg, AppActionPhase.BLOCKED, "Android blocked this settings request.")
    }

    override suspend fun openAccessSettings(capabilityId: String): AppActionResult = when (capabilityId) {
        "notifications" -> launch(activity.packageName, Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).putExtra(Settings.EXTRA_APP_PACKAGE, activity.packageName))
        "installUpdates" -> launch(activity.packageName, Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES, Uri.fromParts("package", activity.packageName, null)))
        "appSettings" -> openAppSettings(activity.packageName)
        else -> result(activity.packageName, AppActionPhase.BLOCKED, "No settings action is available for this capability.")
    }

    override suspend fun requestUninstall(packageName: String, expectedVersionCode: Long, expectedUpdatedMillis: Long): AppActionResult {
        if (inFlight) return result(packageName, AppActionPhase.BLOCKED, "An uninstall confirmation is already open.")
        inFlight = true
        var launched = false
        try {
            val check = withContext(Dispatchers.IO) {
                val p = packageInfo(packageName)
                when {
                    p == null -> "This app is no longer visible or installed. Refresh the list."
                    !AppPolicy.sameTarget(expectedVersionCode, expectedUpdatedMillis, p.longVersionCode, p.lastUpdateTime) -> "This app changed after you reviewed it. Refresh its details before uninstalling."
                    else -> uninstallCapability(p).takeIf { it.state != AccessState.AVAILABLE }?.reason
                }
            }
            if (check != null) return result(packageName, AppActionPhase.BLOCKED, check)
            val intent = systemIntent(uninstallIntent(packageName))
                ?: return result(packageName, AppActionPhase.BLOCKED, "Android's uninstall confirmation is unavailable.")
            // Save before opening Android so an interrupted process never implies success.
            val requested = save(packageName, AppActionPhase.REQUESTED, "Android confirmation requested. Removal has not been verified.")
            return try {
                activity.startActivityForResult(intent, requestCode)
                launched = true
                requested
            } catch (_: Exception) {
                save(packageName, AppActionPhase.FAILED, "Android could not open uninstall confirmation. Try Android app settings.")
            }
        } finally { if (!launched) inFlight = false }
    }

    fun onActivityResult(code: Int, resultCode: Int) {
        if (code != requestCode) return
        val pkg = prefs.getString("package", null) ?: run { inFlight = false; return }
        scope.launch {
            try {
                val present = withContext(Dispatchers.IO) { runCatching { packageInfo(pkg) != null }.getOrNull() }
                val outcome = AppPolicy.outcome(resultCode == Activity.RESULT_OK, resultCode == Activity.RESULT_CANCELED, present)
                save(pkg, outcome.first, outcome.second)
            } finally { inFlight = false }
            changed()
        }
    }

    fun dispose() { scope.cancel() }
}
