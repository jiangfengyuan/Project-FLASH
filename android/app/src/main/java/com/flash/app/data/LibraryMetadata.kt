package com.flash.app.data

import com.flash.app.data.db.LibraryEntry
import org.json.JSONArray
import org.json.JSONObject
import java.time.Instant

/** Filters, rules and archived records retain their validated wire fields, including fractional
 * Apple reference dates. Collections are stored one entry per Room row, not one backup-sized blob. */
@ConsistentCopyVisibility
data class LibraryMetadata internal constructor(
    internal val tags: Map<String, String> = emptyMap(),
    internal val links: Map<String, List<String>> = emptyMap(),
    internal val filters: Map<String, String> = emptyMap(),
    internal val reminders: Map<String, String> = emptyMap(),
    internal val settings: LibrarySettings = LibrarySettings(),
    internal val preferences: LibraryPreferences? = LibraryPreferences(),
    internal val automaticTags: Map<String, List<String>> = emptyMap(),
    internal val trash: Map<String, String> = emptyMap(),
) {
    val tagCount get() = tags.size
    val filterCount get() = filters.size
    val reminderCount get() = reminders.size
    val trashCount get() = trash.size
    val hasExtendedData get() = this != LibraryMetadata()

    private val hasPersonalSettings get() = tags.isNotEmpty() || links.isNotEmpty() ||
        filters.isNotEmpty() || reminders.isNotEmpty() || settings != LibrarySettings()

    internal fun imported() = copy(
        settings = settings.copy(remindersNeedConfirmation = hasPersonalSettings),
        preferences = preferences ?: LibraryPreferences(),
    )

    internal fun withoutExpired(now: Instant = Instant.now()): LibraryMetadata {
        val referenceSeconds = now.epochSecond - 978307200L + now.nano / 1e9
        return copy(trash = trash.filterValues {
            val item = JSONObject(it)
            !item.has("expiresAt") || item.getDouble("expiresAt") > referenceSeconds
        })
    }

    internal fun merge(incoming: LibraryMetadata): LibraryMetadata {
        val mergedTags = tags.toMutableMap()
        val existingByName = tags.entries.associate { it.value.lowercase() to it.key }
        // Resolve against the original catalog so changing array order never changes
        // whether a rename and a same-name import collapse two distinct tags.
        val remapped = incoming.tags.mapValues { (id, name) -> existingByName[name.lowercase()] ?: id }
        if (remapped.values.toSet().size != remapped.size) {
            throw Backup.BackupFormatException(com.flash.app.i18n.tr("标签冲突，无法无损合并"))
        }
        for ((id, name) in incoming.tags) {
            if (name.lowercase() !in existingByName) mergedTags[id] = name
        }
        val mergedLinks = links.toMutableMap()
        val mergedOrigins = automaticTags.toMutableMap()
        for ((key, incomingIDs) in incoming.links) {
            val localIDs = links[key].orEmpty()
            val localAutomatic = automaticTags[key].orEmpty()
            val combined = (localIDs + incomingIDs.map(remapped::getValue)).distinct()
            mergedLinks[key] = combined
            // A manual assignment on either side wins over automatic provenance.
            val manual = localIDs.minus(localAutomatic.toSet()) +
                incomingIDs.minus(incoming.automaticTags[key].orEmpty().toSet()).map(remapped::getValue)
            val automatic = combined.minus(manual.toSet())
            if (automatic.isEmpty()) mergedOrigins.remove(key) else mergedOrigins[key] = automatic
        }
        val mergedFilters = filters + incoming.filters.mapValues { (_, text) ->
            val filter = JSONObject(text)
            val tagIDs = filter.getJSONArray("tagIDs").strings().map(remapped::getValue)
            filter.put("tagIDs", JSONArray(tagIDs)).toString()
        }
        return LibraryMetadata(
            tags = mergedTags, links = mergedLinks, filters = mergedFilters,
            reminders = reminders + incoming.reminders,
            settings = incoming.settings.copy(remindersNeedConfirmation =
                settings.remindersNeedConfirmation || incoming.hasPersonalSettings),
            preferences = incoming.preferences ?: preferences, automaticTags = mergedOrigins,
            trash = trash + incoming.trash.filterKeys { it !in trash },
        ).withoutExpired()
    }

    internal fun writeTo(root: JSONObject) {
        val personal = settings.json()
        personal.put("tags", JSONArray(tags.map { (id, name) -> JSONObject().put("id", id).put("name", name) }))
        personal.put("links", links.jsonArrays())
        personal.put("filters", filters.jsonObjects())
        personal.put("reminders", reminders.jsonObjects())
        root.put("personalLibrary", personal)
        root.put("preferences", (preferences ?: LibraryPreferences()).json())
        root.put("automaticTags", automaticTags.jsonArrays())
        root.put("trash", trash.jsonObjects())
    }

    internal fun rows(): List<LibraryEntry> = buildList {
        fun addMap(kind: String, entries: Map<String, String>) {
            entries.entries.forEachIndexed { i, (key, value) -> add(LibraryEntry(kind, key, i, value)) }
        }
        addMap("tag", tags)
        addMap("link", links.mapValues { JSONArray(it.value).toString() })
        addMap("filter", filters)
        addMap("reminder", reminders)
        addMap("automatic", automaticTags.mapValues { JSONArray(it.value).toString() })
        addMap("trash", trash)
        add(LibraryEntry("settings", "", 0, settings.json().toString()))
        add(LibraryEntry("preferences", "", 0, (preferences ?: LibraryPreferences()).json().toString()))
    }

    internal companion object {

        fun fromRows(rows: List<LibraryEntry>): LibraryMetadata {
            val groups = rows.groupBy { it.kind }
            fun values(kind: String) = groups[kind].orEmpty().associate { it.entryKey to it.value }
            fun associations(kind: String) = values(kind).mapValues { JSONArray(it.value).strings() }
            return LibraryMetadata(
                tags = values("tag"), links = associations("link"), filters = values("filter"),
                reminders = values("reminder"), automaticTags = associations("automatic"), trash = values("trash"),
                settings = groups["settings"]?.single()?.let { LibrarySettings.read(JSONObject(it.value)) } ?: LibrarySettings(),
                preferences = groups["preferences"]?.single()?.let { LibraryPreferences.read(JSONObject(it.value)) } ?: LibraryPreferences(),
            )
        }
    }
}

