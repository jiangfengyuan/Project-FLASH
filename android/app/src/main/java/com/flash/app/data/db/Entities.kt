package com.flash.app.data.db

import androidx.room.Entity
import androidx.room.PrimaryKey
import com.flash.app.data.model.Category
import com.flash.app.data.model.ColorTag
import com.flash.app.data.model.EmotionLevel
import com.flash.app.data.model.EmotionRecord
import com.flash.app.data.model.LogItem
import com.flash.app.data.model.SubEmotion

/**
 * 表结构/列名与 Capacitor 端 SQLite schema 完全一致（见 sqliteAdapter.ts），
 * 为将来的数据迁移/互通保留可能。
 */
@Entity(tableName = "logs")
data class LogEntity(
    @PrimaryKey val id: String,
    val content: String,
    val colorTag: String,
    val category: String,
    val importance: Int,
    val createdAt: String,
    val recordDate: String,
)

@Entity(tableName = "emotions")
data class EmotionEntity(
    @PrimaryKey val id: String,
    val level: Int,
    val subEmotion: String?,
    val status: String?,
    val note: String?,
    val recordDate: String,
    val createdAt: String,
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
