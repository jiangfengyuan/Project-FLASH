// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package com.flash.app.ui.home

import com.flash.app.data.model.Category
import com.flash.app.data.model.ColorTag
import com.flash.app.data.model.LogItem
import org.junit.Assert.assertEquals
import org.junit.Test

class HomeViewModelTest {

    @Test
    fun `home reminder points to oldest unviewed idea`() {
        val newest = idea("newest", "2026-08-31T09:00:00.000Z")
        val oldest = idea("oldest", "2026-08-29T09:00:00.000Z")

        val result = buildHomeUiState(
            logs = listOf(newest, oldest),
            emotions = emptyList(),
            unviewedIdeas = listOf(newest, oldest),
            today = "2026-08-31",
        )

        assertEquals(2, result.unviewedIdeaCount)
        assertEquals("oldest", result.oldestUnviewedIdeaId)
        assertEquals(1, result.todayIdeaCount)
    }

    private fun idea(id: String, createdAt: String) = LogItem(
        id = id,
        content = id,
        colorTag = ColorTag.IDEA,
        category = Category.IDEA,
        importance = 0,
        createdAt = createdAt,
        recordDate = createdAt.take(10),
    )
}
