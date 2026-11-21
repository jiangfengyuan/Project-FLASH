package com.flash.app.data.db

import androidx.room.Dao
import androidx.room.Entity
import androidx.room.Query
import androidx.room.Upsert

@Entity(tableName = "library_entries", primaryKeys = ["kind", "entryKey"])
data class LibraryEntry(val kind: String, val entryKey: String, val position: Int, val value: String)

@Dao
interface LibraryDao {
    @Query("SELECT * FROM library_entries ORDER BY kind, position, entryKey")
    suspend fun entries(): List<LibraryEntry>

    @Upsert
    suspend fun put(rows: List<LibraryEntry>)

    @Query("DELETE FROM library_entries")
    suspend fun clear()

    @Query("SELECT * FROM library_entries WHERE (kind IN ('link','automatic') AND entryKey = :key) OR (kind = 'reminder' AND entryKey = :ideaID)")
    suspend fun recordEntries(key: String, ideaID: String?): List<LibraryEntry>

    @Query("DELETE FROM library_entries WHERE (kind IN ('link','automatic') AND entryKey = :key) OR (kind = 'reminder' AND entryKey = :ideaID)")
    suspend fun detach(key: String, ideaID: String?)

    @Query("DELETE FROM library_entries WHERE kind = 'reminder' AND entryKey IN (:ids)")
    suspend fun removeReminders(ids: List<String>)
}
