package com.flash.app.data

import androidx.room.Room
import androidx.test.core.app.ApplicationProvider
import androidx.lifecycle.ViewModelStore
import com.flash.app.data.db.FlashDatabase
import com.flash.app.ui.emotion.EmotionEvent
import com.flash.app.ui.emotion.EmotionViewModel
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.withContext
import kotlinx.coroutines.withTimeout
import org.junit.Assert.*
import org.junit.Test

class EmotionSaveFailureTest {
    @Test fun rejectedInsertRetainsInputUntilSuccessfulRetry() = runBlocking {
        val database = Room.inMemoryDatabaseBuilder(
            ApplicationProvider.getApplicationContext<android.content.Context>(), FlashDatabase::class.java).build()
        val owner = ViewModelStore()
        try {
            val repository = FlashRepository(database)
            database.openHelper.writableDatabase.execSQL(
                "CREATE TRIGGER reject_emotion BEFORE INSERT ON emotions BEGIN SELECT RAISE(ABORT, 'synthetic storage failure'); END")
            val vm = withContext(Dispatchers.Main) {
                EmotionViewModel(repository).also {
                    owner.put("emotion", it)
                    it.updateNote("retain this unsaved note")
                    it.selectIntensity(4)
                    it.save()
                }
            }
            assertTrue(withTimeout(5000) { vm.events.first() } is EmotionEvent.Failed)
            withContext(Dispatchers.Main) {
                assertEquals("retain this unsaved note", vm.note)
                assertEquals(4, vm.intensity)
            }
            assertTrue(repository.exportSnapshot().emotions.isEmpty())
            database.openHelper.writableDatabase.execSQL("DROP TRIGGER reject_emotion")
            withContext(Dispatchers.Main) { vm.save() }
            assertEquals(EmotionEvent.Saved, withTimeout(5000) { vm.events.first() })
            assertEquals("retain this unsaved note", repository.exportSnapshot().emotions.single().note)
            withContext(Dispatchers.Main) { assertEquals("", vm.note); assertNull(vm.intensity) }
        } finally {
            withContext(Dispatchers.Main) { owner.clear() }
            database.close()
        }
    }
}
