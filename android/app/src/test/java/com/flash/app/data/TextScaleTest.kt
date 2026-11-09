// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package com.flash.app.data

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class TextScaleTest {

    @Test
    fun `storage keys round trip`() {
        TextScale.entries.forEach { scale ->
            assertEquals(scale, TextScale.fromStorage(scale.storageKey))
        }
    }

    @Test
    fun `missing or unknown key falls back to system`() {
        assertEquals(TextScale.SYSTEM, TextScale.fromStorage(null))
        assertEquals(TextScale.SYSTEM, TextScale.fromStorage("huge"))
    }

    @Test
    fun `system leaves font scale untouched and larger options only enlarge`() {
        assertEquals(1f, TextScale.SYSTEM.factor, 0f)
        assertTrue(TextScale.LARGE.factor > TextScale.SYSTEM.factor)
        assertTrue(TextScale.EXTRA_LARGE.factor > TextScale.LARGE.factor)
    }
}
