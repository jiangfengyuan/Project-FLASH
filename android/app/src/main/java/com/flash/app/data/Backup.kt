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
import com.flash.app.data.model.TaskDueKind
import com.flash.app.data.model.TaskItem
import com.flash.app.BuildConfig
import org.json.JSONArray
import org.json.JSONObject
import java.io.ByteArrayOutputStream
import java.io.InputStream
import java.nio.ByteBuffer
import java.nio.charset.CodingErrorAction
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.time.ZoneOffset
import java.time.format.DateTimeFormatter
import java.time.format.DateTimeFormatterBuilder
import java.time.temporal.ChronoField

/**
 * JSON 备份导出/导入。v2 使用分区版本化 envelope；读取端继续兼容 v1。
 * 校验规则对齐 validateBackup / sanitizeBackup：非法条目跳过而非整体失败。
 */
object Backup {

    const val BACKUP_VERSION = "flash-backup-v2"
    const val LEGACY_BACKUP_VERSION = "flash-backup-v1"
    private const val SECTION_SCHEMA_V1 = 1

    /** 与 macOS BackupService 对齐的导入上限 */
    const val MAX_FILE_BYTES = 50L * 1024 * 1024        // 50 MB
    const val MAX_ENTRY_COUNT = 100_000                 // 单类条目上限（三端一致）
    const val MAX_FIELD_LENGTH = 100_000                // content / note / status 单字段上限

    /** 统一归一化为 UTC .SSSZ，避免整秒时省略小数导致字典序错乱 */
    private val NORMALIZED_ISO: DateTimeFormatter = DateTimeFormatterBuilder()
        .appendPattern("yyyy-MM-dd'T'HH:mm:ss")
        .appendLiteral('.')
        .appendValue(ChronoField.MILLI_OF_SECOND, 3)
        .appendLiteral('Z')
        .toFormatter()
        .withZone(ZoneOffset.UTC)

    fun exportJson(
        logs: List<LogItem>,
        emotions: List<EmotionRecord>,
        tasks: List<TaskItem>,
        notes: String = "",
    ): String {
        val logsArray = JSONArray()
        logs.forEach { log ->
            logsArray.put(
                JSONObject()
                    .put("id", log.id)
                    .put("content", log.content)
                    .put("colorTag", log.colorTag.storageKey)
                    .put("category", log.category.storageKey)
                    .put("importance", log.importance)
                    .put("createdAt", normalizedForExport(log.createdAt))
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
                    .put("createdAt", normalizedForExport(e.createdAt))
            )
        }
        val tasksArray = JSONArray()
        tasks.forEach { task ->
            val due = JSONObject().put("kind", task.dueKind.storageKey)
            when (task.dueKind) {
                TaskDueKind.ALL_DAY -> due.put("date", task.dueDate)
                TaskDueKind.DATE_TIME -> due
                    .put("at", task.dueAt?.let(::normalizedForExport))
                    .put("timeZone", task.timeZone)
            }
            tasksArray.put(
                JSONObject()
                    .put("id", task.id)
                    .put("title", task.title)
                    .put("notes", task.notes ?: JSONObject.NULL)
                    .put("colorTag", task.colorTag.storageKey)
                    .put("importance", task.importance)
                    .put("due", due)
                    .put("reminderAt", task.reminderAt?.let(::normalizedForExport) ?: JSONObject.NULL)
                    .put("completedAt", task.completedAt?.let(::normalizedForExport) ?: JSONObject.NULL)
                    .put("createdAt", normalizedForExport(task.createdAt))
                    .put("updatedAt", normalizedForExport(task.updatedAt))
            )
        }
        val schemas = JSONObject()
            .put("logs", SECTION_SCHEMA_V1)
            .put("emotions", SECTION_SCHEMA_V1)
            .put("tasks", SECTION_SCHEMA_V1)
        val data = JSONObject()
            .put("logs", logsArray)
            .put("emotions", emotionsArray)
            .put("tasks", tasksArray)
        return JSONObject()
            .put("version", BACKUP_VERSION)
            .put("exportedAt", NORMALIZED_ISO.format(Instant.now()))
            .put("appVersion", BuildConfig.VERSION_NAME)
            .put("notes", notes)
            .put("schemas", schemas)
            .put("data", data)
            .toString(2).also { parseStrict(it) }
    }

