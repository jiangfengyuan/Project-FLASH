// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package com.flash.app.domain

import com.flash.app.data.model.EmotionLevel
import com.flash.app.data.model.EmotionRecord
import com.flash.app.data.model.SubEmotion
import java.time.DayOfWeek
import java.time.LocalDate
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class EmotionStatsTest {

    private fun record(
        date: String,
        level: EmotionLevel = EmotionLevel.HAPPY,
        subEmotion: SubEmotion? = null,
    ) = EmotionRecord(
        id = date,
        level = level,
        subEmotion = subEmotion,
        status = null,
        note = null,
        recordDate = date,
        createdAt = "${date}T00:00:00",
    )

    // 2026-08-31 是周一，2026-09-06 是周日（同一自然周，跨 8/9 月）

    @Test
    fun `currentWeek on Monday returns week starting that day`() {
        val monday = LocalDate.of(2026, 8, 31)
        assertEquals(DayOfWeek.MONDAY, monday.dayOfWeek)
        val (start, end) = EmotionStats.currentWeek(monday)
        assertEquals(LocalDate.of(2026, 8, 31), start)
        assertEquals(LocalDate.of(2026, 9, 6), end)
    }

    @Test
    fun `currentWeek on Sunday belongs to week started previous Monday`() {
        val sunday = LocalDate.of(2026, 9, 6)
        assertEquals(DayOfWeek.SUNDAY, sunday.dayOfWeek)
        val (start, end) = EmotionStats.currentWeek(sunday)
        assertEquals(LocalDate.of(2026, 8, 31), start)
        assertEquals(LocalDate.of(2026, 9, 6), end)
    }

    @Test
    fun `currentWeek midweek aligns to Monday across month boundary`() {
        // 2026-09-02 周三 → 本周一在上个月（8-31）
        val (start, end) = EmotionStats.currentWeek(LocalDate.of(2026, 9, 2))
        assertEquals(LocalDate.of(2026, 8, 31), start)
        assertEquals(LocalDate.of(2026, 9, 6), end)
    }

    @Test
    fun `currentWeek on Monday whose Sunday crosses year boundary`() {
        // 2025-12-29 周一 → 周日在 2026-01-04
        val monday = LocalDate.of(2025, 12, 29)
        assertEquals(DayOfWeek.MONDAY, monday.dayOfWeek)
        val (start, end) = EmotionStats.currentWeek(monday)
        assertEquals(LocalDate.of(2025, 12, 29), start)
        assertEquals(LocalDate.of(2026, 1, 4), end)
    }

    @Test
    fun `currentWeek in new year reaches back to Monday in previous year`() {
        // 2026-01-01 周四 → 本周一是 2025-12-29
        val (start, end) = EmotionStats.currentWeek(LocalDate.of(2026, 1, 1))
        assertEquals(LocalDate.of(2025, 12, 29), start)
        assertEquals(LocalDate.of(2026, 1, 4), end)
    }

    @Test
    fun `rollingWindow covers last N days ending today`() {
        val (start, end) = EmotionStats.rollingWindow(7, LocalDate.of(2026, 9, 5))
        assertEquals(LocalDate.of(2026, 8, 30), start)
        assertEquals(LocalDate.of(2026, 9, 5), end)
    }

    @Test
    fun `dailyAverages over current week includes Monday to Sunday only`() {
        val emotions = listOf(
            record("2026-08-30", EmotionLevel.VERY_UNHAPPY), // 上周日，窗口外
            record("2026-08-31", EmotionLevel.HAPPY), // 周一，+2
            record("2026-08-31", EmotionLevel.NEUTRAL), // 周一，0 → 日均 1.0
            record("2026-09-06", EmotionLevel.SLIGHTLY_UNHAPPY), // 周日，-1
        )
        val (start, end) = EmotionStats.currentWeek(LocalDate.of(2026, 9, 2))
        val averages = EmotionStats.getDailyAverages(emotions, start, end)

        assertEquals(7, averages.size)
        assertEquals(LocalDate.of(2026, 8, 31), averages.first().first)
        assertEquals(LocalDate.of(2026, 9, 6), averages.last().first)
        assertEquals(1.0, averages[0].second!!, 0.0)
        assertNull(averages[1].second) // 周二无记录
        assertEquals(-1.0, averages[6].second!!, 0.0)
    }

    @Test
    fun `hasEmotionData and distribution respect week window`() {
        val emotions = listOf(
            record("2026-08-30", EmotionLevel.UNHAPPY, SubEmotion.SAD), // 上周日，窗口外
            record("2026-09-01", EmotionLevel.UNHAPPY, SubEmotion.ANGRY), // 周二，窗口内
        )
        val (start, end) = EmotionStats.currentWeek(LocalDate.of(2026, 9, 2))

        assertTrue(EmotionStats.hasEmotionData(emotions, start, end))
        assertEquals(listOf("生气" to 1), EmotionStats.getSubEmotionDistribution(emotions, start, end))

        // 窗口内只有窗口外记录时视为无数据
        assertFalse(EmotionStats.hasEmotionData(emotions.take(1), start, end))
    }
}
