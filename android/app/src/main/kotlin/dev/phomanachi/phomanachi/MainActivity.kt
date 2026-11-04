package dev.phomanachi.phomanachi

import dev.phomanachi.phomanachi.platform.AndroidDeviceService
import dev.phomanachi.phomanachi.platform.DeviceHostApi
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        DeviceHostApi.setUp(flutterEngine.dartExecutor.binaryMessenger, AndroidDeviceService(applicationContext))
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        DeviceHostApi.setUp(flutterEngine.dartExecutor.binaryMessenger, null)
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