    data class ImportResult(
        val logs: List<LogItem>,
        val emotions: List<EmotionRecord>,
        val tasks: List<TaskItem>,
        val skippedLogs: Int,
        val skippedEmotions: Int,
        val skippedTasks: Int,
        val sourceVersion: String,
    )

    class BackupFormatException(message: String) : Exception(message)

    /**
     * 从外部来源读取 UTF-8 备份时始终按“字节”限额，不能信任内容提供方上报的文件大小。
     * 严格拒绝损坏的 UTF-8，避免替换字符让被篡改的数据静默通过校验。
     */
    fun readJson(input: InputStream, maxBytes: Long = MAX_FILE_BYTES): String {
        require(maxBytes in 1..Int.MAX_VALUE.toLong())
        val output = ByteArrayOutputStream(minOf(maxBytes, 64 * 1024L).toInt())
        val buffer = ByteArray(8192)
        var total = 0L
        while (true) {
            val read = input.read(buffer)
            if (read < 0) break
            total += read
            if (total > maxBytes) {
                throw BackupFormatException("备份文件超过 ${MAX_FILE_BYTES / 1024 / 1024} MB，无法导入")
            }
            output.write(buffer, 0, read)
        }
        return try {
            Charsets.UTF_8.newDecoder()
                .onMalformedInput(CodingErrorAction.REPORT)
                .onUnmappableCharacter(CodingErrorAction.REPORT)
                .decode(ByteBuffer.wrap(output.toByteArray()))
                .toString()
        } catch (_: Exception) {
            throw BackupFormatException("备份文件不是有效的 UTF-8 JSON")
        }
    }

    private val UUID_REGEX =
        Regex("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$")
    private val INSTANT_REGEX = Regex("""^(\d{4}-\d{2}-\d{2})T(\d{2}):(\d{2}):(\d{2})(?:\.(\d{1,9}))?(Z|[+-]\d{2}:\d{2})$""")
    private val RECORD_DATE_REGEX = Regex("^\\d{4}-\\d{2}-\\d{2}$")
    private val VALID_COLOR_TAGS = ColorTag.entries.map { it.storageKey }.toSet()
    private val VALID_CATEGORIES = Category.entries.map { it.storageKey }.toSet()

    private fun isValidRecordDate(value: String): Boolean {
        if (!RECORD_DATE_REGEX.matches(value)) return false
        return try {
            LocalDate.parse(value).let { it.year in 1..9999 && it.toString() == value }
        } catch (e: Exception) {
            false
        }
    }

