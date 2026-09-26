// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package com.flash.app.domain

import java.time.LocalDate
import com.flash.app.data.model.*
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class ReviewInsightTest {

    private val today = LocalDate.of(2026, 9, 26) // 周六：本周窗口 [09-21, 09-26]，前窗 [09-15, 09-20]

    private fun log(date: String, id: String = date) =
        LogItem(id, "x", ColorTag.DAILY, Category.LOG, 0, "2026-09-19T00:00:00.000Z", date)

    private fun emotion(date: String, level: EmotionLevel = EmotionLevel.HAPPY, id: String = date) =
        EmotionRecord(id, level, null, null, null, date, "2026-09-19T00:00:00.000Z")

    @Test fun insufficientDataGivesNoConclusion() {
        val insight = reviewInsight(
            logs = listOf(log("2026-09-25"), log("2026-09-22")),
            emotions = listOf(emotion("2026-09-18")),
            window = ReviewWindow.WEEK,
            today = today,
        )
        assertEquals(2, insight.currentCount)
        assertEquals(1, insight.previousCount)
        assertFalse(insight.hasEnoughData)
    }

    @Test fun trendComparesCurrentAndPreviousWindows() {
        val more = reviewInsight(
            logs = (21..25).map { log("2026-09-$it") },
            emotions = listOf(emotion("2026-09-16")),
            window = ReviewWindow.WEEK,
            today = today,
        )
        assertEquals(5, more.currentCount)
        assertEquals(1, more.previousCount)
        assertTrue(more.hasEnoughData)
        assertEquals(ReviewInsight.Trend.MORE, more.trend)

        val less = reviewInsight(
            logs = listOf(log("2026-09-25")),
            emotions = (15..19).map { emotion("2026-09-$it") },
            window = ReviewWindow.WEEK,
            today = today,
        )
        assertEquals(ReviewInsight.Trend.LESS, less.trend)

        val same = reviewInsight(
            logs = listOf(log("2026-09-22"), log("2026-09-24")),
            emotions = (16..18).map { emotion("2026-09-$it") },
            window = ReviewWindow.WEEK,
            today = today,
        )
        assertEquals(2, same.currentCount)
        assertEquals(3, same.previousCount)
        // 合计 5 条刚好达标，current < previous
        assertTrue(same.hasEnoughData)
        assertEquals(ReviewInsight.Trend.LESS, same.trend)

        val tie = reviewInsight(
            logs = listOf(log("2026-09-22"), log("2026-09-24"), log("2026-09-17")),
            emotions = listOf(emotion("2026-09-16"), emotion("2026-09-23")),
            window = ReviewWindow.WEEK,
            today = today,
        )
        assertEquals(3, tie.currentCount)
        assertEquals(2, tie.previousCount)
        assertEquals(ReviewInsight.Trend.MORE, tie.trend)
    }

    @Test fun previousWindowIsEqualLengthAndAdjacent() {
        // 周三：本周窗口 [09-21, 09-23] 共 3 天，前窗应为 [09-18, 09-20]
        val wednesday = LocalDate.of(2026, 9, 23)
        val insight = reviewInsight(
            logs = listOf(log("2026-09-17"), log("2026-09-18"), log("2026-09-20"), log("2026-09-21")),
            emotions = listOf(emotion("2026-09-22")),
            window = ReviewWindow.WEEK,
            today = wednesday,
        )
        assertEquals(2, insight.currentCount)
        assertEquals(2, insight.previousCount)
    }

    @Test fun rollingWindowsUseSameRule() {
        val insight = reviewInsight(
            logs = (1..6).map { log("2026-08-%02d".format(it), id = "p$it") }, // 前 30 天窗口内
            emotions = emptyList(),
            window = ReviewWindow.DAYS_30,
            today = today,
        )
        assertEquals(0, insight.currentCount)
        assertEquals(6, insight.previousCount)
        assertTrue(insight.hasEnoughData)
        assertEquals(ReviewInsight.Trend.LESS, insight.trend)
    }

    @Test fun emotionShiftNeedsBothWindowsAndThreshold() {
        // 前窗均值 -2，当前窗均值 +2：Δ=4 ≥ 0.5
        val up = reviewInsight(
            logs = (21..24).map { log("2026-09-$it") },
            emotions = listOf(
                emotion("2026-09-16", EmotionLevel.UNHAPPY, "a"),
                emotion("2026-09-22", EmotionLevel.HAPPY, "b"),
            ),
            window = ReviewWindow.WEEK,
            today = today,
        )
        assertEquals(-2.0, up.previousEmotionMean!!, 0.001)
        assertEquals(2.0, up.currentEmotionMean!!, 0.001)
        assertEquals(ReviewInsight.Trend.MORE, up.emotionShift)

        // 小幅波动（Δ=0.25 < 0.5）不提示
        val flat = reviewInsight(
            logs = (21..24).map { log("2026-09-$it") },
            emotions = listOf(
                emotion("2026-09-16", EmotionLevel.NEUTRAL, "a"),
                emotion("2026-09-16", EmotionLevel.NEUTRAL, "b"),
                emotion("2026-09-22", EmotionLevel.NEUTRAL, "c"),
                emotion("2026-09-22", EmotionLevel.NEUTRAL, "d"),
                emotion("2026-09-22", EmotionLevel.NEUTRAL, "e"),
                emotion("2026-09-22", EmotionLevel.SLIGHTLY_HAPPY, "f"),
            ),
            window = ReviewWindow.WEEK,
            today = today,
        )
        assertEquals(0.25, flat.currentEmotionMean!!, 0.001)
        assertNull(flat.emotionShift)

        // 只有一个窗口有情绪数据 → 不提示
        val oneSided = reviewInsight(
            logs = (21..24).map { log("2026-09-$it") },
            emotions = listOf(emotion("2026-09-22", EmotionLevel.VERY_UNHAPPY, "a")),
            window = ReviewWindow.WEEK,
            today = today,
        )
        assertNull(oneSided.previousEmotionMean)
        assertNull(oneSided.emotionShift)
    }
}
