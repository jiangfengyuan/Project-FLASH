package com.flash.app.data

import org.json.JSONObject
import org.json.JSONArray
import org.junit.Assert.assertThrows
import org.junit.Assert.assertEquals
import org.junit.Test

/** The same checked-in fixtures are consumed by Node, Swift and ArkTS. */
class BackupContractTest {
    private fun fixture(name: String): String = requireNotNull(
        javaClass.classLoader!!.getResourceAsStream("fixtures/$name.json")
    ) { "Missing shared contract fixture: $name" }.bufferedReader().use { it.readText() }

    @Test fun sharedFixturesRoundTripWithoutLoss() {
        for (name in listOf("valid-minimal", "valid-full")) {
            val json = fixture(name)
            val expected = JSONObject(json).getJSONObject("data")
            val imported = Backup.parse(json)
            assertEquals(name, 0, imported.skippedLogs + imported.skippedEmotions + imported.skippedTasks)
            assertEquals(expected.getJSONArray("logs").length(), imported.logs.size)
            assertEquals(expected.getJSONArray("emotions").length(), imported.emotions.size)
            assertEquals(expected.getJSONArray("tasks").length(), imported.tasks.size)
            val exported = Backup.exportJson(imported.logs, imported.emotions, imported.tasks)
            val roundTrip = Backup.parse(exported)
            assertEquals(imported, roundTrip)
        }
    }

    @Test fun sharedStrictCorpus() {
        val cases = JSONArray(fixture("cases"))
        for (i in 0 until cases.length()) {
            val item = cases.getJSONObject(i)
            val name = item.getString("file").removeSuffix(".json")
            val json = fixture(name)
            if (item.getBoolean("valid")) {
                val result = Backup.parseStrict(json)
                assertEquals(name, 0, result.skippedLogs + result.skippedEmotions + result.skippedTasks)
            } else {
                assertThrows(name, Backup.BackupFormatException::class.java) { Backup.parseStrict(json) }
            }
        }
    }

    @Test fun standardRejectsLenientJsonAndRecoveryIsExplicit() {
        val json = fixture("valid-full")
        for (bad in listOf(json.replace("\"version\"", "'version'"), json + " false", json.replace("\"importance\": 2", "\"importance\": 02"))) {
            assertThrows(Backup.BackupFormatException::class.java) { Backup.parseStrict(bad) }
        }
        assertEquals(1, Backup.parseRecovery(fixture("invalid-importance-range")).skippedLogs)
        assertThrows(Backup.BackupFormatException::class.java) { Backup.parseRecovery(fixture("invalid-unknown-section")) }
        assertEquals(1, Backup.parseStrict(json.replace("\"logs\": 1", "\"logs\": 1.0")).logs.size)
    }

    @Test fun exportRejectsInvalidDataAndNormalizesAllTimes() {
        val input = Backup.parseStrict(fixture("valid-full"))
        assertThrows(Backup.BackupFormatException::class.java) {
            Backup.exportJson(listOf(input.logs.single().copy(importance = 9)), input.emotions, input.tasks)
        }
        val output = JSONObject(Backup.exportJson(listOf(input.logs.single().copy(createdAt = "2026-09-05T08:00:00.123456789+08:00")), input.emotions, input.tasks))
        assertEquals("2026-09-05T00:00:00.123Z", output.getJSONObject("data").getJSONArray("logs").getJSONObject(0).getString("createdAt"))
    }

    @Test fun sharedLegacyFixtureMigratesWithoutTasks() {
        val imported = Backup.parse(fixture("legacy-v1"))
        assertEquals(Backup.LEGACY_BACKUP_VERSION, imported.sourceVersion)
        assertEquals(1, imported.logs.size)
        assertEquals(0, imported.tasks.size)
    }
}