    /** @throws BackupFormatException 文件整体不合法时抛出；单条非法数据跳过。 */
    fun parse(json: String): ImportResult {
        if (json.toByteArray(Charsets.UTF_8).size > MAX_FILE_BYTES) {
            throw BackupFormatException("备份文件超过 ${MAX_FILE_BYTES / 1024 / 1024} MB，无法导入")
        }
        val root = try {
            JSONObject(json)
        } catch (e: Exception) {
            throw BackupFormatException("备份文件不是有效的 JSON 对象")
        }

        val version = root.stringOrNull("version")
            ?: throw BackupFormatException("备份版本不兼容：缺少 version 字段")
        val sectionRoot = when (version) {
            LEGACY_BACKUP_VERSION -> root
            BACKUP_VERSION -> {
                val schemas = root.optJSONObject("schemas")
                    ?: throw BackupFormatException("schemas 必须是对象")
                listOf("logs", "emotions", "tasks").forEach { section ->
                    if (schemas.integerOrNull(section) != SECTION_SCHEMA_V1) {
                        throw BackupFormatException("不支持的 $section 分区版本")
                    }
                }
                root.optJSONObject("data")
                    ?: throw BackupFormatException("data 必须是对象")
            }
            else -> throw BackupFormatException("备份版本不兼容：期望 $BACKUP_VERSION，实际 $version")
        }
        val logsJson = sectionRoot.optJSONArray("logs")
            ?: throw BackupFormatException("logs 必须是数组")
        val emotionsJson = sectionRoot.optJSONArray("emotions")
            ?: throw BackupFormatException("emotions 必须是数组")
        val tasksJson = if (version == LEGACY_BACKUP_VERSION) {
            JSONArray()
        } else {
            sectionRoot.optJSONArray("tasks") ?: throw BackupFormatException("tasks 必须是数组")
        }

        val logs = mutableListOf<LogItem>()
        val logIds = mutableSetOf<String>()
        var skippedLogs = 0
        for (i in 0 until logsJson.length()) {
            if (i >= MAX_ENTRY_COUNT) {
                skippedLogs += logsJson.length() - i
                break
            }
            val obj = logsJson.optJSONObject(i)
            val log = obj?.let(::parseLog)
            if (log != null && logIds.add(log.id)) logs.add(log) else skippedLogs++
        }

        val emotions = mutableListOf<EmotionRecord>()
        val emotionIds = mutableSetOf<String>()
        var skippedEmotions = 0
        for (i in 0 until emotionsJson.length()) {
            if (i >= MAX_ENTRY_COUNT) {
                skippedEmotions += emotionsJson.length() - i
                break
            }
            val obj = emotionsJson.optJSONObject(i)
            val emotion = obj?.let(::parseEmotion)
            if (emotion != null && emotionIds.add(emotion.id)) emotions.add(emotion) else skippedEmotions++
        }

        val tasks = mutableListOf<TaskItem>()
        val taskIds = mutableSetOf<String>()
        var skippedTasks = 0
        for (i in 0 until tasksJson.length()) {
            if (i >= MAX_ENTRY_COUNT) {
                skippedTasks += tasksJson.length() - i
                break
            }
            val obj = tasksJson.optJSONObject(i)
            val task = obj?.let(::parseTask)
            if (task != null && taskIds.add(task.id)) tasks.add(task) else skippedTasks++
        }

        return ImportResult(
            logs, emotions, tasks,
            skippedLogs, skippedEmotions, skippedTasks,
            version,
        )
    }

    /** Standard v2 import: validate the entire snapshot before any repository write. */
    fun parseStrict(json: String): ImportResult {
        if (json.startsWith("\uFEFF")) throw BackupFormatException("/：不允许 UTF-8 BOM")
        if (json.toByteArray(Charsets.UTF_8).size > MAX_FILE_BYTES) throw BackupFormatException("文件超过 50 MiB")
        StrictJson(json).validate()
        val result = parse(json)
        val root = JSONObject(json)
        root.checkFields(setOf("version", "exportedAt", "appVersion", "notes", "schemas", "data"), "/")
        if (result.sourceVersion != BACKUP_VERSION) throw BackupFormatException("/version：旧版文件请使用兼容恢复入口")
        if (normalizeIsoDate(root.stringOrNull("exportedAt")) == null || root.stringOrNull("appVersion") == null ||
            root.stringOrNull("notes")?.let { it.length <= MAX_FIELD_LENGTH } != true) {
            throw BackupFormatException("/：导出元信息不合法")
        }
        val sections = setOf("logs", "emotions", "tasks")
        root.getJSONObject("schemas").checkFields(sections, "/schemas")
        val data = root.getJSONObject("data")
        data.checkFields(sections, "/data")
        for (section in sections) {
            val array = data.getJSONArray(section)
            if (array.length() > MAX_ENTRY_COUNT) throw BackupFormatException("/data/$section：数组超过上限")
            for (i in 0 until array.length()) {
                val item = array.optJSONObject(i) ?: throw BackupFormatException("/data/$section/$i：记录必须是对象")
                val required = when (section) {
                    "logs" -> setOf("id", "content", "colorTag", "category", "importance", "createdAt", "recordDate")
                    "emotions" -> setOf("id", "level", "createdAt", "recordDate")
                    else -> setOf("id", "title", "colorTag", "importance", "due", "createdAt", "updatedAt")
                }
                val optional = when (section) {
                    "emotions" -> setOf("subEmotion", "note", "status")
                    "tasks" -> setOf("notes", "reminderAt", "completedAt")
                    else -> emptySet()
                }
                item.checkFields(required, "/data/$section/$i", optional)
                if (section == "tasks") {
                    val due = item.optJSONObject("due") ?: throw BackupFormatException("/data/tasks/$i/due：必须是对象")
                    due.checkFields(if (due.optString("kind") == "allDay") setOf("kind", "date") else setOf("kind", "at", "timeZone"), "/data/tasks/$i/due")
                }
            }
        }
        if (result.skippedLogs + result.skippedEmotions + result.skippedTasks != 0) {
            throw BackupFormatException("/data：存在非法或重复记录，请使用损坏文件恢复入口查看可恢复内容")
        }
        return result
    }

