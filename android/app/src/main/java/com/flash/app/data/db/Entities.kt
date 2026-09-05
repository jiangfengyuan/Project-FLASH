// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package com.flash.app.data.db

import androidx.room.Entity
import androidx.room.ForeignKey
import androidx.room.Index
import androidx.room.PrimaryKey
import com.flash.app.data.model.Category
import com.flash.app.data.model.ColorTag
import com.flash.app.data.model.EmotionLevel
import com.flash.app.data.model.EmotionRecord
import com.flash.app.data.model.LogItem
import com.flash.app.data.model.SubEmotion
import com.flash.app.data.model.TaskDueKind
import com.flash.app.data.model.TaskItem

/**
 * 表结构/列名与 Capacitor 端 SQLite schema 完全一致（见 sqliteAdapter.ts），
 * 为将来的数据迁移/互通保留可能。
 */
@Entity(
    tableName = "logs",
    indices = [
        Index(value = ["createdAt"]),
        Index(value = ["recordDate"]),
        Index(value = ["category", "createdAt"]),
    ],
)
data class LogEntity(
    @PrimaryKey val id: String,
    val content: String,
    val colorTag: String,
    val category: String,
    val importance: Int,
    val createdAt: String,
    val recordDate: String,
)

/**
 * Idea Reminder 的 Android 本地阅读状态。
 * 这是界面状态而非用户内容，刻意不写入跨平台 flash-backup-v1。
 */
@Entity(
    tableName = "idea_view_state",
    foreignKeys = [
        ForeignKey(
            entity = LogEntity::class,
            parentColumns = ["id"],
            childColumns = ["logId"],
            onDelete = ForeignKey.CASCADE,
        ),
    ],
)
data class IdeaViewStateEntity(
    @PrimaryKey val logId: String,
    val viewedAt: String,
)

@Entity(
    tableName = "emotions",
    indices = [
        Index(value = ["createdAt"]),
        Index(value = ["recordDate"]),
    ],
)
data class EmotionEntity(
    @PrimaryKey val id: String,
    val level: Int,
    val subEmotion: String?,
    val status: String?,
    val note: String?,
    val recordDate: String,
    val createdAt: String,
)

@Entity(
    tableName = "tasks",
    indices = [
        Index(value = ["updatedAt"]),
        Index(value = ["dueDate"]),
        Index(value = ["dueAt"]),
    ],
)
data class TaskEntity(
    @PrimaryKey val id: String,
    val title: String,
    val notes: String?,
    val colorTag: String,
    val importance: Int,
    val dueKind: String,
    val dueDate: String?,
    val dueAt: String?,
    val timeZone: String?,
    val reminderAt: String?,
    val completedAt: String?,
    val createdAt: String,
    val updatedAt: String,
)

fun LogEntity.toModel() = LogItem(
    id = id,
    content = content,
    colorTag = ColorTag.fromStorage(colorTag),
    category = Category.fromStorage(category),
    importance = importance,
    createdAt = createdAt,
    recordDate = recordDate,
)

fun LogItem.toEntity() = LogEntity(
    id = id,
    content = content,
    colorTag = colorTag.storageKey,
    category = category.storageKey,
    importance = importance,
    createdAt = createdAt,
    recordDate = recordDate,
)

fun EmotionEntity.toModel() = EmotionRecord(
    id = id,
    level = EmotionLevel.fromValue(level),
    subEmotion = subEmotion?.let(SubEmotion::fromStorage),
    status = status,
    note = note,
    recordDate = recordDate,
    createdAt = createdAt,
)

fun EmotionRecord.toEntity() = EmotionEntity(
    id = id,
    level = level.value,
    subEmotion = subEmotion?.storageKey,
    status = status,
    note = note,
    recordDate = recordDate,
    createdAt = createdAt,
)

fun TaskEntity.toModel() = TaskItem(
    id = id,
    title = title,
    notes = notes,
    colorTag = ColorTag.fromStorage(colorTag),
    importance = importance,
    dueKind = TaskDueKind.fromStorage(dueKind) ?: TaskDueKind.ALL_DAY,
    dueDate = dueDate,
    dueAt = dueAt,
    timeZone = timeZone,
    reminderAt = reminderAt,
    completedAt = completedAt,
    createdAt = createdAt,
    updatedAt = updatedAt,
)

fun TaskItem.toEntity() = TaskEntity(
    id = id,
    title = title,
    notes = notes,
    colorTag = colorTag.storageKey,
    importance = importance,
    dueKind = dueKind.storageKey,
    dueDate = dueDate,
    dueAt = dueAt,
    timeZone = timeZone,
    reminderAt = reminderAt,
    completedAt = completedAt,
    createdAt = createdAt,
    updatedAt = updatedAt,
)
