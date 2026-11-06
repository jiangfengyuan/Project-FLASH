// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package com.flash.app.data

import com.flash.app.data.model.ColorTag
import com.flash.app.data.model.TaskDueKind
import com.flash.app.data.model.TaskItem
import java.io.ByteArrayInputStream
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Test

class BackupTest {

    private fun sampleBackup(
        logRecordDate: String = "2026-02-28",
        emotionRecordDate: String = "2026-02-28",
    ): String {
        return """
        {
          "version": "flash-backup-v1",
          "exportedAt": "2026-02-28T00:00:00Z",
          "appVersion": "0.1.0",
          "notes": "",
          "logs": [
            {
              "id": "11111111-1111-1111-1111-111111111111",
              "content": "hello",
              "colorTag": "daily",
              "category": "log",
              "importance": 2,
              "createdAt": "2026-02-28T00:00:00Z",
              "recordDate": "$logRecordDate"
            }
          ],
          "emotions": [
            {
              "id": "22222222-2222-2222-2222-222222222222",
              "level": 1,
              "subEmotion": null,
              "status": null,
              "note": null,
              "recordDate": "$emotionRecordDate",
              "createdAt": "2026-02-28T00:00:00Z"
            }
          ]
        }
        """.trimIndent()
    }

    private fun sampleV2TaskBackup(timeZone: String = "Asia/Shanghai"): String = """
        {
          "version": "flash-backup-v2",
          "exportedAt": "2026-08-31T00:00:00Z",
          "appVersion": "0.1.0",
          "notes": "",
          "schemas": { "logs": 1, "emotions": 1, "tasks": 1 },
          "data": {
            "logs": [],
            "emotions": [],
            "tasks": [{
              "id": "33333333-3333-3333-3333-333333333333",
              "title": "交付设计稿",
              "notes": null,
              "colorTag": "memo",
              "importance": 3,
              "due": {
                "kind": "dateTime",
                "at": "2026-09-01T01:30:00Z",
                "timeZone": "$timeZone"
              },
              "reminderAt": "2026-09-01T00:30:00Z",
              "completedAt": null,
              "createdAt": "2026-08-31T00:00:00Z",
              "updatedAt": "2026-08-31T00:01:00Z"
            }]
          }
        }
    """.trimIndent()

    @Test
    fun `parse rejects non-existent recordDate in logs`() {
        val result = Backup.parse(sampleBackup(logRecordDate = "2026-02-30"))
        assertEquals(0, result.logs.size)
        assertEquals(1, result.skippedLogs)
    }

    @Test
    fun `parse rejects non-existent recordDate in emotions`() {
        val result = Backup.parse(sampleBackup(emotionRecordDate = "2026-02-30"))
        assertEquals(0, result.emotions.size)
        assertEquals(1, result.skippedEmotions)
    }

    @Test
    fun `parse accepts valid recordDate`() {
        val result = Backup.parse(sampleBackup())
        assertEquals(1, result.logs.size)
        assertEquals(1, result.emotions.size)
        assertEquals(0, result.tasks.size)
        assertEquals(Backup.LEGACY_BACKUP_VERSION, result.sourceVersion)
    }

    @Test
    fun `parse accepts v2 task section and normalizes timestamps`() {
        val result = Backup.parse(sampleV2TaskBackup())

        assertEquals(Backup.BACKUP_VERSION, result.sourceVersion)
        assertEquals(1, result.tasks.size)
        assertEquals("交付设计稿", result.tasks.single().title)
        assertEquals("2026-09-01T01:30:00.000Z", result.tasks.single().dueAt)
        assertEquals("2026-09-01", result.tasks.single().calendarDate)
    }

    @Test
    fun `modern and legacy time zones retain wire spelling and native calendar rules`() {
        for (identifier in listOf("Europe/Kyiv", "Europe/Kiev", "Asia/Kolkata", "Asia/Calcutta", "Asia/Kathmandu", "Asia/Katmandu", "Africa/Asmara", "Africa/Asmera", "Pacific/Chuuk", "Pacific/Truk")) {
            val first = Backup.parse(sampleV2TaskBackup(identifier))
            assertEquals(identifier, 1, first.tasks.size)
            assertEquals(identifier, first.tasks.single().timeZone)
            val second = Backup.parse(Backup.exportJson(first.logs, first.emotions, first.tasks))
            assertEquals(first.tasks, second.tasks)
            assertEquals("2026-09-01", second.tasks.single().calendarDate)
        }
    }

