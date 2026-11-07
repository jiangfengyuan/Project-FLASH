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
import android.net.Uri
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import androidx.work.CoroutineWorker
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.WorkerParameters
import com.flash.app.FlashApplication
import com.flash.app.MainActivity
import com.flash.app.R
import com.flash.app.domain.ideaReminderDue
import com.flash.app.domain.shouldShowIdeaReminder
import com.flash.app.i18n.tr
import java.time.Duration
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.ZoneId
import java.util.concurrent.TimeUnit
import kotlinx.coroutines.flow.first

/**
 * 灵感提醒（对齐 iOS）：未读灵感 ≥ 3 时，每天晚上约 8 点检查一次，按「每天 / 每 3 天 / 每周」发本地通知。
 * 用 WorkManager，不申请精确闹钟权限，系统可能略有延迟。关闭时取消周期任务。
 */
object IdeaReminderWork {
    private const val WORK_NAME = "flash-idea-reminder"
    const val REMINDER_HOUR = 20

    fun sync(context: Context, enabled: Boolean) {
        val manager = WorkManager.getInstance(context.applicationContext)
        if (!enabled) {
            manager.cancelUniqueWork(WORK_NAME)
            return
        }
        val request = PeriodicWorkRequestBuilder<IdeaReminderWorker>(1, TimeUnit.DAYS)
            .setInitialDelay(delayUntilNext(LocalDateTime.now()).toMinutes(), TimeUnit.MINUTES)
            .build()
        manager.enqueueUniquePeriodicWork(WORK_NAME, ExistingPeriodicWorkPolicy.KEEP, request)
    }

    /** 到下一个晚上 8 点的时长 */
    internal fun delayUntilNext(now: LocalDateTime): Duration {
        val today = now.toLocalDate().atTime(REMINDER_HOUR, 0)
        val target = if (now.isBefore(today)) today else today.plusDays(1)
        return Duration.between(now, target)
    }
}

class IdeaReminderWorker(appContext: Context, params: WorkerParameters) : CoroutineWorker(appContext, params) {
    override suspend fun doWork(): Result {
        val app = applicationContext as FlashApplication
        val settings = app.settings
        if (!settings.ideaReminderEnabled.value) return Result.success()
        val count = app.repository.unviewedIdeas.first().size
        if (!shouldShowIdeaReminder(count)) return Result.success()
        val today = LocalDate.now()
        val lastFired = settings.ideaReminderLastFiredAt
            .takeIf { it > 0 }
            ?.let { java.time.Instant.ofEpochMilli(it).atZone(ZoneId.systemDefault()).toLocalDate() }
        if (!ideaReminderDue(lastFired, today, settings.ideaReminderFrequency.value.intervalDays)) return Result.success()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            ContextCompat.checkSelfPermission(applicationContext, Manifest.permission.POST_NOTIFICATIONS) !=
            PackageManager.PERMISSION_GRANTED
        ) return Result.success()
        val manager = NotificationManagerCompat.from(applicationContext)
        if (!manager.areNotificationsEnabled()) return Result.success()
        applicationContext.getSystemService(NotificationManager::class.java).createNotificationChannel(
            NotificationChannel(CHANNEL_ID, tr("灵感提醒"), NotificationManager.IMPORTANCE_DEFAULT),
        )
        val open = PendingIntent.getActivity(
            applicationContext,
            NOTIFICATION_ID,
            Intent(Intent.ACTION_VIEW, Uri.parse("flash://ideas"), applicationContext, MainActivity::class.java)
                .addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        // 通知正文不含灵感内容，只有数量（锁屏也安全）
        val notification = NotificationCompat.Builder(applicationContext, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle(tr("想法等待梳理"))
            .setContentText(tr("你还有{0}个想法等待梳理，去看看吧", count))
            .setContentIntent(open)
            .setAutoCancel(true)
            .build()
        manager.notify(NOTIFICATION_ID, notification)
        settings.ideaReminderLastFiredAt = System.currentTimeMillis()
        return Result.success()
    }

    private companion object {
        const val CHANNEL_ID = "flash-idea-reminders"
        const val NOTIFICATION_ID = 7201
    }
}
