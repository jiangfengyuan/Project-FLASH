// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package com.flash.app.data.reminder

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import androidx.work.Data
import androidx.work.ExistingWorkPolicy
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.Operation
import androidx.work.WorkManager
import com.google.common.util.concurrent.ListenableFuture
import androidx.work.Worker
import androidx.work.WorkerParameters
import com.flash.app.MainActivity
import com.flash.app.data.model.TaskItem
import java.time.Duration
import java.time.Instant
import java.util.concurrent.TimeUnit
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock

class TaskReminderScheduler(
    context: Context,
    private val canNotify: () -> Boolean = { notificationsEnabled(context.applicationContext) },
) {
    private val appContext = context.applicationContext
    private val workManager = WorkManager.getInstance(appContext)
    private val rebuildMutex = Mutex()

    suspend fun schedule(task: TaskItem) {
        val scheduled = scheduledTask(task)
        if (scheduled == null) {
            cancel(task.id)
            return
        }
        workManager.enqueueUniqueWork(
            scheduled.name,
            ExistingWorkPolicy.REPLACE,
            scheduled.request,
        ).awaitCompletion()
    }

    private fun scheduledTask(task: TaskItem): ScheduledTask? {
        val reminderAt = task.reminderAt ?: return null
        if (task.isCompleted) return null
        val delay = runCatching {
            Duration.between(Instant.now(), Instant.parse(reminderAt)).toMillis()
        }.getOrNull() ?: return null
        if (delay <= 0) return null

        val name = workName(task.id)
        val request = OneTimeWorkRequestBuilder<TaskReminderWorker>()
            .setInitialDelay(delay, TimeUnit.MILLISECONDS)
            .setInputData(
                Data.Builder()
                    .putString(TaskReminderWorker.KEY_TASK_ID, task.id)
                    .putString(TaskReminderWorker.KEY_TITLE, task.title)
                    .build()
            )
            .addTag(TAG)
            .addTag(name)
            .build()
        return ScheduledTask(name, request)
    }

    suspend fun cancel(taskId: String) {
        workManager.cancelUniqueWork(workName(taskId)).awaitCompletion()
    }

    suspend fun rebuild(tasks: List<TaskItem>) = rebuildMutex.withLock {
        // Stage every desired reminder before removing stale work. If enqueueing
        // fails halfway, reminders not yet replaced remain intact.
        val desired = tasks.mapNotNull(::scheduledTask)
        if (desired.isNotEmpty() && !canNotify()) {
            throw IllegalStateException("系统通知或任务提醒频道已关闭")
        }
        val previous = workManager.getWorkInfosByTag(TAG).awaitValue()
        for (scheduled in desired) {
            workManager.enqueueUniqueWork(
                scheduled.name,
                ExistingWorkPolicy.REPLACE,
                scheduled.request,
            ).awaitCompletion()
        }
        val desiredNames = desired.mapTo(mutableSetOf()) { it.name }
        for (work in previous) {
            val taskTag = work.tags.firstOrNull { it.startsWith(WORK_PREFIX) }
            if (taskTag == null || taskTag !in desiredNames) {
                workManager.cancelWorkById(work.id).awaitCompletion()
            }
        }
    }

    private fun workName(taskId: String) = "$WORK_PREFIX$taskId"

    private data class ScheduledTask(
        val name: String,
        val request: androidx.work.OneTimeWorkRequest,
    )

    private companion object {
        fun notificationsEnabled(context: Context): Boolean {
            val channel = context.getSystemService(NotificationManager::class.java).getNotificationChannel(TAG)
            return NotificationManagerCompat.from(context).areNotificationsEnabled() &&
                channel?.importance != NotificationManager.IMPORTANCE_NONE
        }

        const val TAG = "flash-task-reminders"
        const val WORK_PREFIX = "flash-task-reminder-"
    }
}

private suspend fun <T> ListenableFuture<T>.awaitValue(): T = suspendCancellableCoroutine { continuation ->
    continuation.invokeOnCancellation { cancel(true) }
    addListener({
        if (!continuation.isActive) return@addListener
        try {
            continuation.resumeWith(Result.success(get()))
        } catch (error: Throwable) {
            continuation.resumeWith(Result.failure(error.cause ?: error))
        }
    }, Runnable::run)
}

private suspend fun Operation.awaitCompletion(): Unit = suspendCancellableCoroutine { continuation ->
    val future = result
    continuation.invokeOnCancellation { future.cancel(true) }
    future.addListener({
        if (!continuation.isActive) return@addListener
        try {
            future.get()
            continuation.resumeWith(Result.success(Unit))
        } catch (error: Throwable) {
            continuation.resumeWith(Result.failure(error.cause ?: error))
        }
    }, Runnable::run)
}

class TaskReminderWorker(
    appContext: Context,
    params: WorkerParameters,
) : Worker(appContext, params) {

    override fun doWork(): Result {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            ContextCompat.checkSelfPermission(applicationContext, Manifest.permission.POST_NOTIFICATIONS) !=
            PackageManager.PERMISSION_GRANTED
        ) return Result.success()
        val manager = NotificationManagerCompat.from(applicationContext)
        if (!manager.areNotificationsEnabled()) return Result.success()

        createChannel()
        val taskId = inputData.getString(KEY_TASK_ID) ?: return Result.failure()
        val title = inputData.getString(KEY_TITLE) ?: "待办任务"
        val intent = Intent(applicationContext, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val pendingIntent = PendingIntent.getActivity(
            applicationContext,
            taskId.hashCode(),
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val notification = NotificationCompat.Builder(applicationContext, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentTitle("Flash 任务提醒")
            .setContentText(title)
            .setContentIntent(pendingIntent)
            .setAutoCancel(true)
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
            .build()
        manager.notify(taskId.hashCode(), notification)
        return Result.success()
    }

    private fun createChannel() {
        val channel = NotificationChannel(
            CHANNEL_ID,
            "任务提醒",
            NotificationManager.IMPORTANCE_DEFAULT,
        ).apply { description = "Calendar 任务的本地提醒" }
        applicationContext.getSystemService(NotificationManager::class.java)
            .createNotificationChannel(channel)
    }

    companion object {
        const val KEY_TASK_ID = "taskId"
        const val KEY_TITLE = "title"
        private const val CHANNEL_ID = "flash-task-reminders"
    }
}
