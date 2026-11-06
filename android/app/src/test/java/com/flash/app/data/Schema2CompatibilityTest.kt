package com.flash.app.data

import org.json.JSONObject
import org.junit.Assert.*
import org.junit.Test

class Schema2CompatibilityTest {
    private fun document() = JSONObject(requireNotNull(javaClass.classLoader!!
        .getResourceAsStream("fixtures/valid-schema2.json")).bufferedReader().use { it.readText() })

    @Test fun schema2FieldsSurviveProductionParseAndExport() {
        val original = document()
        val imported = Backup.parseStrict(original.toString())
        val encoded = Backup.exportJson(imported.logs, imported.emotions, imported.tasks)
        assertEquals(imported, Backup.parseStrict(encoded))
        val data = JSONObject(encoded).getJSONObject("data")
        assertTrue(data.getJSONArray("logs").getJSONObject(0).getBoolean("isFavorite"))
        val emotion = data.getJSONArray("emotions").getJSONObject(0)
        assertEquals(4, emotion.getInt("intensity"))
        assertFalse(emotion.getBoolean("isFavorite"))
        val task = data.getJSONArray("tasks").getJSONObject(0)
        assertEquals("55555555-5555-4555-8555-555555555555", task.getString("sourceLogId"))
        assertTrue(task.getBoolean("isFavorite"))
    }

    @Test fun optionalFieldsKeepStrictTypesAndSectionVersionGates() {
        for ((field, value) in listOf("isFavorite" to 1, "intensity" to true,
            "intensity" to 4.5, "intensity" to 0, "intensity" to 6)) {
            val input = document()
            input.getJSONObject("data").getJSONArray("emotions").getJSONObject(0).put(field, value)
            assertThrows(Backup.BackupFormatException::class.java) { Backup.parseStrict(input.toString()) }
        }
        val schema1 = document()
        schema1.getJSONObject("schemas").put("logs", 1)
        assertThrows(Backup.BackupFormatException::class.java) { Backup.parseStrict(schema1.toString()) }
        assertThrows(Backup.BackupFormatException::class.java) { Backup.parseRecovery(schema1.toString()) }
        val future = document()
        future.getJSONObject("schemas").put("tasks", 3)
        assertThrows(Backup.BackupFormatException::class.java) { Backup.parseStrict(future.toString()) }
        assertThrows(Backup.BackupFormatException::class.java) { Backup.parseRecovery(future.toString()) }
        val badLink = document()
        badLink.getJSONObject("data").getJSONArray("tasks").getJSONObject(0).put("sourceLogId", "../file")
        assertThrows(Backup.BackupFormatException::class.java) { Backup.parseStrict(badLink.toString()) }
    }

    @Test fun recoverySkipsMalformedSchema2RecordWithoutDroppingValidFields() {
        val input = document()
        input.getJSONObject("data").getJSONArray("emotions").getJSONObject(0).put("intensity", false)
        val recovered = Backup.parseRecovery(input.toString())
        assertEquals(1, recovered.skippedEmotions)
        assertEquals(1, recovered.emotions.size)
        val output = JSONObject(Backup.exportJson(recovered.logs, recovered.emotions, recovered.tasks))
        assertTrue(output.getJSONObject("data").getJSONArray("logs").getJSONObject(0).getBoolean("isFavorite"))
    }

    @Test fun favoriteOnlyChangesInvalidateImportPreviewEquality() {
        val original = Backup.parseStrict(document().toString())
        val changed = original.logs.mapIndexed { index, log -> if (index == 0) log.copy(isFavorite = false) else log }
        val difference = BackupDiff.analyze(original.logs, original.emotions, changed, original.emotions,
            original.tasks, original.tasks)
        assertEquals(1, difference.logs.changed)
        assertFalse(BackupDiff.sameData(FlashSnapshot(original.logs, original.emotions, original.tasks),
            FlashSnapshot(changed, original.emotions, original.tasks)))
    }
}