    fun parseRecovery(json: String): ImportResult {
        val result = parse(json)
        val root = JSONObject(json)
        val legacy = result.sourceVersion == LEGACY_BACKUP_VERSION
        root.checkFields(emptySet(), "/", if (legacy) setOf("version", "exportedAt", "appVersion", "notes", "logs", "emotions") else setOf("version", "exportedAt", "appVersion", "notes", "schemas", "data"))
        val data = if (legacy) root else root.getJSONObject("data")
        if (!legacy) {
            root.getJSONObject("schemas").checkFields(setOf("logs", "emotions", "tasks"), "/schemas")
            data.checkFields(setOf("logs", "emotions", "tasks"), "/data")
        }
        for (section in if (legacy) listOf("logs", "emotions") else listOf("logs", "emotions", "tasks")) {
            val array = data.getJSONArray(section)
            val allowed = when (section) {
                "logs" -> setOf("id", "content", "colorTag", "category", "importance", "createdAt", "recordDate")
                "emotions" -> setOf("id", "level", "createdAt", "recordDate", "note", "status", "subEmotion")
                else -> setOf("id", "title", "colorTag", "importance", "due", "createdAt", "updatedAt", "notes", "reminderAt", "completedAt")
            }
            for (i in 0 until array.length()) {
                val item = array.optJSONObject(i) ?: continue
                item.checkFields(emptySet(), "/data/$section/$i", allowed)
                item.optJSONObject("due")?.checkFields(emptySet(), "/data/$section/$i/due", if (item.optJSONObject("due")?.optString("kind") == "allDay") setOf("kind", "date") else setOf("kind", "at", "timeZone"))
            }
        }
        return result
    }

