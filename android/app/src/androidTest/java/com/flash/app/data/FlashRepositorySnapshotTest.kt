// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package com.flash.app.data

import androidx.room.Room
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.flash.app.data.db.FlashDatabase
import com.flash.app.data.model.Category
import org.junit.Assert.assertTrue
import com.flash.app.data.model.ColorTag
import com.flash.app.data.model.EmotionLevel
import com.flash.app.data.model.TaskDueKind
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class FlashRepositorySnapshotTest {

    @Test
    fun editedFieldsAndReadStateCommitTogetherAndRejectInvalidDates() = runBlocking {
        val context = ApplicationProvider.getApplicationContext<android.content.Context>()
        val database = Room.inMemoryDatabaseBuilder(context, FlashDatabase::class.java)
            .allowMainThreadQueries().build()
        try {
            val repository = FlashRepository(database)
            repository.addLog("原文", ColorTag.DAILY)
            val original = repository.exportSnapshot().logs.single()
            val edited = original.copy(content = "新正文", category = Category.IDEA,
                colorTag = ColorTag.MEMO, recordDate = "2024-02-29")
            repository.updateLog(edited, markViewed = true)
            assertEquals(edited, repository.exportSnapshot().logs.single())
            assertTrue(repository.isIdeaViewed(edited.id))
            for (date in listOf("2026-02-30", "0000-01-01", "2026-9-01")) {
                assertTrue(runCatching { repository.updateLog(edited.copy(recordDate = date)) }.isFailure)
                assertEquals(edited, repository.exportSnapshot().logs.single())
            }
            // A failed second write must also roll back the edited record.
            database.openHelper.writableDatabase.execSQL(
                "CREATE TRIGGER reject_view BEFORE INSERT ON idea_view_state BEGIN SELECT RAISE(ABORT, 'disk failure'); END"
            )
            assertTrue(runCatching {
                repository.updateLog(edited.copy(content = "不可部分保存", recordDate = "2026-09-19"), markViewed = true)
            }.isFailure)
            assertEquals(edited, repository.exportSnapshot().logs.single())
        } finally { database.close() }
    }

    @Test
    fun snapshotContainsEveryPortableSection() = runBlocking {
        val context = ApplicationProvider.getApplicationContext<android.content.Context>()
        val database = Room.inMemoryDatabaseBuilder(context, FlashDatabase::class.java)
            .allowMainThreadQueries()
            .build()
        try {
            val repository = FlashRepository(database)
            repository.addLog("hello", ColorTag.DAILY)
            repository.addEmotion(EmotionLevel.HAPPY, null)
            repository.addTask(
                repository.newTask(
                    title = "task",
                    notes = null,
                    colorTag = ColorTag.MEMO,
                    importance = 0,
                    dueKind = TaskDueKind.ALL_DAY,
                    dueDate = "2026-09-04",
                    dueAt = null,
                    timeZone = null,
                    reminderAt = null,
                )
            )

            val snapshot = repository.exportSnapshot()

            assertEquals(1, snapshot.logs.size)
            assertEquals(1, snapshot.emotions.size)
            assertEquals(1, snapshot.tasks.size)
        } finally {
            database.close()
        }
    }
}
