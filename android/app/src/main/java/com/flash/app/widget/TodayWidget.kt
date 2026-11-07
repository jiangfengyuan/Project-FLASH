// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package com.flash.app.widget

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.widget.RemoteViews
import com.flash.app.FlashApplication
import com.flash.app.MainActivity
import com.flash.app.R
import com.flash.app.data.FlashRepository
import com.flash.app.i18n.tr
import java.time.LocalDate
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.conflate
import kotlinx.coroutines.flow.distinctUntilChanged
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch

/** 小组件只显示计数，不显示记录内容（主屏对旁人可见）。 */
internal data class TodaySnapshot(val records: Int, val tasks: Int)

/**
 * 主屏「Flash 此刻」（对齐 iOS FlashTodayWidget）：今日记录与待办；
 * 宽度足够时显示「灵感 / 日志」按钮。用 RemoteViews，不引入 Glance。
 */
class TodayWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        val pending = goAsync()
        CoroutineScope(Dispatchers.IO).launch {
            try {
                val snapshot = TodayWidgetUpdater.snapshot(context)
                ids.forEach { render(context, manager, it, snapshot) }
            } finally {
                pending.finish()
            }
        }
    }

    override fun onAppWidgetOptionsChanged(context: Context, manager: AppWidgetManager, id: Int, options: Bundle) {
        onUpdate(context, manager, intArrayOf(id))
    }

    companion object {
        /** 宽度 ≥ 这个值时用中号布局（可放下按钮） */
        private const val MEDIUM_MIN_WIDTH_DP = 220

        internal fun render(context: Context, manager: AppWidgetManager, id: Int, snapshot: TodaySnapshot) {
            val width = manager.getAppWidgetOptions(id).getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH)
            val medium = width >= MEDIUM_MIN_WIDTH_DP
            val views = RemoteViews(context.packageName, if (medium) R.layout.widget_today_medium else R.layout.widget_today_small)
            views.setTextViewText(R.id.widget_title, tr("✦ Flash"))
            views.setTextViewText(R.id.widget_records, snapshot.records.toString())
            views.setTextViewText(R.id.widget_records_label, tr("今日记录"))
            views.setTextViewText(R.id.widget_tasks, tr("{0} 项待办", snapshot.tasks))
            views.setOnClickPendingIntent(R.id.widget_root, deepLink(context, "flash://today", 1))
            if (medium) {
                views.setTextViewText(R.id.widget_button_idea, tr("灵感"))
                views.setTextViewText(R.id.widget_button_log, tr("日志"))
                views.setOnClickPendingIntent(R.id.widget_button_idea, deepLink(context, "flash://capture?category=idea", 2))
                views.setOnClickPendingIntent(R.id.widget_button_log, deepLink(context, "flash://capture?category=log", 3))
            }
            manager.updateAppWidget(id, views)
        }

        private fun deepLink(context: Context, uri: String, code: Int): PendingIntent = PendingIntent.getActivity(
            context,
            code,
            Intent(Intent.ACTION_VIEW, Uri.parse(uri), context, MainActivity::class.java)
                .addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }
}

object TodayWidgetUpdater {
    internal suspend fun snapshot(context: Context): TodaySnapshot {
        val repository = (context.applicationContext as FlashApplication).repository
        val today = LocalDate.now().toString()
        val records = repository.logs.first().count { it.recordDate == today }
        val tasks = repository.tasks.first().count { !it.isCompleted }
        return TodaySnapshot(records, tasks)
    }

    /** 进程存活时跟随数据变化刷新；无小组件时不做事 */
    fun observe(context: Context, repository: FlashRepository) {
        val appContext = context.applicationContext
        val component = ComponentName(appContext, TodayWidgetProvider::class.java)
        CoroutineScope(SupervisorJob() + Dispatchers.IO).launch {
            combine(repository.logs, repository.tasks) { logs, tasks ->
                val today = LocalDate.now().toString()
                TodaySnapshot(logs.count { it.recordDate == today }, tasks.count { !it.isCompleted })
            }.distinctUntilChanged().conflate().collect { snapshot ->
                val manager = AppWidgetManager.getInstance(appContext)
                manager.getAppWidgetIds(component).forEach { TodayWidgetProvider.render(appContext, manager, it, snapshot) }
            }
        }
    }
}
