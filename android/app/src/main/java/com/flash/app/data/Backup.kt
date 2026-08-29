// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

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
import java.time.LocalDate
import java.time.ZoneOffset
import java.time.format.DateTimeFormatter
import java.time.format.DateTimeFormatterBuilder
import java.time.temporal.ChronoField

/**
 * JSON 备份导出/导入，格式与 Web 版 src/lib/backup.ts 完全一致：
 * { version, exportedAt, appVersion, notes, logs[], emotions[] }
 * 校验规则对齐 validateBackup / sanitizeBackup：非法条目跳过而非整体失败。
 */
object Backup {

    const val BACKUP_VERSION = "flash-backup-v1"

    /** 与 macOS BackupService 对齐的导入上限 */
    const val MAX_FILE_BYTES = 50L * 1024 * 1024        // 50 MB
    const val MAX_ENTRY_COUNT = 1_000_000               // 单类条目上限
    const val MAX_FIELD_LENGTH = 100_000                // content / note / status 单字段上限

    /** 统一归一化为 UTC .SSSZ，避免整秒时省略小数导致字典序错乱 */
    private val NORMALIZED_ISO: DateTimeFormatter = DateTimeFormatterBuilder()
        .appendPattern("yyyy-MM-dd'T'HH:mm:ss")
        .appendValue(ChronoField.MILLI_OF_SECOND, 3)
        .appendLiteral('Z')
        .toFormatter()
        .withZone(ZoneOffset.UTC)

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

    private fun isValidRecordDate(value: String): Boolean {
        if (!RECORD_DATE_REGEX.matches(value)) return false
        return try {
            LocalDate.parse(value).toString() == value
        } catch (e: Exception) {
            false
        }
    }

    /** @throws BackupFormatException 文件整体不合法时抛出；单条非法数据跳过。 */
    fun parse(json: String): ImportResult {
        if (json.length > MAX_FILE_BYTES) {
            throw BackupFormatException("备份文件超过 ${MAX_FILE_BYTES / 1024 / 1024} MB，无法导入")
        }
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
            if (logs.size >= MAX_ENTRY_COUNT) {
                skippedLogs += logsJson.length() - i
                break
            }
            val obj = logsJson.optJSONObject(i)
            val log = obj?.let(::parseLog)
            if (log != null) logs.add(log) else skippedLogs++
        }

        val emotions = mutableListOf<EmotionRecord>()
        var skippedEmotions = 0
        for (i in 0 until emotionsJson.length()) {
            if (emotions.size >= MAX_ENTRY_COUNT) {
                skippedEmotions += emotionsJson.length() - i
                break
            }
            val obj = emotionsJson.optJSONObject(i)
            val emotion = obj?.let(::parseEmotion)
            if (emotion != null) emotions.add(emotion) else skippedEmotions++
        }

        return ImportResult(logs, emotions, skippedLogs, skippedEmotions)
    }

    private fun parseLog(obj: JSONObject): LogItem? {
        val id = obj.optString("id").takeIf { UUID_REGEX.matches(it) } ?: return null
        val content = obj.stringOrNull("content")?.takeIf { it.length <= MAX_FIELD_LENGTH }
            ?: return null
        val colorTag = obj.stringOrNull("colorTag")?.takeIf { it in VALID_COLOR_TAGS }
            ?: return null
        val category = obj.stringOrNull("category")?.takeIf { it in VALID_CATEGORIES }
            ?: return null
        val createdAt = normalizeIsoDate(obj.stringOrNull("createdAt")) ?: return null
        val recordDate = obj.stringOrNull("recordDate")?.takeIf(::isValidRecordDate)
            ?: return null
        val importance = obj.optInt("importance", 0).takeIf { it == obj.opt("importance") }
            ?.coerceIn(0, 4) ?: return null
        return LogItem(
            id = id,
            content = content,
            colorTag = ColorTag.fromStorage(colorTag),
            category = Category.fromStorage(category),
            importance = importance,
            createdAt = createdAt,
            recordDate = recordDate,
        )
    }

    private fun parseEmotion(obj: JSONObject): EmotionRecord? {
        val id = obj.optString("id").takeIf { UUID_REGEX.matches(it) } ?: return null
        if (!obj.has("level")) return null
        val level = obj.optInt("level", Int.MIN_VALUE).takeIf { it == obj.opt("level") }
            ?: return null
        if (level < -3 || level > 3) return null
        val createdAt = normalizeIsoDate(obj.stringOrNull("createdAt")) ?: return null
        val recordDate = obj.stringOrNull("recordDate")?.takeIf(::isValidRecordDate)
            ?: return null
        if (!obj.hasValidOptionalString("status") || !obj.hasValidOptionalString("note")) {
            return null
        }
        val subEmotion = when {
            !obj.has("subEmotion") || obj.isNull("subEmotion") -> null
            else -> SubEmotion.fromStorage(obj.stringOrNull("subEmotion") ?: return null) ?: return null
        }
        return EmotionRecord(
            id = id,
            level = EmotionLevel.fromValue(level),
            subEmotion = subEmotion,
            status = obj.stringOrNull("status")?.takeIf { it.length <= MAX_FIELD_LENGTH },
            note = obj.stringOrNull("note")?.takeIf { it.length <= MAX_FIELD_LENGTH },
            recordDate = recordDate,
            createdAt = createdAt,
        )
    }

    private fun JSONObject.stringOrNull(key: String): String? {
        if (!has(key) || isNull(key)) return null
        return opt(key) as? String
    }

    /**
     * Optional text fields may be absent or null, but an explicitly supplied value must be a
     * bounded string. Treating an oversized or wrongly typed field as null silently loses data
     * while reporting a successful import.
     */
    private fun JSONObject.hasValidOptionalString(key: String): Boolean =
        !has(key) || isNull(key) || ((opt(key) as? String)?.length ?: Int.MAX_VALUE) <= MAX_FIELD_LENGTH

    private fun normalizeIsoDate(value: String?): String? {
        if (value.isNullOrBlank()) return null
        return try {
            val instant = Instant.parse(value)
            NORMALIZED_ISO.format(instant)
        } catch (e: Exception) {
            null
        }
    }
}
