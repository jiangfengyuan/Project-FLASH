package com.flash.app.data.db

import androidx.room.Dao
import androidx.room.Query
import androidx.room.Upsert
import kotlinx.coroutines.flow.Flow

@Dao
interface LogDao {
    @Query("SELECT * FROM logs ORDER BY createdAt DESC")
    fun observeAll(): Flow<List<LogEntity>>

    @Upsert
    suspend fun upsert(log: LogEntity)

    @Upsert
    suspend fun upsertAll(logs: List<LogEntity>)

    @Query("DELETE FROM logs WHERE id = :id")
    suspend fun deleteById(id: String)

    @Query("DELETE FROM logs")
    suspend fun clearAll()
}

@Dao
interface EmotionDao {
    @Query("SELECT * FROM emotions ORDER BY createdAt DESC")
    fun observeAll(): Flow<List<EmotionEntity>>

    @Upsert
    suspend fun upsert(emotion: EmotionEntity)

    @Upsert
    suspend fun upsertAll(emotions: List<EmotionEntity>)

    @Query("DELETE FROM emotions WHERE id = :id")
    suspend fun deleteById(id: String)

    @Query("DELETE FROM emotions")
    suspend fun clearAll()
}
