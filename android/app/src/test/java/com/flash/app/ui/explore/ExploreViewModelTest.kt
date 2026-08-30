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
