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
import com.flash.app.data.model.TaskItem
import androidx.room.withTransaction
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneOffset
import java.time.format.DateTimeFormatter
import java.time.format.DateTimeFormatterBuilder
import java.time.temporal.ChronoField
import java.util.UUID

data class FlashSnapshot(
    val logs: List<LogItem>,
    val emotions: List<EmotionRecord>,
    val tasks: List<TaskItem>,
)

/**
 * 对应 Web 版 StorageAdapter 的仓库层。
 * createdAt 使用 ISO-8601（与 JS Date#toISOString 同格式），recordDate 为 yyyy-MM-dd。
 */
class FlashRepository(private val db: FlashDatabase) {

    /** 与 macOS DateFormatting.isoNow() 对齐：UTC .SSSZ，固定 3 位毫秒 */
    private val ISO_MILLIS: DateTimeFormatter = DateTimeFormatterBuilder()
        .appendPattern("yyyy-MM-dd'T'HH:mm:ss")
        .appendLiteral('.')
        .appendValue(ChronoField.MILLI_OF_SECOND, 3)
        .appendLiteral('Z')
        .toFormatter()
        .withZone(ZoneOffset.UTC)

    private fun isoNow(): String = ISO_MILLIS.format(Instant.now())

    val logs: Flow<List<LogItem>> =
        db.logDao().observeAll().map { list -> list.map { it.toModel() } }

    val emotions: Flow<List<EmotionRecord>> =
        db.emotionDao().observeAll().map { list -> list.map { it.toModel() } }

    /** 从未打开详情的 Idea；阅读状态只保存在 Android 本地。 */
    val unviewedIdeas: Flow<List<LogItem>> =
        db.logDao().observeUnviewedIdeas().map { list -> list.map { it.toModel() } }

    val tasks: Flow<List<TaskItem>> =
        db.taskDao().observeAll().map { list -> list.map { it.toModel() } }

    fun observeLog(id: String): Flow<LogItem?> =
        db.logDao().observeById(id).map { it?.toModel() }

    /** 记录流分页（对应 Web 版 logFilters 的查询/标签/日期/排序，全部下推 SQL） */
    fun observeLogPage(
        query: String,
        tags: Set<String>,
        startDate: String?,
        endDate: String?,
        sort: String,
        limit: Int,
    ): Flow<List<LogItem>> = db.logDao()
        .observeLogPage(query, tags, tags.size, startDate, endDate, sort, limit)
        .map { list -> list.map { it.toModel() } }

    /** 与 [observeLogPage] 同条件的命中总数 */
    fun observeLogCount(
        query: String,
        tags: Set<String>,
        startDate: String?,
        endDate: String?,
    ): Flow<Int> = db.logDao().observeLogCount(query, tags, tags.size, startDate, endDate)

    /** 情绪历史分页 */
    fun observeEmotionPage(limit: Int): Flow<List<EmotionRecord>> =
        db.emotionDao().observePage(limit).map { list -> list.map { it.toModel() } }

    /** 近期情绪（统计窗口用，按 recordDate 下推） */
    fun observeEmotionsSince(startDate: String): Flow<List<EmotionRecord>> =
        db.emotionDao().observeSince(startDate).map { list -> list.map { it.toModel() } }

    suspend fun addLog(
        content: String,
        colorTag: ColorTag,
        category: Category = Category.LOG,
        importance: Int = 0,
    ) {
        val normalized = content.trim()
        if (normalized.isEmpty()) return
        // 用户输入超限拒绝写入（对齐 macOS），不静默截断；UI 层负责提前拦截并提示
        TextLimits.requireFits(normalized)
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
        val normalized = log.content.trim()
        if (normalized.isEmpty()) return
        TextLimits.requireFits(normalized)
        db.logDao().upsert(
            log.copy(content = normalized, importance = log.importance.coerceIn(0, 4)).toEntity()
        )
    }

    suspend fun deleteLog(id: String) = db.logDao().deleteById(id)

    suspend fun isIdeaViewed(id: String): Boolean = db.logDao().isIdeaViewed(id)

    suspend fun markIdeaViewed(id: String) = db.logDao().markIdeaViewed(id, isoNow())

