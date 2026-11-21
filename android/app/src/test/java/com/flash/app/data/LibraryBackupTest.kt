package com.flash.app.data

import org.json.JSONArray
import org.json.JSONObject
import org.junit.Assert.*
import org.junit.Test

class LibraryBackupTest {
    private fun fixture(name: String): JSONObject = javaClass.classLoader!!
        .getResourceAsStream("fixtures/valid-library-$name.json")!!.bufferedReader().use { JSONObject(it.readText()) }

    private fun parse(root: JSONObject) = Backup.parseStrict(root.toString())

    @Test fun appleArchiveAndMetadataSurviveFullExportAndExplicitCompatibilityChoice() {
        val original = parse(fixture("v4"))
        val library = requireNotNull(original.library)
        val snapshot = FlashSnapshot(original.logs, original.emotions, original.tasks, library)
        val full = Backup.exportSnapshot(snapshot)
        assertEquals(library, Backup.parseStrict(full).library)
        assertEquals(library, Backup.parseRecovery(full).library)
        val encrypted = BackupEncryption.encrypt(full, "test-library-v4")
        assertEquals(library, BackupEncryption.parseText(encrypted, false, "test-library-v4").library)
        val legacy = Backup.parseStrict(Backup.exportSnapshot(snapshot, compatibleV2 = true))
        assertNull(legacy.library)
        assertEquals(original.logs, legacy.logs)
        assertEquals(original.tasks, legacy.tasks)
        assertEquals(LibraryBackup.V3, parse(fixture("v3")).sourceVersion)
    }

    @Test fun bothImportModesRejectBrokenReferencesAndMalformedArchiveValues() {
        val mutations = listOf<(JSONObject) -> Unit>(
            { it.getJSONObject("preferences").put("retentionDays", "30") },
            { it.getJSONObject("personalLibrary").put("summaryEnabled", 1) },
            { it.getJSONObject("automaticTags").put("log:missing", JSONArray("[\"missing\"]")) },
            { it.getJSONObject("personalLibrary").getJSONArray("tags").getJSONObject(0).put("name", " 带空格") },
            { it.getJSONArray("trash").getJSONObject(0).put("unknown", true) },
            { it.getJSONArray("trash").getJSONObject(0).put("expiresAt", 0) },
            { it.getJSONArray("trash").getJSONObject(0).put("reminder", JSONObject.NULL) },
            { it.getJSONArray("trash").getJSONObject(0).getJSONObject("log").put("importance", 100) },
            { it.getJSONArray("trash").put(it.getJSONArray("trash").getJSONObject(0)) },
            { it.getJSONArray("trash").getJSONObject(3).getJSONObject("task").put("timeZone", "Asia/Shanghai") },
        )
        for (mutate in mutations) {
            val bad = fixture("v4").also(mutate).toString()
            assertThrows(Backup.BackupFormatException::class.java) { Backup.parseStrict(bad) }
            assertThrows(Backup.BackupFormatException::class.java) { Backup.parseRecovery(bad) }
        }
    }

    @Test fun mergeRemapsFilterAndTagOriginsAndKeepsArchivedConflictLocal() {
        val root = fixture("v4")
        val original = requireNotNull(parse(root).library)
        val recordKey = original.links.keys.single()
        val id = original.tags.keys.single()
        val alias = "00000000-0000-4000-8000-000000000001"
        val filterID = "00000000-0000-4000-8000-000000000002"
        val personal = root.getJSONObject("personalLibrary")
        personal.getJSONArray("tags").getJSONObject(0).put("id", alias)
        personal.getJSONObject("links").put(recordKey, JSONArray(listOf(alias)))
        val filter = JSONObject().put("id", filterID).put("name", "阅读").put("kinds", JSONArray())
            .put("query", "").put("tagIDs", JSONArray(listOf(alias))).put("matchAll", false)
            .put("colors", JSONArray()).put("favoritesOnly", false).put("startDay", "").put("endDay", "")
            .put("taskStatus", "all").put("oldestFirst", true)
        personal.getJSONArray("filters").put(filter)
        root.getJSONObject("automaticTags").put(recordKey, JSONArray(listOf(alias)))
        root.getJSONArray("trash").getJSONObject(0).getJSONObject("log").put("content", "Different archive")
        val incoming = requireNotNull(parse(root).library)
        val merged = original.copy(automaticTags = emptyMap()).merge(incoming)
        assertEquals(mapOf(id to "阅读"), merged.tags)
        assertEquals(listOf(id), merged.links.getValue(recordKey))
        assertTrue(merged.automaticTags.isEmpty())
        assertEquals(id, JSONObject(merged.filters.getValue(filterID)).getJSONArray("tagIDs").getString(0))
        assertTrue(merged.settings.remindersNeedConfirmation)
        assertEquals(original.trash, merged.trash)
        assertEquals(merged, merged.merge(incoming))

        val old = parse(fixture("v3")).library!!
        assertEquals(original.preferences, original.merge(old).preferences)
        assertEquals(original.trash, original.merge(old).trash)
        assertEquals(LibraryPreferences(), old.imported().preferences)
        assertTrue(old.imported().trash.isEmpty())
    }

    @Test fun ambiguousTagRemapIsRejectedBeforeTwoDistinctTagsCanCollapse() {
        val localID = "00000000-0000-4000-8000-000000000001"
        val otherID = "00000000-0000-4000-8000-000000000002"
        val original = LibraryMetadata(tags = mapOf(localID to "Reading"))
        val incoming = LibraryMetadata(tags = linkedMapOf(otherID to "Reading", localID to "Journal"))
        assertThrows(Backup.BackupFormatException::class.java) { original.merge(incoming) }
        val reversed = incoming.copy(tags = incoming.tags.toList().reversed().toMap())
        assertThrows(Backup.BackupFormatException::class.java) { original.merge(reversed) }
    }

    @Test fun expiryUsesAppleEpochAndFractionalSeconds() {
        val root = fixture("v4")
        val archive = root.getJSONArray("trash").getJSONObject(0)
        archive.put("deletedAt", 1.0).put("expiresAt", 2.25)
        assertFalse(parse(root).library!!.trash.containsKey(archive.getString("id")))
    }
}
