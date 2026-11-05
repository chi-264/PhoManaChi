package dev.phomanachi.phomanachi

import android.content.Intent
import dev.phomanachi.phomanachi.apps.AndroidAppsService
import dev.phomanachi.phomanachi.apps.AppsHostApi
import dev.phomanachi.phomanachi.apps.AppsFlutterApi
import dev.phomanachi.phomanachi.platform.AndroidDeviceService
import dev.phomanachi.phomanachi.platform.DeviceHostApi
import dev.phomanachi.phomanachi.updates.AndroidUpdateService
import dev.phomanachi.phomanachi.updates.UpdateBridge
import dev.phomanachi.phomanachi.updates.UpdateCore
import dev.phomanachi.phomanachi.updates.UpdateFlutterApi
import dev.phomanachi.phomanachi.updates.UpdateHostApi
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    private var updates: AndroidUpdateService? = null
    private var apps: AndroidAppsService? = null
    private var callbackScope: CoroutineScope? = null

    override fun getInitialRoute(): String? = if (intent?.getBooleanExtra(UpdateCore.OPEN_UPDATES, false) == true) "/more/updates" else super.getInitialRoute()

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        DeviceHostApi.setUp(messenger, AndroidDeviceService(applicationContext))
        updates = AndroidUpdateService(this)
        UpdateHostApi.setUp(messenger, updates)
        val callbacks = UpdateFlutterApi(messenger)
        callbackScope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
        val appCallbacks = AppsFlutterApi(messenger)
        apps = AndroidAppsService(this) {
            callbackScope?.launch { runCatching { appCallbacks.actionChanged() } }
        }
        AppsHostApi.setUp(messenger, apps)
        UpdateBridge.changed = { callbackScope?.launch { runCatching { callbacks.statusChanged() } } }
        UpdateBridge.openUpdates = { callbackScope?.launch { runCatching { callbacks.openUpdates() } } }
    }

    override fun onResume() { super.onResume(); updates?.onResume() }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        if (intent.getBooleanExtra(UpdateCore.OPEN_UPDATES, false)) UpdateBridge.openUpdates?.invoke()
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        updates?.onPermissionResult(requestCode)
    }

    @Deprecated("Android's confirmation activity returns through this callback")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        apps?.onActivityResult(requestCode, resultCode)
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        UpdateBridge.changed = null; UpdateBridge.openUpdates = null
        callbackScope?.cancel(); callbackScope = null
        apps?.dispose(); apps = null
        AppsHostApi.setUp(flutterEngine.dartExecutor.binaryMessenger, null)
        updates?.dispose(); updates = null
        UpdateHostApi.setUp(flutterEngine.dartExecutor.binaryMessenger, null)
        DeviceHostApi.setUp(flutterEngine.dartExecutor.binaryMessenger, null)
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
