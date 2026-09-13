// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package com.flash.app.domain

import com.flash.app.data.model.EmotionRecord
import java.time.DayOfWeek
import java.time.LocalDate
import java.time.temporal.ChronoUnit
import java.time.temporal.TemporalAdjusters
import kotlin.math.roundToInt

/**
 * 情绪统计算法，与 macOS EmotionStats.swift / Web 版 src/lib/emotionStats.ts 对应。
 * recordDate 格式为 yyyy-MM-dd。
 *
 * 时间窗口径分两种，由调用方按展示位选择：
 * - [rollingWindow]：滚动 N 天（含今天），对应 macOS 统计页「近 7/30 天」；
 * - [currentWeek]：周一对齐的自然周（本周一至周日，本地时区），
 *   与 macOS DateWindows.currentWeek() 逐点一致，对应 macOS 情绪页「本周趋势」。
 */
object EmotionStats {

    /** 滚动 N 天窗口（含今天）：[today - (days-1), today]。 */
    fun rollingWindow(days: Int, today: LocalDate = LocalDate.now()): Pair<LocalDate, LocalDate> =
        today.minusDays(days - 1L) to today

    /** 周一对齐的本周窗口：[本周一, 本周日]（含未来日期，与 macOS 端一致按 7 天展示）。 */
    fun currentWeek(today: LocalDate = LocalDate.now()): Pair<LocalDate, LocalDate> {
        val monday = today.with(TemporalAdjusters.previousOrSame(DayOfWeek.MONDAY))
        return monday to monday.plusDays(6)
    }

    private fun inWindow(recordDate: String, start: LocalDate, end: LocalDate): Boolean {
        // yyyy-MM-dd 字典序即时间序，避免 LocalDate.parse 在非法日期时抛异常
        val startKey = start.toString()
        val endKey = end.toString()
        return recordDate >= startKey && recordDate <= endKey
    }

    fun hasEmotionData(
        emotions: List<EmotionRecord>,
        start: LocalDate,
        end: LocalDate,
    ): Boolean = emotions.any { inWindow(it.recordDate, start, end) }

    /** 返回 [start, end] 每天的平均情绪值；当日无记录则为 null。 */
    fun getDailyAverages(
        emotions: List<EmotionRecord>,
        start: LocalDate,
        end: LocalDate,
    ): List<Pair<LocalDate, Double?>> {
        val grouped = emotions
            .filter { inWindow(it.recordDate, start, end) }
            .groupBy({ it.recordDate }, { it.level.value })

        val days = ChronoUnit.DAYS.between(start, end).toInt() + 1
        return (0 until days).map { i ->
            val date = start.plusDays(i.toLong())
            val levels = grouped[date.toString()]
            val average = levels?.average()?.let { (it * 100).roundToInt() / 100.0 }
            date to average
        }
    }

    /** 负面情绪子类型（伤心/生气/难受）在 [start, end] 内的分布，key 为中文名。 */
    fun getSubEmotionDistribution(
        emotions: List<EmotionRecord>,
        start: LocalDate,
        end: LocalDate,
    ): List<Pair<String, Int>> = emotions
        .filter { it.level.isNegative && it.subEmotion != null }
        .filter { inWindow(it.recordDate, start, end) }
        .groupingBy { it.subEmotion!!.displayName }
        .eachCount()
        .toList()
}
