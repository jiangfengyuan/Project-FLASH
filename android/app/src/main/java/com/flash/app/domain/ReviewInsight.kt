// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package com.flash.app.domain

import com.flash.app.data.model.EmotionRecord
import com.flash.app.data.model.LogItem
import java.time.LocalDate
import kotlin.math.roundToInt

/**
 * 回顾页洞察：当前时间窗口 vs 前一等长窗口的对比结论。
 * 记录数 = 日志/灵感 + 情绪次数（与 [dailyActivity] 口径一致，任务不计入）。
 * 两窗口合计不足 [MIN_RECORDS] 条时不给趋势结论。
 */
data class ReviewInsight(
    val currentCount: Int,
    val previousCount: Int,
    val currentEmotionMean: Double?,
    val previousEmotionMean: Double?,
) {
    val hasEnoughData: Boolean get() = currentCount + previousCount >= MIN_RECORDS

    val trend: Trend
        get() = when {
            currentCount > previousCount -> Trend.MORE
            currentCount < previousCount -> Trend.LESS
            else -> Trend.SAME
        }

    /** 情绪均值显著变化（两窗均有情绪数据且 |Δ| ≥ [EMOTION_SHIFT_THRESHOLD]）时的方向，否则 null。 */
    val emotionShift: Trend?
        get() {
            val current = currentEmotionMean ?: return null
            val previous = previousEmotionMean ?: return null
            val delta = current - previous
            return when {
                delta >= EMOTION_SHIFT_THRESHOLD -> Trend.MORE
                delta <= -EMOTION_SHIFT_THRESHOLD -> Trend.LESS
                else -> null
            }
        }

    enum class Trend { MORE, SAME, LESS }

    companion object {
        const val MIN_RECORDS = 5
        const val EMOTION_SHIFT_THRESHOLD = 0.5
    }
}

private fun inRange(recordDate: String, start: LocalDate, end: LocalDate): Boolean =
    recordDate >= start.toString() && recordDate <= end.toString()

fun reviewInsight(
    logs: List<LogItem>,
    emotions: List<EmotionRecord>,
    window: ReviewWindow,
    today: LocalDate,
): ReviewInsight {
    val days = window.days(today).toLong()
    val start = window.start(today)
    val previousStart = start.minusDays(days)
    val previousEnd = start.minusDays(1)

    fun count(from: LocalDate, to: LocalDate): Int =
        logs.count { inRange(it.recordDate, from, to) } +
            emotions.count { inRange(it.recordDate, from, to) }

    fun emotionMean(from: LocalDate, to: LocalDate): Double? = emotions
        .filter { inRange(it.recordDate, from, to) }
        .map { it.level.value }
        .takeIf { it.isNotEmpty() }
        ?.average()
        ?.let { (it * 100).roundToInt() / 100.0 }

    return ReviewInsight(
        currentCount = count(start, today),
        previousCount = count(previousStart, previousEnd),
        currentEmotionMean = emotionMean(start, today),
        previousEmotionMean = emotionMean(previousStart, previousEnd),
    )
}
