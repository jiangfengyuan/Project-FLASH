// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package com.flash.app.data

import org.junit.Assert.assertTrue
import org.junit.Test

class LocalBackupTransferTest {
    @Test
    fun `generated PIN is always four digits`() {
        repeat(200) {
            assertTrue(LocalBackupTransfer.generatePin().matches(Regex("\\d{4}")))
        }
    }
}
