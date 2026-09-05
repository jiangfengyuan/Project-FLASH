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

    @Query("SELECT * FROM logs ORDER BY createdAt DESC")
    suspend fun getAll(): List<LogEntity>

    /**
     * 记录流分页查询：过滤条件下推 SQL，一次只把前 [limit] 条读进内存，
     * 滑到底部由调用方增大 limit 加载更多（Room 会在数据变化时自动重查）。
     * [query] 需先用 ESCAPE '\' 转义 %/_/\\；[sort] 取值 newest/oldest/tag。
     */
    @Query(
        """
        SELECT * FROM logs
        WHERE category = 'log'
          AND (:query = '' OR LOWER(content) LIKE '%' || :query || '%' ESCAPE '\')
          AND (:tagCount = 0 OR colorTag IN (:tags))
          AND (:startDate IS NULL OR recordDate >= :startDate)
          AND (:endDate IS NULL OR recordDate <= :endDate)
        ORDER BY
          CASE WHEN :sort = 'tag' THEN colorTag END ASC,
          CASE WHEN :sort = 'oldest' THEN createdAt END ASC,
          CASE WHEN :sort <> 'oldest' THEN createdAt END DESC
        LIMIT :limit
        """
    )
    fun observeLogPage(
        query: String,
        tags: Set<String>,
        tagCount: Int,
        startDate: String?,
        endDate: String?,
        sort: String,
        limit: Int,
    ): Flow<List<LogEntity>>

    /** 与 [observeLogPage] 同条件的命中总数，用于"N 条"展示与 hasMore 判断 */
    @Query(
        """
        SELECT COUNT(*) FROM logs
        WHERE category = 'log'
          AND (:query = '' OR LOWER(content) LIKE '%' || :query || '%' ESCAPE '\')
          AND (:tagCount = 0 OR colorTag IN (:tags))
          AND (:startDate IS NULL OR recordDate >= :startDate)
          AND (:endDate IS NULL OR recordDate <= :endDate)
        """
    )
    fun observeLogCount(
        query: String,
        tags: Set<String>,
        tagCount: Int,
        startDate: String?,
        endDate: String?,
    ): Flow<Int>

    /** 删除灵感前记住阅读状态，供撤销删除时恢复（idea_view_state 随 CASCADE 被清） */
    @Query("SELECT EXISTS(SELECT 1 FROM idea_view_state WHERE logId = :id)")
    suspend fun isIdeaViewed(id: String): Boolean

    @Query("SELECT * FROM logs WHERE id = :id LIMIT 1")
    fun observeById(id: String): Flow<LogEntity?>

    @Query(
        """
        SELECT * FROM logs
        WHERE category = 'idea'
          AND NOT EXISTS (
              SELECT 1 FROM idea_view_state WHERE idea_view_state.logId = logs.id
          )
        ORDER BY createdAt DESC
        """
    )
    fun observeUnviewedIdeas(): Flow<List<LogEntity>>

    @Query(
        """
        INSERT OR IGNORE INTO idea_view_state (logId, viewedAt)
        SELECT id, :viewedAt FROM logs WHERE id = :id AND category = 'idea'
        """
    )
    suspend fun markIdeaViewed(id: String, viewedAt: String)

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

    @Query("SELECT * FROM emotions ORDER BY createdAt DESC")
    suspend fun getAll(): List<EmotionEntity>

    /** 情绪历史分页：一次只读前 [limit] 条，滑到底部由调用方增大 limit */
    @Query("SELECT * FROM emotions ORDER BY createdAt DESC LIMIT :limit")
    fun observePage(limit: Int): Flow<List<EmotionEntity>>

    /** 统计只需近期窗口（本周/近 30 天），按 recordDate 下推避免全表进内存 */
    @Query("SELECT * FROM emotions WHERE recordDate >= :startDate ORDER BY createdAt DESC")
    fun observeSince(startDate: String): Flow<List<EmotionEntity>>

    @Upsert
    suspend fun upsert(emotion: EmotionEntity)

    @Upsert
    suspend fun upsertAll(emotions: List<EmotionEntity>)

    @Query("DELETE FROM emotions WHERE id = :id")
    suspend fun deleteById(id: String)

    @Query("DELETE FROM emotions")
    suspend fun clearAll()
}

@Dao
interface TaskDao {
    @Query("SELECT * FROM tasks ORDER BY completedAt IS NOT NULL, updatedAt DESC")
    fun observeAll(): Flow<List<TaskEntity>>

    @Query("SELECT * FROM tasks")
    suspend fun getAll(): List<TaskEntity>

    @Upsert
    suspend fun upsert(task: TaskEntity)

    @Upsert
    suspend fun upsertAll(tasks: List<TaskEntity>)

    @Query("DELETE FROM tasks WHERE id = :id")
    suspend fun deleteById(id: String)

    @Query("DELETE FROM tasks")
    suspend fun clearAll()
}
