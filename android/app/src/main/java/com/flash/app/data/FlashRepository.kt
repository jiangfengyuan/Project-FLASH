// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package com.flash.app.data

import com.flash.app.data.db.FlashDatabase
import com.flash.app.data.db.toEntity
import com.flash.app.data.db.toModel
import com.flash.app.data.model.Category
import com.flash.app.data.model.ColorTag
import com.flash.app.data.model.EmotionLevel
import com.flash.app.data.model.EmotionRecord
import com.flash.app.data.model.LogItem
import com.flash.app.data.model.SubEmotion
import androidx.room.withTransaction
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.map
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneOffset
import java.time.format.DateTimeFormatter
import java.time.format.DateTimeFormatterBuilder
import java.time.temporal.ChronoField
import java.util.UUID

/**
 * 对应 Web 版 StorageAdapter 的仓库层。
 * createdAt 使用 ISO-8601（与 JS Date#toISOString 同格式），recordDate 为 yyyy-MM-dd。
 */
class FlashRepository(private val db: FlashDatabase) {

    /** 与 macOS DateFormatting.isoNow() 对齐：UTC .SSSZ，固定 3 位毫秒 */
    private val ISO_MILLIS: DateTimeFormatter = DateTimeFormatterBuilder()
        .appendPattern("yyyy-MM-dd'T'HH:mm:ss")
        .appendValue(ChronoField.MILLI_OF_SECOND, 3)
        .appendLiteral('Z')
        .toFormatter()
        .withZone(ZoneOffset.UTC)

    private fun isoNow(): String = ISO_MILLIS.format(Instant.now())

    val logs: Flow<List<LogItem>> =
        db.logDao().observeAll().map { list -> list.map { it.toModel() } }

    val emotions: Flow<List<EmotionRecord>> =
        db.emotionDao().observeAll().map { list -> list.map { it.toModel() } }

    fun observeLog(id: String): Flow<LogItem?> =
        db.logDao().observeById(id).map { it?.toModel() }

    suspend fun addLog(
        content: String,
        colorTag: ColorTag,
        category: Category = Category.LOG,
        importance: Int = 0,
    ) {
        val normalized = content.trim().take(Backup.MAX_FIELD_LENGTH)
        if (normalized.isEmpty()) return
        db.logDao().upsert(
            LogItem(
                id = UUID.randomUUID().toString(),
                content = normalized,
                colorTag = colorTag,
                category = category,
                importance = importance.coerceIn(0, 4),
                createdAt = isoNow(),
                recordDate = LocalDate.now().toString(),
            ).toEntity()
        )
    }

    suspend fun updateLog(log: LogItem) {
        val normalized = log.content.trim().take(Backup.MAX_FIELD_LENGTH)
        if (normalized.isEmpty()) return
        db.logDao().upsert(
            log.copy(content = normalized, importance = log.importance.coerceIn(0, 4)).toEntity()
        )
    }

    suspend fun deleteLog(id: String) = db.logDao().deleteById(id)

    suspend fun addEmotion(
        level: EmotionLevel,
        subEmotion: SubEmotion?,
        status: String? = null,
        note: String? = null,
    ) {
        db.emotionDao().upsert(
            EmotionRecord(
                id = UUID.randomUUID().toString(),
                level = level,
                subEmotion = subEmotion,
                status = status?.trim()?.take(Backup.MAX_FIELD_LENGTH)?.ifEmpty { null },
                note = note?.trim()?.take(Backup.MAX_FIELD_LENGTH)?.ifEmpty { null },
                recordDate = LocalDate.now().toString(),
                createdAt = isoNow(),
            ).toEntity()
        )
    }

    suspend fun deleteEmotion(id: String) = db.emotionDao().deleteById(id)

    suspend fun exportSnapshot(): Pair<List<LogItem>, List<EmotionRecord>> {
        val logs = db.logDao().observeAll().first()
        val emotions = db.emotionDao().observeAll().first()
        return logs.map { it.toModel() } to emotions.map { it.toModel() }
    }

    /** 覆盖式导入：清空后写入（对应 Web 版 overwriteImport） */
    suspend fun replaceAll(logs: List<LogItem>, emotions: List<EmotionRecord>) {
        db.withTransaction {
            db.logDao().clearAll()
            db.emotionDao().clearAll()
            db.logDao().upsertAll(logs.map { it.toEntity() })
            db.emotionDao().upsertAll(emotions.map { it.toEntity() })
        }
    }

    /** 合并式导入：同 id 覆盖，其余保留（对应 Web 版 mergeImport） */
    suspend fun mergeAll(logs: List<LogItem>, emotions: List<EmotionRecord>) {
        db.withTransaction {
            db.logDao().upsertAll(logs.map { it.toEntity() })
            db.emotionDao().upsertAll(emotions.map { it.toEntity() })
        }
    }

    suspend fun clearAll() {
        db.withTransaction {
            db.logDao().clearAll()
            db.emotionDao().clearAll()
        }
    }
}
