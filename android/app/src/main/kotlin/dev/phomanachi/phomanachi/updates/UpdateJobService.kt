package dev.phomanachi.phomanachi.updates

import android.app.job.JobInfo
import android.app.job.JobParameters
import android.app.job.JobScheduler
import android.app.job.JobService
import android.content.ComponentName
import android.content.Context
import android.os.Handler
import android.os.Looper
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.util.concurrent.TimeUnit

/** Engine callbacks are cleared when the Flutter engine is detached. */
object UpdateBridge {
    var changed: (() -> Unit)? = null
    var openUpdates: (() -> Unit)? = null
    fun notifyChanged() { Handler(Looper.getMainLooper()).post { changed?.invoke() } }
}

object UpdateSchedule {
    private const val JOB_ID = 1042
    fun configure(context: Context, enabled: Boolean) {
        val scheduler = context.getSystemService(JobScheduler::class.java)
        if (!enabled) { scheduler.cancel(JOB_ID); return }
        if (scheduler.getPendingJob(JOB_ID) != null) return
        val job = JobInfo.Builder(JOB_ID, ComponentName(context, UpdateJobService::class.java))
            .setRequiredNetworkType(JobInfo.NETWORK_TYPE_ANY)
            .setRequiresBatteryNotLow(true)
            .setPersisted(true)
            .setPeriodic(TimeUnit.HOURS.toMillis(6)).build()
        check(scheduler.schedule(job) == JobScheduler.RESULT_SUCCESS) { "Android could not schedule milestone update checks." }
    }
}

class UpdateJobService : JobService() {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private var running: Job? = null
    override fun onStartJob(params: JobParameters): Boolean {
        running = scope.launch {
            val core = UpdateCore(applicationContext)
            if (core.automaticChecks) {
                core.check()
                UpdateBridge.notifyChanged()
            }
            withContext(Dispatchers.Main) { jobFinished(params, core.error != null && core.automaticChecks) }
        }
        return true
    }
    override fun onStopJob(params: JobParameters): Boolean {
        running?.cancel()
        return UpdateCore(applicationContext).automaticChecks
    }
    override fun onDestroy() { scope.cancel(); super.onDestroy() }
}
