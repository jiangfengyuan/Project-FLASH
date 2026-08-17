// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package com.flash.app.domain

import com.flash.app.data.model.EmotionRecord
import java.time.LocalDate
import kotlin.math.roundToInt

/**
 * 情绪统计算法，与 Web 版 src/lib/emotionStats.ts 一一对应。
 * recordDate 格式为 yyyy-MM-dd。
 */
object EmotionStats {

    private fun window(days: Int, today: LocalDate): Pair<LocalDate, LocalDate> =
        today.minusDays(days - 1L) to today

    private fun inWindow(recordDate: String, start: LocalDate, end: LocalDate): Boolean {
        val d = LocalDate.parse(recordDate)
        return !d.isBefore(start) && !d.isAfter(end)
    }

    fun hasEmotionData(
        emotions: List<EmotionRecord>,
        days: Int,
        today: LocalDate = LocalDate.now(),
    ): Boolean {
        val (start, end) = window(days, today)
        return emotions.any { inWindow(it.recordDate, start, end) }
    }

    /** 返回 [start, today] 每天的平均情绪值；当日无记录则为 null。 */
    fun getDailyAverages(
        emotions: List<EmotionRecord>,
        days: Int,
        today: LocalDate = LocalDate.now(),
    ): List<Pair<LocalDate, Double?>> {
        val (start, end) = window(days, today)
        val grouped = emotions
            .filter { inWindow(it.recordDate, start, end) }
            .groupBy({ it.recordDate }, { it.level.value })

        return (0 until days).map { i ->
            val date = start.plusDays(i.toLong())
            val levels = grouped[date.toString()]
            val average = levels?.average()?.let { (it * 100).roundToInt() / 100.0 }
            date to average
        }
    }

    /** 负面情绪子类型（伤心/生气/难受）在时间窗内的分布，key 为中文名。 */
    fun getSubEmotionDistribution(
        emotions: List<EmotionRecord>,
        days: Int,
        today: LocalDate = LocalDate.now(),
    ): List<Pair<String, Int>> {
        val (start, end) = window(days, today)
        return emotions
            .filter { it.level.isNegative && it.subEmotion != null }
            .filter { inWindow(it.recordDate, start, end) }
            .groupingBy { it.subEmotion!!.displayName }
            .eachCount()
            .toList()
    }
}
