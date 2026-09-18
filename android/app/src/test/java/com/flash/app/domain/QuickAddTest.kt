// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package com.flash.app.domain

import com.flash.app.data.model.Category
import com.flash.app.data.model.ColorTag
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class QuickAddTest {

    @Test
    fun `blank content is rejected`() {
        assertNull(quickAddDraft("   ", Category.LOG))
        assertNull(quickAddDraft("", Category.IDEA))
    }

    @Test
    fun `log draft uses daily tag and zero importance even with bangs`() {
        val draft = quickAddDraft("  今天散步 !! ", Category.LOG)
        assertEquals(
            QuickAddDraft("今天散步 !!", ColorTag.DAILY, Category.LOG, 0),
            draft,
        )
    }

    @Test
    fun `idea draft uses idea tag and infers importance from content`() {
        assertEquals(
            QuickAddDraft("新点子", ColorTag.IDEA, Category.IDEA, 0),
            quickAddDraft("新点子", Category.IDEA),
        )
        assertEquals(
            QuickAddDraft("新点子 !!!", ColorTag.IDEA, Category.IDEA, 3),
            quickAddDraft("新点子 !!!", Category.IDEA),
        )
    }
}
