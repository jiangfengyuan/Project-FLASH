package com.flash.app.data

import com.flash.app.data.model.Category
import com.flash.app.data.model.ColorTag
import org.json.JSONArray
import org.json.JSONObject
import java.text.Normalizer

/** v3 and v4 share v2's content partitions; extended fields must be validated against that content. */
internal object LibraryBackup {
    const val V3 = "flash-backup-v3"
    const val V4 = "flash-backup-v4"
    private val header = setOf("version", "exportedAt", "appVersion", "notes", "schemas", "data")
    private val v4Fields = setOf("trash", "automaticTags", "preferences")
    private val kinds = setOf("idea", "log", "emotion", "task")
    private val colors = ColorTag.entries.mapTo(mutableSetOf()) { it.storageKey }

    fun supports(root: JSONObject) = root.opt("version") in setOf(V3, V4)

    private fun invalid(field: String): Nothing = throw Backup.BackupFormatException(
        com.flash.app.i18n.tr("{0}：缺少必填字段或包含未知字段", "/$field")
    )
    private fun check(valid: Boolean, field: String) { if (!valid) invalid(field) }
    private fun JSONObject.fields(required: Set<String>, optional: Set<String> = emptySet()) {
        check(required.all(::has) && keys().asSequence().all { it in required || it in optional }, "personalLibrary")
    }
    private fun JSONObject.obj(name: String) = optJSONObject(name) ?: invalid(name)
    private fun JSONObject.string(name: String) = opt(name) as? String ?: invalid(name)
    private fun JSONObject.id(): String = string("id").also { check(Backup.UUID_REGEX.matches(it), "id") }
    private fun JSONObject.bool(name: String) { check(opt(name) is Boolean, name) }
    private fun JSONObject.number(name: String): Double =
        (opt(name) as? Number)?.toDouble()?.takeIf { it.isFinite() } ?: invalid(name)
    private fun JSONObject.int(name: String, range: IntRange): Int {
        val value = number(name)
        check(value % 1 == 0.0 && value >= range.first && value <= range.last, name)
        return value.toInt()
    }
    private fun JSONObject.array(name: String, max: Int): JSONArray =
        (optJSONArray(name) ?: invalid(name)).also { check(it.length() <= max, name) }
    private fun JSONArray.stringValues(max: Int, field: String): List<String> {
        check(length() <= max, field)
        return List(length()) { opt(it) as? String ?: invalid(field) }
    }
    private fun JSONObject.objects(name: String, max: Int): Map<String, JSONObject> {
        val array = array(name, max)
        val result = linkedMapOf<String, JSONObject>()
        for (i in 0 until array.length()) {
            val obj = array.optJSONObject(i) ?: invalid(name)
            check(result.put(obj.id(), obj) == null, name)
        }
        return result
    }

    fun parse(root: JSONObject): Backup.ImportResult {
        val version = root.string("version")
        val v4 = version == V4
        root.fields(header + "personalLibrary" + if (v4) v4Fields else emptySet())
        val core = JSONObject()
        for (field in header) core.put(field, root.get(field))
        core.put("version", Backup.BACKUP_VERSION)
        val result = Backup.parseStrictCore(core)
        val keys = buildSet {
            result.logs.forEach { add("log:" + it.id) }
            result.emotions.forEach { add("emotion:" + it.id) }
            result.tasks.forEach { add("task:" + it.id) }
        }
        val ideas = result.logs.filter { it.category == Category.IDEA }.mapTo(mutableSetOf()) { it.id }
        val personal = root.obj("personalLibrary")
        personal.fields(setOf("tags", "links", "filters", "reminders", "showEmotions", "summaryHour", "summaryMinute",
            "summaryEnabled", "summaryIntervalDays", "remindersNeedConfirmation"))
        for (flag in listOf("showEmotions", "summaryEnabled", "remindersNeedConfirmation")) personal.bool(flag)
        check(personal.int("summaryIntervalDays", 1..7) in listOf(1, 3, 7), "summaryIntervalDays")
        personal.int("summaryHour", 9..21)
        personal.int("summaryMinute", 0..59)
        val tags = readTags(personal, 1000)
        val links = readLinks(personal.obj("links")) { key, ids -> key in keys && ids.all(tags::containsKey) }
        val filters = personal.objects("filters", 100).mapValues { (_, filter) ->
            validateFilter(filter, tags.keys)
            filter.toString()
        }
        val reminders = personal.objects("reminders", Backup.MAX_ENTRY_COUNT).mapValues { (id, rule) ->
            check(id in ideas, "reminders")
            validateReminder(rule)
            rule.toString()
        }
        val library = LibraryMetadata(
            tags, links, filters, reminders, LibrarySettings.read(personal),
            preferences = if (v4) preferences(root.obj("preferences")) else null,
            automaticTags = if (v4) readLinks(root.obj("automaticTags")) { key, ids ->
                ids.isNotEmpty() && links[key]?.containsAll(ids) == true
            } else emptyMap(),
            trash = if (v4) root.objects("trash", Backup.MAX_ENTRY_COUNT).mapValues { (_, item) ->
                validateArchive(item)
                item.toString()
            } else emptyMap(),
        )
        return result.copy(sourceVersion = version, library = library.withoutExpired())
    }

