// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package com.flash.app.domain

import com.flash.app.data.model.Category
import com.flash.app.data.model.ColorTag
import com.flash.app.data.model.EmotionLevel
import com.flash.app.data.model.EmotionRecord
import com.flash.app.data.model.LogItem
import com.flash.app.data.model.TaskDueKind
import com.flash.app.data.model.TaskItem
import java.time.LocalDate
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/** 与 FlashCoreTests/WeeklyMemoryTests 同一组夹具：基准日 2026-08-13（周四），本周 08-10 ~ 08-16。 */
class WeeklyMemoryTest {
    private val base = LocalDate.parse("2026-08-13")
    private var seq = 0

    private fun log(day: String, content: String = "x", category: Category = Category.LOG, importance: Int = 0,
                    favorite: Boolean? = null, createdAt: String = "${day}T08:00:00.000Z") =
        LogItem("l${seq++}", content, ColorTag.DAILY, category, importance, createdAt, day, favorite)

    private fun emotion(day: String, level: EmotionLevel) =
        EmotionRecord("e${seq++}", level, null, null, null, day, "${day}T08:00:00.000Z")

    private fun task(day: String) = TaskItem(
        "t${seq++}", "t", null, ColorTag.DAILY, 0, TaskDueKind.ALL_DAY, day, null, null, null, null,
        "2026-08-13T08:00:00.000Z", "2026-08-13T08:00:00.000Z",
    )

    @Test
    fun emptyWeekHasNoData() {
        val report = WeeklyMemory.report(emptyList(), emptyList(), emptyList(), base)
        assertEquals("2026-08-10", report.weekStart)
        assertEquals("2026-08-16", report.weekEnd)
        assertFalse(report.hasData)
        assertNull(report.mood)
        assertTrue(report.highlights.isEmpty())
    }

    @Test
    fun countsEachCategoryInWeek() {
        val report = WeeklyMemory.report(
            listOf(log("2026-08-10"), log("2026-08-11"), log("2026-08-12", category = Category.IDEA)),
            listOf(emotion("2026-08-13", EmotionLevel.HAPPY), emotion("2026-08-14", EmotionLevel.NEUTRAL)),
            listOf(task("2026-08-15")),
            base,
        )
        assertEquals(2, report.moments)
        assertEquals(1, report.ideas)
        assertEquals(1, report.tasks)
        assertEquals(2, report.emotions)
        assertTrue(report.hasData)
    }

    @Test
    fun weekBoundariesIncludeMondayAndSundayOnly() {
        val report = WeeklyMemory.report(
            listOf(log("2026-08-10"), log("2026-08-16"), log("2026-08-09"), log("2026-08-17")),
            listOf(emotion("2026-08-09", EmotionLevel.HAPPY)),
            listOf(task("2026-08-16"), task("2026-08-17")),
            base,
        )
        assertEquals(2, report.moments)
        assertEquals(1, report.tasks)
        assertEquals(0, report.emotions)
    }

    @Test
    fun highlightsFavoritesFirstThenImportanceLimitFour() {
        val report = WeeklyMemory.report(
            listOf(
                log("2026-08-12", "普通4", importance = 4),
                log("2026-08-12", "普通3", importance = 3),
                log("2026-08-12", "普通2", importance = 2),
                log("2026-08-12", "普通1", importance = 1),
                log("2026-08-12", "收藏\n第二行", importance = 0, favorite = true),
            ),
            emptyList(),
            emptyList(),
            base,
        )
        assertEquals(listOf("收藏", "普通4", "普通3", "普通2"), report.highlights)
    }

    @Test
    fun moodThresholdsMatchApple() {
        fun text(vararg levels: EmotionLevel) =
            WeeklyMemory.report(emptyList(), levels.map { emotion("2026-08-12", it) }, emptyList(), base).mood?.text
        assertEquals("Mostly Positive", text(EmotionLevel.HAPPY))
        assertEquals("Mostly Low", text(EmotionLevel.UNHAPPY))
        assertEquals("Mostly Steady", text(EmotionLevel.NEUTRAL))
    }

    @Test
    fun globalSearchSortsAcrossKindsAndLimits() {
        val logs = (0 until 30).map {
            LogItem("l$it", "晨跑 $it", ColorTag.DAILY, Category.LOG, 0, "2026-08-12T08:%02d:00.000Z".format(it), "2026-08-12")
        }
        val results = GlobalSearch.search(logs, emptyList(), emptyList(), "晨跑")
        assertEquals(20, results.size)
        assertEquals("l29", results.first().id)
        assertTrue(GlobalSearch.search(logs, emptyList(), emptyList(), "  ").isEmpty())
    }

    @Test
    fun globalSearchMatchesEmotionAndTaskNotes() {
        val emotions = listOf(EmotionRecord("e", EmotionLevel.HAPPY, null, null, "散步之后", "2026-08-12", "2026-08-12T08:00:00.000Z"))
        val tasks = listOf(task("2026-08-12").copy(id = "t", notes = "带上雨伞"))
        val matches = GlobalSearch.search(emptyList(), emotions, tasks, "雨伞") + GlobalSearch.search(emptyList(), emotions, tasks, "散步")
        assertEquals(listOf(SearchMatchKind.TASK, SearchMatchKind.EMOTION), matches.map { it.kind })
    }

    @Test
    fun ideaReminderIntervals() {
        val today = LocalDate.parse("2026-08-13")
        assertTrue(ideaReminderDue(null, today, 7))
        assertFalse(ideaReminderDue(today.minusDays(2), today, 3))
        assertTrue(ideaReminderDue(today.minusDays(3), today, 3))
    }
}
