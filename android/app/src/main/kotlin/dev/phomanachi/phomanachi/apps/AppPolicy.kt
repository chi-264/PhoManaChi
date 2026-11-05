package dev.phomanachi.phomanachi.apps

/** Pure policy: Android services gather facts; every uninstall re-evaluates them. */
object AppPolicy {
    data class Facts(
        val ownApp: Boolean = false,
        val systemApp: Boolean = false,
        val coreUid: Boolean = false,
        val essentialDefault: Boolean = false,
        val activeAdmin: Boolean = false,
        val userRestricted: Boolean = false,
        val protectionKnown: Boolean = true,
        val permission: Boolean = true,
        val handler: Boolean = true,
    )

    fun uninstall(f: Facts): Pair<AccessState, String> = when {
        f.ownApp -> AccessState.RESTRICTED to "Phone Manager cannot uninstall itself from this screen."
        f.systemApp || f.coreUid -> AccessState.RESTRICTED to "System applications are protected. Use Android app settings for supported options."
        f.essentialDefault -> AccessState.RESTRICTED to "This app is a default home, phone, messaging, or keyboard app. Change the default in Android settings first."
        f.activeAdmin -> AccessState.RESTRICTED to "This app is an active device administrator. Manage its administrator access in Android settings."
        f.userRestricted -> AccessState.RESTRICTED to "Uninstalling apps is restricted for this user or device."
        !f.protectionKnown -> AccessState.UNAVAILABLE to "Protection checks could not be completed. Retry before requesting uninstall."
        !f.permission -> AccessState.PERMISSION_REQUIRED to "This build does not have Android's uninstall-request permission."
        !f.handler -> AccessState.UNSUPPORTED to "Android's confirmation screen is unavailable. Use app settings."
        else -> AccessState.AVAILABLE to "Android will ask you to confirm. Removal is checked after returning."
    }

    fun sameTarget(expectedVersion: Long, expectedUpdated: Long, currentVersion: Long, currentUpdated: Long) =
        expectedVersion == currentVersion && expectedUpdated == currentUpdated

    fun outcome(systemConfirmed: Boolean, canceled: Boolean, present: Boolean?): Pair<AppActionPhase, String> = when {
        systemConfirmed && present == false -> AppActionPhase.VERIFIED_REMOVED to "Android confirmed uninstall and the package is no longer available in this profile."
        canceled && present == true -> AppActionPhase.CANCELED to "Uninstall was canceled. The app is still installed."
        else -> AppActionPhase.UNVERIFIED to "Removal could not be confirmed. Refresh the app list or check Android app settings."
    }

    fun validPackage(value: String) = value.length in 1..255 &&
        value.matches(Regex("[A-Za-z][A-Za-z0-9_]*(\\.[A-Za-z][A-Za-z0-9_]*)*"))
}
