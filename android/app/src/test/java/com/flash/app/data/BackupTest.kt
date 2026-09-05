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
}