internal data class LibraryPreferences(val taggingMode: String = "suggest", val retentionDays: Int = 30) {
    fun json() = JSONObject().put("taggingMode", taggingMode).put("retentionDays", retentionDays)
    companion object {
        fun read(value: JSONObject) = LibraryPreferences(value.getString("taggingMode"), value.getInt("retentionDays"))
    }
}

internal data class LibrarySettings(
    val showEmotions: Boolean = true, val summaryHour: Int = 20, val summaryMinute: Int = 0,
    val summaryEnabled: Boolean = true, val summaryIntervalDays: Int = 1, val remindersNeedConfirmation: Boolean = false,
) {
    fun json(): JSONObject = JSONObject().put("showEmotions", showEmotions).put("summaryHour", summaryHour)
        .put("summaryMinute", summaryMinute).put("summaryEnabled", summaryEnabled)
        .put("summaryIntervalDays", summaryIntervalDays).put("remindersNeedConfirmation", remindersNeedConfirmation)
    companion object {
        fun read(data: JSONObject) = LibrarySettings(data.getBoolean("showEmotions"), data.getInt("summaryHour"),
            data.getInt("summaryMinute"), data.getBoolean("summaryEnabled"), data.getInt("summaryIntervalDays"),
            data.getBoolean("remindersNeedConfirmation"))
    }
}

internal fun JSONArray.strings() = List(length()) { get(it) as String }
private fun Map<String, String>.jsonObjects() = JSONArray(values.map(::JSONObject))
private fun Map<String, List<String>>.jsonArrays() = JSONObject().also { result ->
    forEach { (key, ids) -> result.put(key, JSONArray(ids)) }
}
