// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package com.flash.app.data

import com.flash.app.data.model.Category
import com.flash.app.data.model.ColorTag
import com.flash.app.data.model.LogItem
import org.junit.Assert.assertEquals
import org.junit.Test

class BackupDiffTest {
    private fun log(id: String, content: String) = LogItem(
        id, content, ColorTag.DAILY, Category.LOG, 0,
        "2026-08-29T00:00:00.000Z", "2026-08-29",
    )

    @Test fun `analyze separates added changed unchanged and local-only records`() {
        val local = listOf(log("same", "A"), log("changed", "old"), log("local", "L"))
        val incoming = listOf(log("same", "A"), log("changed", "new"), log("added", "N"))
        val difference = BackupDiff.analyze(local, emptyList(), incoming, emptyList())

        assertEquals(DifferenceSummary(1, 1, 1, 1), difference.logs)
        assertEquals(DifferenceSummary(0, 0, 0, 0), difference.emotions)
        assertEquals(DifferenceSummary(0, 0, 0, 0), difference.tasks)
    }
}
