// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package com.flash.app.domain

import com.flash.app.data.model.Category
import com.flash.app.data.model.EmotionRecord
import com.flash.app.data.model.LogItem
import com.flash.app.data.model.TaskItem
import com.flash.app.i18n.tr
import java.time.DayOfWeek
import java.time.LocalDate
import java.time.temporal.TemporalAdjusters

/**
 * Memory 周报聚合（规则版，无 AI），口径与 FlashCore/Domain/WeeklyMemory.swift 一致：
 * 周一到周日的自然周；日志/灵感/情绪按记录日期，任务按日历日落周。
 */
object WeeklyMemory {
    data class MoodSummary(val average: Double, val emoji: String, val text: String)

    data class Report(
        val weekStart: String,
        val weekEnd: String,
        val moments: Int,
        val ideas: Int,
        val tasks: Int,
        val emotions: Int,
        val mood: MoodSummary?,
        val highlights: List<String>,
        val hasData: Boolean,
    )

    const val HIGHLIGHT_LIMIT = 4
    const val POSITIVE_THRESHOLD = 1.0
    const val NEGATIVE_THRESHOLD = -1.0

    fun report(
        logs: List<LogItem>,
        emotions: List<EmotionRecord>,
        tasks: List<TaskItem>,
        baseDate: LocalDate = LocalDate.now(),
    ): Report {
        val monday = baseDate.with(TemporalAdjusters.previousOrSame(DayOfWeek.MONDAY))
        val weekStart = monday.toString()
        val weekEnd = monday.plusDays(6).toString()
        fun inWeek(day: String) = day >= weekStart && day <= weekEnd

        val weekLogs = logs.filter { inWeek(it.recordDate) }
        val weekEmotions = emotions.filter { inWeek(it.recordDate) }
        val weekTasks = tasks.filter { task -> runCatching { inWeek(task.calendarDate) }.getOrDefault(false) }
        val moments = weekLogs.count { it.category == Category.LOG }
        val ideas = weekLogs.count { it.category == Category.IDEA }
        val highlights = weekLogs
            .sortedWith(
                compareByDescending<LogItem> { it.isFavorite == true }
                    .thenByDescending { it.importance }
                    .thenByDescending { it.createdAt },
            )
            .take(HIGHLIGHT_LIMIT)
            .map(::highlightTitle)
        return Report(
            weekStart = weekStart,
            weekEnd = weekEnd,
            moments = moments,
            ideas = ideas,
            tasks = weekTasks.size,
            emotions = weekEmotions.size,
            mood = moodSummary(weekEmotions),
            highlights = highlights,
            hasData = moments + ideas + weekTasks.size + weekEmotions.size > 0,
        )
    }

    private fun moodSummary(emotions: List<EmotionRecord>): MoodSummary? {
        if (emotions.isEmpty()) return null
        val mean = emotions.sumOf { it.level.value }.toDouble() / emotions.size
        val average = kotlin.math.floor(mean * 100 + 0.5) / 100
        return when {
            average >= POSITIVE_THRESHOLD -> MoodSummary(average, "😊", tr("Mostly Positive"))
            average <= NEGATIVE_THRESHOLD -> MoodSummary(average, "😔", tr("Mostly Low"))
            else -> MoodSummary(average, "🙂", tr("Mostly Steady"))
        }
    }

    private fun highlightTitle(log: LogItem): String {
        val first = log.content.substringBefore('\n').trim()
        return first.ifEmpty { tr("（无标题）") }
    }
}
