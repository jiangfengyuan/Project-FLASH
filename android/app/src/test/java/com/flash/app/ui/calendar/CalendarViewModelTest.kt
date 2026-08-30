// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package com.flash.app.ui.calendar

import com.flash.app.data.model.Category
import com.flash.app.data.model.ColorTag
import com.flash.app.data.model.EmotionLevel
import com.flash.app.data.model.EmotionRecord
import com.flash.app.data.model.LogItem
import java.time.LocalDate
import java.time.YearMonth
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class CalendarViewModelTest {

    @Test
    fun `calendar grid is six Monday-first weeks`() {
        val weeks = buildCalendarWeeks(YearMonth.of(2026, 8))

        assertEquals(6, weeks.size)
        assertEquals(7, weeks.first().size)
        assertEquals(LocalDate.of(2026, 7, 27), weeks.first().first())
        assertEquals(LocalDate.of(2026, 9, 6), weeks.last().last())
    }

    @Test
    fun `aggregation groups logs and emotions in one date index`() {
        val firstLog = log("log-1", "2026-08-30")
        val secondLog = log("log-2", "2026-08-30")
        val emotion = emotion("emotion-1", "2026-08-31")

        val result = aggregateByDate(listOf(firstLog, secondLog), listOf(emotion))

        assertEquals(listOf("2026-08-30", "2026-08-31"), result.keys.toList())
        assertEquals(listOf(firstLog, secondLog), result["2026-08-30"]?.logs)
        assertEquals(listOf(emotion), result["2026-08-31"]?.emotions)
        assertNull(result["2026-09-01"])
    }

    private fun log(id: String, date: String) = LogItem(
        id = id,
        content = id,
        colorTag = ColorTag.DAILY,
        category = Category.LOG,
        importance = 0,
        createdAt = "${date}T08:00:00.000Z",
        recordDate = date,
    )

    private fun emotion(id: String, date: String) = EmotionRecord(
        id = id,
        level = EmotionLevel.NEUTRAL,
        subEmotion = null,
        status = null,
        note = null,
        recordDate = date,
        createdAt = "${date}T09:00:00.000Z",
    )
}