    private fun JSONObject.checkFields(required: Set<String>, path: String, optional: Set<String> = emptySet()) {
        if (!required.all { has(it) } || keys().asSequence().any { it !in required && it !in optional }) {
            throw BackupFormatException("$path：缺少必填字段或包含未知字段")
        }
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
        val importance = obj.integerOrNull("importance")
            ?.takeIf { it in 0..4 } ?: return null
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
        val level = obj.integerOrNull("level")
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

    private fun parseTask(obj: JSONObject): TaskItem? {
        val id = obj.optString("id").takeIf { UUID_REGEX.matches(it) } ?: return null
        val title = obj.stringOrNull("title")
            ?.takeIf { it.trimContract().isNotEmpty() && it.length <= 200 } ?: return null
        if (!obj.hasValidOptionalString("notes") ||
            !obj.hasValidOptionalString("reminderAt") ||
            !obj.hasValidOptionalString("completedAt")
        ) return null
        val colorTag = obj.stringOrNull("colorTag")?.takeIf { it in VALID_COLOR_TAGS }
            ?: return null
        val importance = obj.integerOrNull("importance")
            ?.takeIf { it in 0..4 } ?: return null
        val due = obj.optJSONObject("due") ?: return null
        val dueKind = due.stringOrNull("kind")?.let(TaskDueKind::fromStorage) ?: return null
        var dueDate: String? = null
        var dueAt: String? = null
        var timeZone: String? = null
        when (dueKind) {
            TaskDueKind.ALL_DAY -> {
                dueDate = due.stringOrNull("date")?.takeIf(::isValidRecordDate) ?: return null
            }
            TaskDueKind.DATE_TIME -> {
                dueAt = normalizeIsoDate(due.stringOrNull("at")) ?: return null
                timeZone = due.stringOrNull("timeZone")?.takeIf { zone ->
                    zone == "UTC" || zone in ZoneId.getAvailableZoneIds()
                } ?: return null
            }
        }
        val createdAt = normalizeIsoDate(obj.stringOrNull("createdAt")) ?: return null
        val updatedAt = normalizeIsoDate(obj.stringOrNull("updatedAt")) ?: return null
        if (updatedAt < createdAt) return null
        val reminderAt = when {
            !obj.has("reminderAt") || obj.isNull("reminderAt") -> null
            else -> normalizeIsoDate(obj.stringOrNull("reminderAt")) ?: return null
        }
        val completedAt = when {
            !obj.has("completedAt") || obj.isNull("completedAt") -> null
            else -> normalizeIsoDate(obj.stringOrNull("completedAt")) ?: return null
        }
        return TaskItem(
            id = id,
            title = title.trimContract(),
            notes = obj.stringOrNull("notes")?.takeIf { it.length <= MAX_FIELD_LENGTH },
            colorTag = ColorTag.fromStorage(colorTag),
            importance = importance,
            dueKind = dueKind,
            dueDate = dueDate,
            dueAt = dueAt,
            timeZone = timeZone,
            reminderAt = reminderAt,
            completedAt = completedAt,
            createdAt = createdAt,
            updatedAt = updatedAt,
        )
    }

    private fun JSONObject.integerOrNull(key: String): Int? {
        val value = (opt(key) as? Number)?.toDouble() ?: return null
        return value.takeIf { it.isFinite() && it >= Int.MIN_VALUE && it <= Int.MAX_VALUE && it % 1.0 == 0.0 }?.toInt()
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
            val match = INSTANT_REGEX.matchEntire(value) ?: return null
            if (!isValidRecordDate(match.groupValues[1])) return null
            val hour = match.groupValues[2].toInt()
            val minute = match.groupValues[3].toInt()
            val second = match.groupValues[4].toInt()
            val zone = match.groupValues[6]
            if (hour > 23 || minute > 59 || second > 59 || zone == "-00:00") return null
            var offset = 0L
            if (zone != "Z") {
                val zh = zone.substring(1, 3).toInt()
                val zm = zone.substring(4, 6).toInt()
                if (zh > 23 || zm > 59) return null
                offset = (zh * 60L + zm) * 60 * if (zone[0] == '-') -1 else 1
            }
            val day = LocalDate.parse(match.groupValues[1]).toEpochDay()
            val millis = match.groupValues[5].padEnd(3, '0').take(3).toLong()
            val instant = Instant.ofEpochMilli((day * 86400 + hour * 3600 + minute * 60 + second - offset) * 1000 + millis)
            if (instant.atOffset(ZoneOffset.UTC).year !in 1..9999) return null
            NORMALIZED_ISO.format(instant)
        } catch (e: Exception) {
            null
        }
    }

    private fun String.trimContract(): String = trim { it in "\u0009\u000A\u000B\u000C\u000D\u0020\u00A0\u1680\u2000\u2001\u2002\u2003\u2004\u2005\u2006\u2007\u2008\u2009\u200A\u2028\u2029\u202F\u205F\u3000\uFEFF" }

    internal fun normalizedTimestamp(value: String): String =
        normalizeIsoDate(value) ?: throw BackupFormatException("任务时间不合法")

    private fun normalizedForExport(value: String): String =
        normalizeIsoDate(value) ?: value
}
