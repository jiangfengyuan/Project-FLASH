package com.flash.app.data.db

import android.database.sqlite.SQLiteDatabase
import androidx.room.Room
import androidx.room.migration.Migration
import androidx.room.testing.MigrationTestHelper
import androidx.sqlite.db.SupportSQLiteDatabase
import androidx.test.platform.app.InstrumentationRegistry
import com.flash.app.data.Backup
import com.flash.app.data.BackupDiff
import com.flash.app.data.FlashRepository
import kotlinx.coroutines.runBlocking
import org.junit.Assert.*
import org.junit.Rule
import org.junit.Test

class Schema2MigrationTest {
    private val context get() = InstrumentationRegistry.getInstrumentation().targetContext
    @get:Rule val helper = MigrationTestHelper(InstrumentationRegistry.getInstrumentation(), FlashDatabase::class.java)

    private fun populatedV4() {
        helper.createDatabase(DB, 4).use { db ->
            db.execSQL("INSERT INTO logs (id,content,colorTag,category,importance,createdAt,recordDate) " +
                "VALUES ('$LOG','fictional legacy idea','daily','idea',2,'2026-09-04T00:00:00.000Z','2026-09-04')")
            db.execSQL("INSERT INTO idea_view_state (logId,viewedAt) VALUES ('$LOG','$VIEWED')")
            db.execSQL("INSERT INTO emotions (id,level,recordDate,createdAt) " +
                "VALUES ('$EMOTION',1,'2026-09-04','2026-09-04T01:00:00.000Z')")
            db.execSQL("INSERT INTO tasks (id,title,colorTag,importance,dueKind,dueDate,createdAt,updatedAt) " +
                "VALUES ('$TASK','fictional legacy task','daily',1,'allDay','2026-09-05'," +
                "'2026-09-04T02:00:00.000Z','2026-09-04T02:00:00.000Z')")
        }
    }

    private fun open() = Room.databaseBuilder(context, FlashDatabase::class.java, DB)
        .addMigrations(FlashDatabase.MIGRATION_4_5).build()

    @Test fun additiveMigrationPreservesReadStateAndAllFieldsAcrossCloseAndReopen() = runBlocking {
        populatedV4()
        var database = open()
        try {
            val repo = FlashRepository(database)
            val before = repo.exportSnapshot()
            assertEquals(5, database.openHelper.writableDatabase.version)
            assertEquals(1, before.logs.size); assertEquals(1, before.emotions.size); assertEquals(1, before.tasks.size)
            assertNull(before.logs.single().isFavorite)
            assertNull(before.emotions.single().isFavorite); assertNull(before.emotions.single().intensity)
            assertNull(before.tasks.single().isFavorite); assertNull(before.tasks.single().sourceLogId)
            assertTrue(repo.isIdeaViewed(LOG))
            repo.updateLog(before.logs.single().copy(isFavorite = true))
            database.emotionDao().upsert(before.emotions.single().copy(intensity = 4, isFavorite = false).toEntity())
            repo.updateTask(before.tasks.single().copy(sourceLogId = DANGLING_SOURCE, isFavorite = true))
            val expected = repo.exportSnapshot()
            database.close()
            database = open()
            val reopened = FlashRepository(database)
            val actual = reopened.exportSnapshot()
            assertTrue(BackupDiff.sameData(expected, actual))
            assertTrue(reopened.isIdeaViewed(LOG))
            database.openHelper.writableDatabase.query("SELECT viewedAt FROM idea_view_state WHERE logId='$LOG'").use {
                assertTrue(it.moveToFirst()); assertEquals(VIEWED, it.getString(0))
            }
            val exported = Backup.exportJson(actual.logs, actual.emotions, actual.tasks)
            val imported = Backup.parseStrict(exported)
            assertEquals(actual.logs, imported.logs)
            assertEquals(actual.emotions, imported.emotions)
            assertEquals(actual.tasks, imported.tasks)
            assertEquals(DANGLING_SOURCE, imported.tasks.single().sourceLogId)
        } finally { database.close(); context.deleteDatabase(DB) }
    }

    @Test fun failedMigrationRollsBackColumnsVersionAndExistingRecords() {
        populatedV4()
        var reachedFault = false
        val failure = object : Migration(4, 5) {
            override fun migrate(db: SupportSQLiteDatabase) {
                FlashDatabase.MIGRATION_4_5.migrate(db)
                reachedFault = true
                error("synthetic migration failure after additive DDL")
            }
        }
        val database = Room.databaseBuilder(context, FlashDatabase::class.java, DB).addMigrations(failure).build()
        try {
            assertThrows(Exception::class.java) { database.openHelper.writableDatabase }
            assertTrue(reachedFault)
        } finally { database.close() }
        try {
            SQLiteDatabase.openDatabase(context.getDatabasePath(DB).path, null, SQLiteDatabase.OPEN_READONLY).use { db ->
                assertEquals(4, db.version)
                for (table in listOf("logs", "emotions", "tasks")) {
                    db.rawQuery("SELECT COUNT(*) FROM $table", null).use {
                        assertTrue(it.moveToFirst()); assertEquals(1, it.getInt(0))
                    }
                    db.rawQuery("PRAGMA table_info($table)", null).use {
                        val names = mutableSetOf<String>()
                        while (it.moveToNext()) names.add(it.getString(it.getColumnIndexOrThrow("name")))
                        assertFalse(names.contains("isFavorite"))
                        assertFalse(names.contains("intensity")); assertFalse(names.contains("sourceLogId"))
                    }
                }
                db.rawQuery("SELECT viewedAt FROM idea_view_state WHERE logId=?", arrayOf(LOG)).use {
                    assertTrue(it.moveToFirst()); assertEquals(VIEWED, it.getString(0))
                }
            }
        } finally { context.deleteDatabase(DB) }
    }

    companion object {
        private const val DB = "schema2-synthetic-migration"
        private const val LOG = "11111111-1111-4111-8111-111111111111"
        private const val EMOTION = "22222222-2222-4222-8222-222222222222"
        private const val TASK = "33333333-3333-4333-8333-333333333333"
        private const val DANGLING_SOURCE = "99999999-9999-4999-8999-999999999999"
        private const val VIEWED = "2026-09-04T01:00:00.000Z"
    }
}