    private fun readTags(container: JSONObject, limit: Int): Map<String, String> {
        val names = mutableSetOf<String>()
        return container.objects("tags", limit).mapValues { (_, tag) ->
            tag.fields(setOf("id", "name"))
            val name = tag.string("name")
            check(name.isNotEmpty() && name.codePointCount(0, name.length) <= 80 &&
                name.trim { it.isWhitespace() || it == '\uFEFF' } == name &&
                Normalizer.isNormalized(name, Normalizer.Form.NFC) && names.add(name.lowercase()), "tags")
            name
        }
    }
    private fun readLinks(obj: JSONObject, valid: (String, List<String>) -> Boolean): Map<String, List<String>> =
        obj.keys().asSequence().associateWith { key ->
            val ids = obj.array(key, 20).stringValues(20, "links")
            check(ids.size == ids.distinct().size && valid(key, ids), "links")
            ids
        }

    private fun validateFilter(filter: JSONObject, tagIDs: Set<String>) = with(filter) {
        fields(setOf("id", "name", "kinds", "query", "tagIDs", "matchAll", "colors", "favoritesOnly",
            "startDay", "endDay", "taskStatus", "oldestFirst"))
        val name = string("name")
        check(name.isNotBlank() && name.codePointCount(0, name.length) <= 80, "filters/name")
        check(string("query").length <= Backup.MAX_FIELD_LENGTH, "filters/query")
        check(array("kinds", 4).stringValues(4, "kinds").all(kinds::contains), "kinds")
        check(array("colors", 6).stringValues(6, "colors").all(colors::contains), "colors")
        check(array("tagIDs", 1000).stringValues(1000, "tagIDs").all(tagIDs::contains), "tagIDs")
        check(string("taskStatus") in setOf("all", "open", "completed"), "taskStatus")
        for (flag in listOf("matchAll", "favoritesOnly", "oldestFirst")) bool(flag)
        val start = string("startDay")
        val end = string("endDay")
        check(listOf(start, end).all { it.isEmpty() || Backup.isValidRecordDate(it) } &&
            (start.isEmpty() || end.isEmpty() || start <= end), "filters/day")
    }

    private fun validateReminder(rule: JSONObject) = with(rule) {
        fields(setOf("id", "enabled", "hour", "minute", "intervalDays", "anchorDay"))
        bool("enabled")
        int("hour", 9..21)
        int("minute", 0..59)
        check(int("intervalDays", 1..7) in listOf(1, 3, 7) && Backup.isValidRecordDate(string("anchorDay")), "reminders")
    }

    private fun preferences(value: JSONObject): LibraryPreferences {
        value.fields(setOf("taggingMode", "retentionDays"))
        val mode = value.string("taggingMode")
        check(mode in setOf("suggest", "existing", "organize"), "taggingMode")
        return LibraryPreferences(mode, value.int("retentionDays", 0..365))
    }

    private fun validateArchive(item: JSONObject) = with(item) {
        fields(setOf("id", "deletedAt", "tags", "automaticTagIDs"), setOf("expiresAt", "log", "emotion", "task", "reminder"))
        val deleted = number("deletedAt")
        check(!has("expiresAt") || number("expiresAt") >= deleted, "trash/expiresAt")
        val kinds = listOf("log", "emotion", "task").filter(::has)
        check(kinds.size == 1, "trash")
        val record = obj(kinds.single())
        check(record.keys().asSequence().none(record::isNull), "trash/record")
        when (kinds.single()) {
            "log" -> {
                record.fields(setOf("id","content","category","colorTag","importance","createdAt","recordDate"), setOf("isFavorite"))
                check(Backup.parseLog(record) != null, "trash/log")
            }
            "emotion" -> {
                record.fields(setOf("id","level","createdAt","recordDate"), setOf("subEmotion","status","note","isFavorite","intensity"))
                check(Backup.parseEmotion(record) != null, "trash/emotion")
            }
            "task" -> validateArchivedTask(record)
        }
        val tags = readTags(item, 20)
        val automatic = array("automaticTagIDs", 20).stringValues(20, "automaticTagIDs")
        check(automatic.distinct().size == automatic.size && automatic.all(tags::containsKey), "automaticTagIDs")
        if (has("reminder")) {
            val rule = obj("reminder")
            check(kinds.single() == "log" && record.string("category") == "idea" && record.id() == rule.id(), "trash/reminder")
            validateReminder(rule)
        }
    }

    private fun validateArchivedTask(record: JSONObject) = with(record) {
        val kind = string("dueKind")
        val due = JSONObject().put("kind", kind)
        val dueKeys = when (kind) {
            "allDay" -> setOf("dueDate").also { due.put("date", string("dueDate")) }
            "dateTime" -> setOf("dueAt", "timeZone").also { due.put("at", string("dueAt")).put("timeZone", string("timeZone")) }
            else -> invalid("trash/dueKind")
        }
        fields(setOf("id","title","colorTag","importance","dueKind","createdAt","updatedAt") + dueKeys,
            setOf("sourceLogId","isFavorite","reminderAt","completedAt","notes"))
        val standard = JSONObject()
        for (field in keys()) if (field != "dueKind" && field !in dueKeys) standard.put(field, get(field))
        check(Backup.parseTask(standard.put("due", due)) != null, "trash/task")
    }
}