    @Test
    fun `IANA rename aliases support older native databases without GMT fallback`() {
        for ((modern, legacy) in listOf("Europe/Kyiv" to "Europe/Kiev", "Asia/Kolkata" to "Asia/Calcutta", "Africa/Asmara" to "Africa/Asmera", "Pacific/Chuuk" to "Pacific/Truk")) {
            assertEquals(legacy, CanonicalTimeZones.runtimeIdentifier(modern) { it == legacy })
            assertEquals(modern, CanonicalTimeZones.runtimeIdentifier(legacy) { it == modern })
        }
        assertEquals(null, CanonicalTimeZones.runtimeIdentifier("Europe/Kyiv") { false })
        assertEquals(null, CanonicalTimeZones.runtimeIdentifier("Africa/Asmara") { it == "Africa/Nairobi" })
        for (bad in listOf("utc", "Zulu", "US/Eastern", "+08:00", "Europe/kyiv", "Mars/Olympus")) {
            assertEquals(null, CanonicalTimeZones.runtimeIdentifier(bad) { true })
        }
    }

    @Test
    fun `device-reported zones outside the wire set never fail export`() {
        val task = Backup.parse(sampleV2TaskBackup("Asia/Shanghai")).tasks.single()
        for ((device, wire) in listOf(
            "GMT" to "UTC", "Etc/GMT" to "UTC", "Zulu" to "UTC", "Asia/Chongqing" to "Asia/Shanghai",
            "US/Eastern" to "America/New_York", "Asia/Ho_Chi_Minh" to "Asia/Ho_Chi_Minh",
            "UTC" to "UTC", "Etc/UTC" to "Etc/UTC",
        )) {
            val parsed = Backup.parse(Backup.exportJson(emptyList(), emptyList(), listOf(task.copy(timeZone = device))))
            assertEquals(device, wire, parsed.tasks.single().timeZone)
            assertEquals(device, task.dueAt, parsed.tasks.single().dueAt)
        }
    }

    @Test
    fun `a fixed-offset device zone degrades to UTC with the instant kept and a note recorded`() {
        val task = Backup.parse(sampleV2TaskBackup("Asia/Shanghai")).tasks.single()
        val json = Backup.exportJson(emptyList(), emptyList(), listOf(task.copy(timeZone = "GMT+08:00")), notes = "kept")
        val parsed = Backup.parse(json)
        assertEquals("UTC", parsed.tasks.single().timeZone)
        assertEquals(task.dueAt, parsed.tasks.single().dueAt)
        val notes = org.json.JSONObject(json).getString("notes")
        org.junit.Assert.assertTrue(notes, notes.startsWith("kept\n") && notes.contains("GMT+08:00") && notes.contains("UTC"))
        val exact = Backup.exportJson(emptyList(), emptyList(), listOf(task), notes = "kept")
        assertEquals("kept", org.json.JSONObject(exact).getString("notes"))
    }

    @Test
    fun `every JDK zone ID exports`() {
        val task = Backup.parse(sampleV2TaskBackup("Asia/Shanghai")).tasks.single()
        for (device in java.time.ZoneId.getAvailableZoneIds()) {
            val parsed = Backup.parse(Backup.exportJson(emptyList(), emptyList(), listOf(task.copy(timeZone = device))))
            assertEquals(device, 1, parsed.tasks.size)
        }
    }

    @Test
    fun `a local task keeps the native rules of its device zone`() {
        for (device in listOf("GMT", "US/Eastern", "GMT+08:00")) {
            assertEquals(device, java.time.ZoneId.of(device), CanonicalTimeZones.zoneId(device))
        }
        assertEquals(null, CanonicalTimeZones.zoneId("Mars/Olympus"))
    }

