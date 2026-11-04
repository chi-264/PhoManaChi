package dev.phomanachi.phomanachi.platform

import android.app.ActivityManager
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.BatteryManager
import android.os.Build
import android.os.Environment
import android.os.StatFs
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

/** Read-only system access. Individual service failures leave unrelated readings intact. */
class AndroidDeviceService(private val context: Context) : DeviceHostApi {
    override suspend fun getSystemSnapshot(): SystemSnapshot = withContext(Dispatchers.IO) {
        val notices = mutableListOf<String>()
        val memory = runCatching {
            val manager = context.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
            ActivityManager.MemoryInfo().also { manager.getMemoryInfo(it) }
        }.getOrElse { notices.add("Memory service could not be read."); null }
        val storage = runCatching { StatFs(Environment.getDataDirectory().absolutePath) }
            .getOrElse { notices.add("Internal storage capacity could not be read."); null }
        val battery = runCatching {
            context.registerReceiver(null, IntentFilter(Intent.ACTION_BATTERY_CHANGED))
        }.getOrElse { notices.add("Battery service could not be read."); null }
        if (battery == null) notices.add("Battery information is unavailable.")
        val level = battery?.getIntExtra(BatteryManager.EXTRA_LEVEL, -1) ?: -1
        val scale = battery?.getIntExtra(BatteryManager.EXTRA_SCALE, -1) ?: -1
        val temperature = battery?.takeIf { it.hasExtra(BatteryManager.EXTRA_TEMPERATURE) }
            ?.getIntExtra(BatteryManager.EXTRA_TEMPERATURE, 0)?.div(10.0)
        val voltage = battery?.getIntExtra(BatteryManager.EXTRA_VOLTAGE, -1)
            ?.takeIf { it > 0 }?.toLong()
        SystemSnapshot(
            contractVersion = 1L,
            observedAtMillis = System.currentTimeMillis(),
            manufacturer = Build.MANUFACTURER,
            model = Build.MODEL,
            androidVersion = Build.VERSION.RELEASE,
            apiLevel = Build.VERSION.SDK_INT.toLong(),
            buildId = Build.DISPLAY,
            totalMemoryBytes = memory?.totalMem?.takeIf { it > 0 },
            availableMemoryBytes = memory?.availMem?.takeIf { it >= 0 },
            lowMemory = memory?.lowMemory,
            totalStorageBytes = storage?.totalBytes?.takeIf { it > 0 },
            availableStorageBytes = storage?.availableBytes?.takeIf { it >= 0 },
            batteryPercent = if (scale > 0 && level in 0..scale) level * 100.0 / scale else null,
            batteryState = when (battery?.getIntExtra(BatteryManager.EXTRA_STATUS, -1)) {
                BatteryManager.BATTERY_STATUS_CHARGING -> "Charging"
                BatteryManager.BATTERY_STATUS_DISCHARGING -> "Discharging"
                BatteryManager.BATTERY_STATUS_FULL -> "Full"
                BatteryManager.BATTERY_STATUS_NOT_CHARGING -> "Not charging"
                else -> null
            },
            powerSource = when (battery?.getIntExtra(BatteryManager.EXTRA_PLUGGED, -1)) {
                0 -> "Battery"
                BatteryManager.BATTERY_PLUGGED_AC -> "AC"
                BatteryManager.BATTERY_PLUGGED_USB -> "USB"
                BatteryManager.BATTERY_PLUGGED_WIRELESS -> "Wireless"
                else -> null
            },
            temperatureCelsius = temperature,
            voltageMillivolts = voltage,
            batteryHealth = when (battery?.getIntExtra(BatteryManager.EXTRA_HEALTH, -1)) {
                BatteryManager.BATTERY_HEALTH_GOOD -> "Good"
                BatteryManager.BATTERY_HEALTH_OVERHEAT -> "Overheating"
                BatteryManager.BATTERY_HEALTH_DEAD -> "Dead"
                BatteryManager.BATTERY_HEALTH_OVER_VOLTAGE -> "Over voltage"
                BatteryManager.BATTERY_HEALTH_UNSPECIFIED_FAILURE -> "Failure"
                BatteryManager.BATTERY_HEALTH_COLD -> "Cold"
                else -> null
            },
            notices = notices,
        )
    }
}
