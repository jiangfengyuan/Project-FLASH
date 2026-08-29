// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package com.flash.app.data

import org.junit.Assert.assertEquals
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
}
