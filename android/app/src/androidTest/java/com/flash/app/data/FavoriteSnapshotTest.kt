package com.flash.app.data

import androidx.room.Room
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.flash.app.data.db.FlashDatabase
import com.flash.app.data.model.Category
import com.flash.app.data.model.ColorTag
import com.flash.app.data.model.EmotionLevel
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith

/** A late favorite action carries the UI snapshot from before an import. */
@RunWith(AndroidJUnit4::class)
class FavoriteSnapshotTest {
    @Test
    fun staleFavoritePreservesImportedFieldsAndDoesNotResurrectDeletedRows() = runBlocking {
        val context = ApplicationProvider.getApplicationContext<android.content.Context>()
        val database = Room.inMemoryDatabaseBuilder(context, FlashDatabase::class.java).build()
        try {
            val repository = FlashRepository(database)
            repository.addLog("original body", ColorTag.DAILY, Category.IDEA)
            repository.addEmotion(EmotionLevel.HAPPY, null, note = "original note")
            val before = repository.exportSnapshot()
            val staleLog = before.logs.single()
            val staleEmotion = before.emotions.single()
            val importedLog = staleLog.copy(content = "imported body", colorTag = ColorTag.MEMO,
                importance = 4, recordDate = "2026-09-01")
            val importedEmotion = staleEmotion.copy(note = "imported note", status = "changed",
                intensity = 5, recordDate = "2026-09-01")
            repository.replaceAll(listOf(importedLog), listOf(importedEmotion), emptyList())
            repository.markIdeaViewed(importedLog.id)

            repository.setLogFavorite(staleLog, true)
            repository.setEmotionFavorite(staleEmotion, true)
            val favorited = repository.exportSnapshot()
            assertEquals(importedLog.copy(isFavorite = true), favorited.logs.single())
            assertEquals(importedEmotion.copy(isFavorite = true), favorited.emotions.single())
            assertTrue(repository.isIdeaViewed(importedLog.id))

            repository.setLogFavorite(staleLog, false)
            repository.setEmotionFavorite(staleEmotion, false)
            val unfavorited = repository.exportSnapshot()
            assertEquals(importedLog.copy(isFavorite = false), unfavorited.logs.single())
            assertEquals(importedEmotion.copy(isFavorite = false), unfavorited.emotions.single())

            repository.deleteLog(importedLog.id)
            repository.deleteEmotion(importedEmotion.id)
            repository.setLogFavorite(staleLog, true)
            repository.setEmotionFavorite(staleEmotion, true)
            assertTrue(repository.exportSnapshot().logs.isEmpty())
            assertTrue(repository.exportSnapshot().emotions.isEmpty())
        } finally {
            database.close()
        }
    }
}
