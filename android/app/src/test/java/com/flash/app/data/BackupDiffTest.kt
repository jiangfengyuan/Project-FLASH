// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package com.flash.app.data

import com.flash.app.data.model.Category
import com.flash.app.data.model.ColorTag
import com.flash.app.data.model.EmotionLevel
import com.flash.app.data.model.EmotionRecord
import com.flash.app.data.model.LogItem
import com.flash.app.data.model.TaskDueKind
import com.flash.app.data.model.TaskItem
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
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

    @Test fun `sameData detects any local change for overwrite re-verification`() {
        val base = FlashSnapshot(listOf(log("a", "A")), emptyList(), emptyList())
        assertTrue(BackupDiff.sameData(base, base.copy()))
        assertTrue(BackupDiff.sameData(base, FlashSnapshot(listOf(log("a", "A")), emptyList(), emptyList())))
        // 新增 / 修改 / 删除任一分区记录都视为本地有变化
        assertFalse(BackupDiff.sameData(base, base.copy(logs = base.logs + log("b", "B"))))
        assertFalse(BackupDiff.sameData(base, base.copy(logs = listOf(log("a", "A2")))))
        assertFalse(BackupDiff.sameData(base, base.copy(logs = emptyList())))
        assertFalse(
            BackupDiff.sameData(
                base,
                base.copy(
                    emotions = listOf(
                        EmotionRecord(
                            id = "e",
                            level = EmotionLevel.fromValue(1),
                            subEmotion = null,
                            status = null,
                            note = null,
                            recordDate = "2026-08-29",
                            createdAt = "2026-08-29T00:00:00.000Z",
                        )
                    )
                ),
            )
        )
        assertFalse(
            BackupDiff.sameData(
                base,
                base.copy(tasks = listOf(task("t", "T"))),
            )
        )
    }

    private fun task(id: String, title: String) = TaskItem(
        id = id,
        title = title,
        notes = null,
        colorTag = ColorTag.MEMO,
        importance = 0,
        dueKind = TaskDueKind.ALL_DAY,
        dueDate = "2026-08-29",
        dueAt = null,
        timeZone = null,
        reminderAt = null,
        completedAt = null,
        createdAt = "2026-08-29T00:00:00.000Z",
        updatedAt = "2026-08-29T00:00:00.000Z",
    )
}
