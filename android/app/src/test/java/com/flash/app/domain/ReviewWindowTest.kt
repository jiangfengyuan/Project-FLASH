// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package com.flash.app.domain

import java.time.LocalDate
import com.flash.app.data.model.*
import org.junit.Assert.assertEquals
import org.junit.Test

class ReviewWindowTest {
    @Test fun activityCountsUseRecordDatesAndFillEmptyDays() {
        val start = LocalDate.of(2024, 2, 28)
        val end = LocalDate.of(2024, 3, 1)
        val log = LogItem("a", "x", ColorTag.DAILY, Category.LOG, 0,
            "2026-09-19T00:00:00.000Z", "2024-02-29")
        val idea = log.copy(id = "b", category = Category.IDEA)
        val emotion = EmotionRecord("e", EmotionLevel.HAPPY, null, null, null,
            "2024-03-01", "2026-09-19T00:00:00.000Z")
        val result = dailyActivity(listOf(log, idea, log.copy(id = "future", recordDate = "2024-03-02")),
            listOf(emotion), start, end)
        assertEquals(listOf(0, 2, 1), result.map { it.total })
        assertEquals(listOf(0, 2, 0), result.map { it.records })
        assertEquals(listOf(0, 0, 1), result.map { it.emotions })
        assertEquals(listOf("2024-02-28", "2024-02-29", "2024-03-01"), result.map { it.date.toString() })
        assertEquals(listOf(1, 0, 0), dailyActivity(listOf(log.copy(recordDate = "2024-02-28")),
            emptyList(), start, end).map { it.total })
        assertEquals(emptyList<DailyActivity>(), dailyActivity(emptyList(), emptyList(), end, start))
    }

    @Test fun calendarAndRollingBoundaries() {
        val saturday = LocalDate.of(2026, 9, 19)
        assertEquals(LocalDate.of(2026, 9, 14), ReviewWindow.WEEK.start(saturday))
        assertEquals(1, ReviewWindow.WEEK.days(LocalDate.of(2026, 9, 14)))
        assertEquals(7, ReviewWindow.WEEK.days(LocalDate.of(2026, 9, 20)))
        assertEquals(LocalDate.of(2026, 9, 1), ReviewWindow.MONTH.start(saturday))
        assertEquals(29, ReviewWindow.MONTH.days(LocalDate.of(2024, 2, 29)))
        assertEquals(LocalDate.of(2026, 12, 28), ReviewWindow.WEEK.start(LocalDate.of(2027, 1, 1)))
        assertEquals(saturday.minusDays(29), ReviewWindow.DAYS_30.start(saturday))
        assertEquals(saturday.minusDays(89), ReviewWindow.DAYS_90.start(saturday))
    }
}
