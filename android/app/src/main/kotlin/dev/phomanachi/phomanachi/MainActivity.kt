package dev.phomanachi.phomanachi

import android.content.Intent
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

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        UpdateBridge.changed = null; UpdateBridge.openUpdates = null
        callbackScope?.cancel(); callbackScope = null
        updates?.dispose(); updates = null
        UpdateHostApi.setUp(flutterEngine.dartExecutor.binaryMessenger, null)
        DeviceHostApi.setUp(flutterEngine.dartExecutor.binaryMessenger, null)
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