    suspend fun addEmotion(
        level: EmotionLevel,
        subEmotion: SubEmotion?,
        status: String? = null,
        note: String? = null,
    ) {
        val normalizedStatus = status?.trim()?.ifEmpty { null }
        val normalizedNote = note?.trim()?.ifEmpty { null }
        normalizedStatus?.let(TextLimits::requireFits)
        normalizedNote?.let(TextLimits::requireFits)
        db.emotionDao().upsert(
            EmotionRecord(
                id = UUID.randomUUID().toString(),
                level = level,
                subEmotion = subEmotion,
                status = normalizedStatus,
                note = normalizedNote,
                recordDate = LocalDate.now().toString(),
                createdAt = isoNow(),
            ).toEntity()
        )
    }

    suspend fun deleteEmotion(id: String) = db.emotionDao().deleteById(id)

    suspend fun addTask(task: TaskItem) {
        db.taskDao().upsert(task.toEntity())
    }

    suspend fun updateTask(task: TaskItem) {
        db.taskDao().upsert(task.copy(updatedAt = isoNow()).toEntity())
    }

    suspend fun setTaskCompleted(task: TaskItem, completed: Boolean): TaskItem {
        val now = isoNow()
        val updated = task.copy(
            completedAt = if (completed) now else null,
            updatedAt = now,
        )
        db.taskDao().upsert(updated.toEntity())
        return updated
    }

    suspend fun deleteTask(id: String) = db.taskDao().deleteById(id)

    fun newTask(
        title: String,
        notes: String?,
        colorTag: ColorTag,
        importance: Int,
        dueKind: com.flash.app.data.model.TaskDueKind,
        dueDate: String?,
        dueAt: String?,
        timeZone: String?,
        reminderAt: String?,
    ): TaskItem {
        val now = isoNow()
        return TaskItem(
            id = UUID.randomUUID().toString(),
            title = title.trim().take(200),
            notes = notes?.trim()?.take(Backup.MAX_FIELD_LENGTH)?.ifEmpty { null },
            colorTag = colorTag,
            importance = importance.coerceIn(0, 4),
            dueKind = dueKind,
            dueDate = dueDate,
            dueAt = dueAt,
            timeZone = timeZone,
            reminderAt = reminderAt,
            completedAt = null,
            createdAt = now,
            updatedAt = now,
        )
    }

    suspend fun exportSnapshot(): FlashSnapshot {
        // All three sections must describe one logical database instant. Reading
        // separate Flows allowed a write to land between sections and produced a
        // backup that never existed locally as a whole.
        return db.withTransaction {
            FlashSnapshot(
                logs = db.logDao().getAll().map { it.toModel() },
                emotions = db.emotionDao().getAll().map { it.toModel() },
                tasks = db.taskDao().getAll().map { it.toModel() },
            )
        }
    }

    /** 覆盖式导入：清空后写入（对应 Web 版 overwriteImport） */
    suspend fun replaceAll(
        logs: List<LogItem>,
        emotions: List<EmotionRecord>,
        tasks: List<TaskItem>,
    ) {
        db.withTransaction {
            db.logDao().clearAll()
            db.emotionDao().clearAll()
            db.taskDao().clearAll()
            db.logDao().upsertAll(logs.map { it.toEntity() })
            db.emotionDao().upsertAll(emotions.map { it.toEntity() })
            db.taskDao().upsertAll(tasks.map { it.toEntity() })
        }
    }

    /** 合并式导入：同 id 覆盖，其余保留（对应 Web 版 mergeImport） */
    suspend fun mergeAll(
        logs: List<LogItem>,
        emotions: List<EmotionRecord>,
        tasks: List<TaskItem>,
    ) {
        db.withTransaction {
            db.logDao().upsertAll(logs.map { it.toEntity() })
            db.emotionDao().upsertAll(emotions.map { it.toEntity() })
            val localTasks = db.taskDao().getAll().associateBy { it.id }
            val accepted = tasks.filter { incoming ->
                val local = localTasks[incoming.id]
                local == null || Backup.normalizedTimestamp(incoming.updatedAt) >= Backup.normalizedTimestamp(local.updatedAt)
            }
            db.taskDao().upsertAll(accepted.map { it.toEntity() })
        }
    }

    suspend fun clearAll() {
        db.withTransaction {
            db.logDao().clearAll()
            db.emotionDao().clearAll()
            db.taskDao().clearAll()
        }
    }
}
