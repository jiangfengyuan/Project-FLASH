package com.flash.app.data

import androidx.room.Room
import androidx.test.core.app.ApplicationProvider
import com.flash.app.data.db.FlashDatabase
import com.flash.app.data.model.ColorTag
import com.flash.app.data.model.TaskDueKind
import kotlinx.coroutines.runBlocking
import org.junit.Assert.*
import org.junit.Test

class TaskEditorConcurrencyTest {
    @Test fun staleEditorPreservesCompletionAndRejectsDeletedTask() = runBlocking {
        val database = Room.inMemoryDatabaseBuilder(
            ApplicationProvider.getApplicationContext<android.content.Context>(), FlashDatabase::class.java).build()
        try {
            val repository = FlashRepository(database)
            val opened = repository.newTask("original", null, ColorTag.MEMO, 0,
                TaskDueKind.ALL_DAY, "2026-11-14", null, null, null)
            repository.addTask(opened)
            val completed = repository.setTaskCompleted(opened, true)
            repository.updateTaskFromEditor(opened.copy(title = "editor changes"))
            val saved = repository.exportSnapshot().tasks.single()
            assertEquals(completed.completedAt, saved.completedAt)
            assertEquals("editor changes", saved.title)
            // Notification state mutations must preserve the most recent edited fields too.
            repository.snoozeTask(opened.id, "2026-11-15T10:00:00Z")
            repository.setTaskCompleted(opened, true)
            assertEquals("editor changes", repository.exportSnapshot().tasks.single().title)
            repository.deleteTask(opened.id)
            assertTrue(runCatching { repository.updateTaskFromEditor(opened) }.isFailure)
            assertTrue(repository.exportSnapshot().tasks.isEmpty())
        } finally { database.close() }
    }
}
