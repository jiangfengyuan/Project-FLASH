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
import java.time.format.DateTimeFormatter
import java.util.UUID

/**
 * 对应 Web 版 StorageAdapter 的仓库层。
 * createdAt 使用 ISO-8601（与 JS Date#toISOString 同格式），recordDate 为 yyyy-MM-dd。
 */
class FlashRepository(private val db: FlashDatabase) {

    val logs: Flow<List<LogItem>> =
        db.logDao().observeAll().map { list -> list.map { it.toModel() } }

    val emotions: Flow<List<EmotionRecord>> =
        db.emotionDao().observeAll().map { list -> list.map { it.toModel() } }

    suspend fun addLog(
        content: String,
        colorTag: ColorTag,
        category: Category = Category.LOG,
        importance: Int = 0,
    ) {
        db.logDao().upsert(
            LogItem(
                id = UUID.randomUUID().toString(),
                content = content,
                colorTag = colorTag,
                category = category,
                importance = importance.coerceIn(0, 4),
                createdAt = DateTimeFormatter.ISO_INSTANT.format(Instant.now()),
                recordDate = LocalDate.now().toString(),
            ).toEntity()
        )
    }

    suspend fun updateLog(log: LogItem) = db.logDao().upsert(log.toEntity())

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
                status = status,
                note = note,
                recordDate = LocalDate.now().toString(),
                createdAt = DateTimeFormatter.ISO_INSTANT.format(Instant.now()),
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
