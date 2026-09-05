// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package com.flash.app.data

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Test

class TextLimitsTest {

    @Test
    fun `fits boundary is inclusive at limit`() {
        val atLimit = "a".repeat(TextLimits.MAX_CONTENT_LENGTH)
        val overLimit = "a".repeat(TextLimits.MAX_CONTENT_LENGTH + 1)

        assertTrue(TextLimits.fits(atLimit))
        assertFalse(TextLimits.fits(overLimit))
    }

    @Test
    fun `requireFits accepts content at limit`() {
        TextLimits.requireFits("a".repeat(TextLimits.MAX_CONTENT_LENGTH))
    }

    @Test
    fun `requireFits rejects over-limit content with readable message`() {
        val overLimit = "a".repeat(TextLimits.MAX_CONTENT_LENGTH + 1)

        try {
            TextLimits.requireFits(overLimit)
            fail("expected ContentTooLongException")
        } catch (e: TextLimits.ContentTooLongException) {
            assertEquals(TextLimits.MAX_CONTENT_LENGTH + 1, e.actual)
            assertEquals(TextLimits.MAX_CONTENT_LENGTH, e.limit)
            assertTrue(e.message!!.contains("${TextLimits.MAX_CONTENT_LENGTH + 1}"))
            assertTrue(e.message!!.contains("${TextLimits.MAX_CONTENT_LENGTH}"))
        }
    }

    @Test
    fun `requireFits never truncates the value`() {
        val overLimit = "a".repeat(TextLimits.MAX_CONTENT_LENGTH + 1)

        runCatching { TextLimits.requireFits(overLimit) }

        assertEquals(TextLimits.MAX_CONTENT_LENGTH + 1, overLimit.length)
    }
}