    @Test
    fun `parse skips a timed task with invalid IANA time zone`() {
        val result = Backup.parse(sampleV2TaskBackup(timeZone = "Mars/Olympus"))

        assertEquals(0, result.tasks.size)
        assertEquals(1, result.skippedTasks)
    }

    @Test
    fun `export writes section envelope and normalized task timestamps`() {
        val task = TaskItem(
            id = "33333333-3333-3333-3333-333333333333",
            title = "任务",
            notes = null,
            colorTag = ColorTag.MEMO,
            importance = 0,
            dueKind = TaskDueKind.DATE_TIME,
            dueDate = null,
            dueAt = "2026-09-01T01:30:00Z",
            timeZone = "Asia/Shanghai",
            reminderAt = null,
            completedAt = null,
            createdAt = "2026-08-31T00:00:00Z",
            updatedAt = "2026-08-31T00:00:00Z",
        )

        val root = JSONObject(Backup.exportJson(emptyList(), emptyList(), listOf(task)))
        val exported = root.getJSONObject("data").getJSONArray("tasks").getJSONObject(0)

        assertEquals(Backup.BACKUP_VERSION, root.getString("version"))
        assertEquals(1, root.getJSONObject("schemas").getInt("tasks"))
        assertEquals("2026-09-01T01:30:00.000Z", exported.getJSONObject("due").getString("at"))
    }

    @Test
    fun `parse skips emotion with oversized optional text instead of losing the field`() {
        val oversizedNote = "x".repeat(Backup.MAX_FIELD_LENGTH + 1)
        val result = Backup.parse(sampleBackup().replace("\"note\": null", "\"note\": \"$oversizedNote\""))

        assertEquals(0, result.emotions.size)
        assertEquals(1, result.skippedEmotions)
    }

    @Test
    fun `parse skips emotion with non-string optional text`() {
        val result = Backup.parse(sampleBackup().replace("\"status\": null", "\"status\": 42"))

        assertEquals(0, result.emotions.size)
        assertEquals(1, result.skippedEmotions)
    }

    @Test
    fun `parse skips emotion with an unknown sub-emotion`() {
        val result = Backup.parse(sampleBackup().replace("\"subEmotion\": null", "\"subEmotion\": \"worried\""))

        assertEquals(0, result.emotions.size)
        assertEquals(1, result.skippedEmotions)
    }

    @Test
    fun `bounded reader rejects a stream larger than its declared limit`() {
        assertThrows(Backup.BackupFormatException::class.java) {
            Backup.readJson(ByteArrayInputStream("12345".toByteArray()), maxBytes = 4)
        }
    }

    @Test
    fun `bounded reader rejects malformed UTF-8`() {
        assertThrows(Backup.BackupFormatException::class.java) {
            Backup.readJson(ByteArrayInputStream(byteArrayOf(0xC3.toByte(), 0x28)))
        }
    }

    @Test
    fun `parseRecovery accepts valid legacy and v2 files`() {
        val legacy = Backup.parseRecovery(sampleBackup())
        assertEquals(Backup.LEGACY_BACKUP_VERSION, legacy.sourceVersion)
        assertEquals(1, legacy.logs.size)

        val v2 = Backup.parseRecovery(sampleV2TaskBackup())
        assertEquals(Backup.BACKUP_VERSION, v2.sourceVersion)
        assertEquals(1, v2.tasks.size)
    }

    @Test
    fun `parseRecovery rejects duplicate keys before org json lenient parse`() {
        assertThrows(Backup.BackupFormatException::class.java) {
            Backup.parseRecovery(sampleBackup().replace("\"notes\": \"\"", "\"notes\": \"a\", \"notes\": \"b\""))
        }
    }

    @Test
    fun `parseRecovery rejects deeply nested json`() {
        val deep = "[".repeat(200) + "]".repeat(200)
        assertThrows(Backup.BackupFormatException::class.java) {
            Backup.parseRecovery(deep)
        }
    }

    @Test
    fun `parseRecovery rejects invalid json syntax`() {
        assertThrows(Backup.BackupFormatException::class.java) {
            Backup.parseRecovery("""{"version": "flash-backup-v1", invalid}""")
        }
    }
}
