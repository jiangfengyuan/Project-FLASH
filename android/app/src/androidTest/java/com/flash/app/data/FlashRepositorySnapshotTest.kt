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
