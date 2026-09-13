// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package com.flash.app.domain

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class IdeaReminderTest {

    @Test
    fun `reminder starts at three unviewed ideas`() {
        assertFalse(shouldShowIdeaReminder(0))
        assertFalse(shouldShowIdeaReminder(2))
        assertTrue(shouldShowIdeaReminder(3))
        assertTrue(shouldShowIdeaReminder(20))
    }
}
