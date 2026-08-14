package com.flash.app.data

import com.flash.app.data.model.Category
import com.flash.app.data.model.ColorTag
import com.flash.app.data.model.EmotionLevel
import com.flash.app.data.model.EmotionRecord
import com.flash.app.data.model.LogItem
import com.flash.app.data.model.SubEmotion
import com.flash.app.BuildConfig
import org.json.JSONArray
import org.json.JSONObject
import java.time.Instant

/**
 * JSON 备份导出/导入，格式与 Web 版 src/lib/backup.ts 完全一致：
 * { version, exportedAt, appVersion, notes, logs[], emotions[] }
 * 校验规则对齐 validateBackup / sanitizeBackup：非法条目跳过而非整体失败。
 */
object Backup {

    const val BACKUP_VERSION = "flash-backup-v1"

    fun exportJson(logs: List<LogItem>, emotions: List<EmotionRecord>, notes: String = ""): String {
        val logsArray = JSONArray()
        logs.forEach { log ->
            logsArray.put(
                JSONObject()
                    .put("id", log.id)
                    .put("content", log.content)
                    .put("colorTag", log.colorTag.storageKey)
                    .put("category", log.category.storageKey)
                    .put("importance", log.importance)
                    .put("createdAt", log.createdAt)
                    .put("recordDate", log.recordDate)
            )
        }
        val emotionsArray = JSONArray()
        emotions.forEach { e ->
            emotionsArray.put(
                JSONObject()
                    .put("id", e.id)
                    .put("level", e.level.value)
                    .put("subEmotion", e.subEmotion?.storageKey ?: JSONObject.NULL)
                    .put("status", e.status ?: JSONObject.NULL)
                    .put("note", e.note ?: JSONObject.NULL)
                    .put("recordDate", e.recordDate)
                    .put("createdAt", e.createdAt)
            )
        }
        return JSONObject()
            .put("version", BACKUP_VERSION)
            .put("exportedAt", Instant.now().toString())
            .put("appVersion", BuildConfig.VERSION_NAME)
            .put("notes", notes)
            .put("logs", logsArray)
            .put("emotions", emotionsArray)
            .toString(2)
    }

    data class ImportResult(
        val logs: List<LogItem>,
        val emotions: List<EmotionRecord>,
        val skippedLogs: Int,
        val skippedEmotions: Int,
    )

    class BackupFormatException(message: String) : Exception(message)

    private val UUID_REGEX =
        Regex("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$")
    private val RECORD_DATE_REGEX = Regex("^\\d{4}-\\d{2}-\\d{2}$")
    private val VALID_COLOR_TAGS = ColorTag.entries.map { it.storageKey }.toSet()
    private val VALID_CATEGORIES = Category.entries.map { it.storageKey }.toSet()

    /** @throws BackupFormatException 文件整体不合法时抛出；单条非法数据跳过。 */
    fun parse(json: String): ImportResult {
        val root = try {
            JSONObject(json)
        } catch (e: Exception) {
            throw BackupFormatException("备份文件不是有效的 JSON 对象")
        }

        val version = root.stringOrNull("version")
            ?: throw BackupFormatException("备份版本不兼容：缺少 version 字段")
        if (version != BACKUP_VERSION) {
            throw BackupFormatException("备份版本不兼容：期望 $BACKUP_VERSION，实际 $version")
        }
        val logsJson = root.optJSONArray("logs")
            ?: throw BackupFormatException("logs 必须是数组")
        val emotionsJson = root.optJSONArray("emotions")
            ?: throw BackupFormatException("emotions 必须是数组")

        val logs = mutableListOf<LogItem>()
        var skippedLogs = 0
        for (i in 0 until logsJson.length()) {
            val obj = logsJson.optJSONObject(i)
            val log = obj?.let(::parseLog)
            if (log != null) logs.add(log) else skippedLogs++
        }

        val emotions = mutableListOf<EmotionRecord>()
        var skippedEmotions = 0
        for (i in 0 until emotionsJson.length()) {
            val obj = emotionsJson.optJSONObject(i)
            val emotion = obj?.let(::parseEmotion)
            if (emotion != null) emotions.add(emotion) else skippedEmotions++
        }

        return ImportResult(logs, emotions, skippedLogs, skippedEmotions)
    }

    private fun parseLog(obj: JSONObject): LogItem? {
        val id = obj.optString("id").takeIf { UUID_REGEX.matches(it) } ?: return null
        val content = obj.stringOrNull("content") ?: return null
        val colorTag = obj.optString("colorTag").takeIf { it in VALID_COLOR_TAGS } ?: return null
        val category = obj.optString("category").takeIf { it in VALID_CATEGORIES } ?: return null
        val createdAt = obj.optString("createdAt").takeIf(::isIsoDate) ?: return null
        val recordDate = obj.optString("recordDate").takeIf { RECORD_DATE_REGEX.matches(it) }
            ?: return null
        return LogItem(
            id = id,
            content = content,
            colorTag = ColorTag.fromStorage(colorTag),
            category = Category.fromStorage(category),
            importance = obj.optInt("importance", 0).coerceIn(0, 4),
            createdAt = createdAt,
            recordDate = recordDate,
        )
    }

    private fun parseEmotion(obj: JSONObject): EmotionRecord? {
        val id = obj.optString("id").takeIf { UUID_REGEX.matches(it) } ?: return null
        if (!obj.has("level")) return null
        val level = obj.optInt("level", Int.MIN_VALUE)
        if (level < -3 || level > 3) return null
        val createdAt = obj.optString("createdAt").takeIf(::isIsoDate) ?: return null
        val recordDate = obj.optString("recordDate").takeIf { RECORD_DATE_REGEX.matches(it) }
            ?: return null
        val subEmotion = if (obj.isNull("subEmotion")) null
        else SubEmotion.fromStorage(obj.optString("subEmotion"))
        return EmotionRecord(
            id = id,
            level = EmotionLevel.fromValue(level),
            subEmotion = subEmotion,
            status = obj.stringOrNull("status"),
            note = obj.stringOrNull("note"),
            recordDate = recordDate,
            createdAt = createdAt,
        )
    }

    private fun JSONObject.stringOrNull(key: String): String? =
        if (isNull(key)) null else getString(key)

    private fun isIsoDate(value: String): Boolean = try {
        value.isNotBlank() && Instant.parse(value) != null
    } catch (e: Exception) {
        // Instant.parse 要求严格的 ISO-8601；Web 端 Date.parse 更宽松，这里按严格口径即可
        false
    }
}
