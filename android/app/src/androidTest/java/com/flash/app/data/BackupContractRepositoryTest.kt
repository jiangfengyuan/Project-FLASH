package com.flash.app.data

import androidx.room.Room
import androidx.test.core.app.ApplicationProvider
import androidx.test.platform.app.InstrumentationRegistry
import com.flash.app.data.db.FlashDatabase
import com.flash.app.data.reminder.TaskReminderScheduler
import java.time.Instant
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.json.JSONArray
import org.junit.Assert.assertNotNull
import org.junit.Test

class BackupContractRepositoryTest {
    private fun fixture(name: String): Backup.ImportResult = Backup.parseStrict(
        InstrumentationRegistry.getInstrumentation().context.assets.open("fixtures/$name.json")
            .bufferedReader().use { it.readText() }
    )

    @Test fun sharedCorpusOnAndroidJsonRuntime() {
        val assets = InstrumentationRegistry.getInstrumentation().context.assets
        val cases = JSONArray(assets.open("fixtures/cases.json").bufferedReader().use { it.readText() })
        for (i in 0 until cases.length()) {
            val item = cases.getJSONObject(i)
            val name = item.getString("file")
            val json = assets.open("fixtures/$name").bufferedReader().use { it.readText() }
            if (item.getBoolean("valid")) {
                val result = Backup.parseStrict(json)
                assertEquals(name, 0, result.skippedLogs + result.skippedEmotions + result.skippedTasks)
                Backup.parseStrict(Backup.exportJson(result.logs, result.emotions, result.tasks))
            } else assertThrows(name, Backup.BackupFormatException::class.java) { Backup.parseStrict(json) }
        }
    }

    @Test fun disabledNotificationsAreReportedBeforeScheduling() = runBlocking {
        val context = ApplicationProvider.getApplicationContext<android.content.Context>()
        val scheduler = TaskReminderScheduler(context, canNotify = { false })
        val task = fixture("merge-incoming").tasks.first().copy(
            reminderAt = Instant.now().plusSeconds(3600).toString(), completedAt = null,
        )
        val failure = runCatching { scheduler.rebuild(listOf(task)) }.exceptionOrNull()
        assertEquals("系统通知或任务提醒频道已关闭", failure?.message)
    }

    @Test fun sharedMergeOverwriteAndRollback() = runBlocking {
        val db = Room.inMemoryDatabaseBuilder(ApplicationProvider.getApplicationContext(), FlashDatabase::class.java)
            .allowMainThreadQueries().build()
        try {
            val repo = FlashRepository(db)
            val local = fixture("merge-local")
            val incoming = fixture("merge-incoming")
            suspend fun check(name: String) {
                val expected = fixture(name)
                val actual = repo.exportSnapshot()
                assertEquals(expected.logs.sortedBy { it.id }, actual.logs.sortedBy { it.id })
                assertEquals(expected.emotions.sortedBy { it.id }, actual.emotions.sortedBy { it.id })
                assertEquals(expected.tasks.sortedBy { it.id }, actual.tasks.sortedBy { it.id })
            }
            repo.replaceAll(local.logs, local.emotions, local.tasks)
            repo.mergeAll(incoming.logs, incoming.emotions, incoming.tasks)
            check("merge-expected")
            repo.replaceAll(incoming.logs, incoming.emotions, incoming.tasks)
            check("overwrite-expected")
            // Fail after logs/emotions have been changed; real SQLite must roll back all partitions.
            db.openHelper.writableDatabase.execSQL("CREATE TRIGGER fail_task BEFORE INSERT ON tasks BEGIN SELECT RAISE(ABORT, 'injected failure'); END")
            assertNotNull(runCatching { repo.replaceAll(local.logs, local.emotions, local.tasks) }.exceptionOrNull())
            check("overwrite-expected")
            assertNotNull(runCatching { repo.mergeAll(local.logs, local.emotions, local.tasks) }.exceptionOrNull())
            check("overwrite-expected")
            db.openHelper.writableDatabase.execSQL("DROP TRIGGER fail_task")
            repo.replaceAll(local.logs, local.emotions, local.tasks)
            check("merge-local")
        } finally { db.close() }
    }
}
