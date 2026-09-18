// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package com.flash.app.ui.explore

import com.flash.app.data.model.Category
import com.flash.app.data.model.ColorTag
import com.flash.app.data.model.LogItem
import org.junit.Assert.assertEquals
import org.junit.Test

class ExploreViewModelTest {

    @Test
    fun `category and query filters compose without losing order`() {
        val log = item("1", "今天散步", Category.LOG, ColorTag.DAILY)
        val idea = item("2", "设计新的首页", Category.IDEA, ColorTag.INSPIRATION)
        val otherIdea = item("3", "周末做饭", Category.IDEA, ColorTag.DAILY)

        val result = filterExploreLogs(
            listOf(log, idea, otherIdea),
            ExploreFilter.IDEA,
            "设计",
        )

        assertEquals(listOf(idea), result)
    }

    @Test
    fun `query also matches localized tag name`() {
        val inspiration = item("1", "未命名内容", Category.IDEA, ColorTag.INSPIRATION)
        val daily = item("2", "另一条内容", Category.IDEA, ColorTag.DAILY)

        assertEquals(
            listOf(inspiration),
            filterExploreLogs(listOf(inspiration, daily), ExploreFilter.ALL, "灵感"),
        )
    }

    @Test
    fun `inbox excludes ideas with daily tags and logs with other tags`() {
        val daily = item("1", "日常日志", Category.LOG, ColorTag.DAILY)
        val idea = item("2", "日常灵感", Category.IDEA, ColorTag.DAILY)
        val tagged = item("3", "已分类", Category.LOG, ColorTag.INSPIRATION)
        val logs = listOf(daily, idea, tagged)
        assertEquals(listOf(daily), filterExploreLogs(logs, ExploreFilter.UNSORTED, ""))
        assertEquals(emptyList<LogItem>(), filterExploreLogs(logs, ExploreFilter.UNSORTED, "灵感"))
        assertEquals(emptyList<LogItem>(), filterExploreLogs(
            logs, ExploreFilter.UNSORTED, "", ExplorePanel(tags = setOf(ColorTag.INSPIRATION)),
        ))
    }

    @Test
    fun `summary counts current calendar week excluding future records`() {
        val base = item("1", "日志", Category.LOG, ColorTag.DAILY)
        val logs = listOf(
            base.copy(recordDate = "2026-09-13"),
            base.copy(id = "2", recordDate = "2026-09-14"),
            base.copy(id = "3", recordDate = "2026-09-18", category = Category.IDEA),
            base.copy(id = "4", recordDate = "2026-09-19"),
        )
        assertEquals("本周 2 条记录 · 3 条待整理",
            buildExploreSummary(logs, java.time.LocalDate.of(2026, 9, 18)))
        assertEquals("本周 1 条记录 · 3 条待整理",
            buildExploreSummary(logs, java.time.LocalDate.of(2026, 9, 14)))
    }

    private fun item(id: String, content: String, category: Category, tag: ColorTag) = LogItem(
        id = id,
        content = content,
        colorTag = tag,
        category = category,
        importance = 0,
        createdAt = "2026-08-31T08:00:00.000Z",
        recordDate = "2026-08-31",
    )
}
