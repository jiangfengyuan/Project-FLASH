package com.flash.app.data

import androidx.lifecycle.ViewModelStore
import androidx.room.Room
import androidx.test.core.app.ApplicationProvider
import com.flash.app.FlashApplication
import com.flash.app.data.db.FlashDatabase
import com.flash.app.data.model.ColorTag
import com.flash.app.data.model.TaskDueKind
import com.flash.app.ui.calendar.CalendarEvent
import com.flash.app.ui.calendar.CalendarViewModel
import com.flash.app.ui.calendar.TaskDraft
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.withContext
import kotlinx.coroutines.withTimeout
import org.junit.Assert.*
import org.junit.Test

class TaskSaveFailureTest {
    @Test fun persistenceFailurePropagatesButReminderFailureDoesNotInviteDuplicateSave() = runBlocking {
        val app = ApplicationProvider.getApplicationContext<FlashApplication>()
        val database = Room.inMemoryDatabaseBuilder(app, FlashDatabase::class.java).build()
        val owner = ViewModelStore()
        try {
            val repository = FlashRepository(database)
            var reminderCalls = 0
            val vm = withContext(Dispatchers.Main) {
                CalendarViewModel(repository, app.taskReminders) {
                    reminderCalls++
                    error("synthetic reminder failure")
                }.also { owner.put("calendar", it) }
            }
            val draft = TaskDraft("unsaved title", "unsaved notes", ColorTag.MEMO, 1,
                TaskDueKind.ALL_DAY, "2026-11-14", null, null, null)
            database.openHelper.writableDatabase.execSQL(
                "CREATE TRIGGER reject_task BEFORE INSERT ON tasks BEGIN SELECT RAISE(ABORT, 'synthetic storage failure'); END")
            assertTrue(runCatching { vm.saveTask(null, draft) }.isFailure)
            assertEquals(0, reminderCalls)
            assertTrue(repository.exportSnapshot().tasks.isEmpty())
            assertEquals("unsaved notes", draft.notes)
            database.openHelper.writableDatabase.execSQL("DROP TRIGGER reject_task")
            // A successful return closes the editor even when reminder restoration fails.
            vm.saveTask(null, draft)
            assertEquals(1, reminderCalls)
            assertEquals("unsaved title", repository.exportSnapshot().tasks.single().title)
            assertTrue(withTimeout(5000) { vm.events.first() } is CalendarEvent.Failed)
        } finally {
            withContext(Dispatchers.Main) { owner.clear() }
            database.close()
        }
    }
}
