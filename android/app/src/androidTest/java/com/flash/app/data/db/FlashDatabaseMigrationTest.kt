// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package com.flash.app.data.db

import android.content.Context
import android.database.sqlite.SQLiteDatabase
import androidx.room.Room
import androidx.room.testing.MigrationTestHelper
import androidx.sqlite.db.SimpleSQLiteQuery
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import org.junit.Assert.assertEquals
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class FlashDatabaseMigrationTest {

    private val context: Context
        get() = InstrumentationRegistry.getInstrumentation().targetContext

    @get:Rule
    val helper = MigrationTestHelper(
        InstrumentationRegistry.getInstrumentation(),
        FlashDatabase::class.java,
    )

    @Test
    fun migration1To4PreservesContentAndBuildsEveryLaterTable() {
        createLegacyDatabase(version = 1, includeIdeaViewState = false)

        val database = openMigratedDatabase()
        try {
            val sqlite = database.openHelper.writableDatabase
            assertEquals(1, sqlite.query(SimpleSQLiteQuery("SELECT COUNT(*) FROM logs")).singleInt())
            assertEquals(1, sqlite.query(SimpleSQLiteQuery("SELECT COUNT(*) FROM emotions")).singleInt())
            assertEquals(1, sqlite.query(SimpleSQLiteQuery("SELECT COUNT(*) FROM idea_view_state")).singleInt())
            assertEquals(0, sqlite.query(SimpleSQLiteQuery("SELECT COUNT(*) FROM tasks")).singleInt())
            assertEquals(4, sqlite.version)
        } finally {
            database.close()
        }
    }

    @Test
    fun migration2To4PreservesIdeaStateAndBuildsTasks() {
        createLegacyDatabase(version = 2, includeIdeaViewState = true)

        val database = openMigratedDatabase()
        try {
            val sqlite = database.openHelper.writableDatabase
            sqlite.query(
                SimpleSQLiteQuery("SELECT viewedAt FROM idea_view_state WHERE logId = 'log-1'"),
            ).use { cursor ->
                cursor.moveToFirst()
                assertEquals("2026-09-04T01:00:00.000Z", cursor.getString(0))
            }
            assertEquals(0, sqlite.query(SimpleSQLiteQuery("SELECT COUNT(*) FROM tasks")).singleInt())
            assertEquals(4, sqlite.version)
        } finally {
            database.close()
        }
    }

    @Test
    fun migration3To4PreservesDataAndCreatesQueryIndexes() {
        helper.createDatabase(TEST_DB, 3).apply {
            execSQL(
                """
                INSERT INTO logs
                    (id, content, colorTag, category, importance, createdAt, recordDate)
                VALUES
                    ('log-1', 'hello', 'daily', 'log', 0,
                     '2026-09-04T00:00:00.000Z', '2026-09-04')
                """.trimIndent()
            )
            execSQL(
                """
                INSERT INTO emotions
                    (id, level, subEmotion, status, note, recordDate, createdAt)
                VALUES
                    ('emotion-1', 1, NULL, NULL, NULL,
                     '2026-09-04', '2026-09-04T00:00:00.000Z')
                """.trimIndent()
            )
            close()
        }

        helper.runMigrationsAndValidate(
            TEST_DB,
            4,
            true,
            FlashDatabase.MIGRATION_3_4,
        ).use { database ->
            database.query("SELECT COUNT(*) FROM logs").use { cursor ->
                cursor.moveToFirst()
                assertEquals(1, cursor.getInt(0))
            }
            database.query("SELECT COUNT(*) FROM emotions").use { cursor ->
                cursor.moveToFirst()
                assertEquals(1, cursor.getInt(0))
            }
            assertEquals(
                setOf(
                    "index_logs_createdAt",
                    "index_logs_recordDate",
                    "index_logs_category_createdAt",
                ),
                database.indexNames("logs"),
            )
            assertEquals(
                setOf("index_emotions_createdAt", "index_emotions_recordDate"),
                database.indexNames("emotions"),
            )
            assertEquals(
                setOf("index_tasks_updatedAt", "index_tasks_dueDate", "index_tasks_dueAt"),
                database.indexNames("tasks"),
            )
        }
    }

    private fun androidx.sqlite.db.SupportSQLiteDatabase.indexNames(table: String): Set<String> {
        val names = mutableSetOf<String>()
        query("PRAGMA index_list(`$table`)").use { cursor ->
            val nameColumn = cursor.getColumnIndexOrThrow("name")
            while (cursor.moveToNext()) {
                val name = cursor.getString(nameColumn)
                if (!name.startsWith("sqlite_autoindex_")) names += name
            }
        }
        return names
    }

    private fun createLegacyDatabase(version: Int, includeIdeaViewState: Boolean) {
        context.deleteDatabase(TEST_DB)
        SQLiteDatabase.openOrCreateDatabase(context.getDatabasePath(TEST_DB), null).use { database ->
            database.execSQL(
                """
                CREATE TABLE logs (
                    id TEXT NOT NULL PRIMARY KEY,
                    content TEXT NOT NULL,
                    colorTag TEXT NOT NULL,
                    category TEXT NOT NULL,
                    importance INTEGER NOT NULL,
                    createdAt TEXT NOT NULL,
                    recordDate TEXT NOT NULL
                )
                """.trimIndent(),
            )
            database.execSQL(
                """
                CREATE TABLE emotions (
                    id TEXT NOT NULL PRIMARY KEY,
                    level INTEGER NOT NULL,
                    subEmotion TEXT,
                    status TEXT,
                    note TEXT,
                    recordDate TEXT NOT NULL,
                    createdAt TEXT NOT NULL
                )
                """.trimIndent(),
            )
            database.execSQL(
                """
                INSERT INTO logs
                    (id, content, colorTag, category, importance, createdAt, recordDate)
                VALUES
                    ('log-1', 'legacy idea', 'idea', 'idea', 1,
                     '2026-09-04T00:00:00.000Z', '2026-09-04')
                """.trimIndent(),
            )
            database.execSQL(
                """
                INSERT INTO emotions
                    (id, level, subEmotion, status, note, recordDate, createdAt)
                VALUES
                    ('emotion-1', 2, NULL, NULL, 'legacy emotion',
                     '2026-09-04', '2026-09-04T00:00:00.000Z')
                """.trimIndent(),
            )
            if (includeIdeaViewState) {
                database.execSQL(
                    """
                    CREATE TABLE idea_view_state (
                        logId TEXT NOT NULL PRIMARY KEY,
                        viewedAt TEXT NOT NULL,
                        FOREIGN KEY(logId) REFERENCES logs(id)
                            ON UPDATE NO ACTION ON DELETE CASCADE
                    )
                    """.trimIndent(),
                )
                database.execSQL(
                    """
                    INSERT INTO idea_view_state (logId, viewedAt)
                    VALUES ('log-1', '2026-09-04T01:00:00.000Z')
                    """.trimIndent(),
                )
            }
            database.version = version
        }
    }

    private fun openMigratedDatabase(): FlashDatabase = Room.databaseBuilder(
        context,
        FlashDatabase::class.java,
        TEST_DB,
    ).addMigrations(
        FlashDatabase.MIGRATION_1_2,
        FlashDatabase.MIGRATION_2_3,
        FlashDatabase.MIGRATION_3_4,
    ).build().also { it.openHelper.writableDatabase }

    private fun android.database.Cursor.singleInt(): Int = use { cursor ->
        cursor.moveToFirst()
        cursor.getInt(0)
    }

    private companion object {
        const val TEST_DB = "flash-migration-test"
    }
}
