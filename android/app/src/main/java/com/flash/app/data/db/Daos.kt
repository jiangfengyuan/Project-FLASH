// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package com.flash.app.data.db

import androidx.room.Dao
import androidx.room.Query
import androidx.room.Upsert
import kotlinx.coroutines.flow.Flow

@Dao
interface LogDao {
    @Query("SELECT * FROM logs ORDER BY createdAt DESC")
    fun observeAll(): Flow<List<LogEntity>>

    @Query("SELECT * FROM logs WHERE id = :id LIMIT 1")
    fun observeById(id: String): Flow<LogEntity?>

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
