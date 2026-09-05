// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package com.flash.app.data.model

import java.time.Instant
import java.time.ZoneId

/**
 * 与 Web 版 src/lib/constants.ts 对齐的核心数据模型。
 * storageKey 与 SQLite/Capacitor 端存储值保持一致，保证数据互通。
 */

enum class ColorTag(val storageKey: String, val displayName: String, val colorHex: String) {
    URGENT("urgent", "紧急", "#FF6B6B"),
    INSPIRATION("inspiration", "灵感", "#FFD93D"),
    DAILY("daily", "日常", "#4D96FF"),
    MEMO("memo", "备忘", "#6BCB77"),
    EMOTION("emotion", "情绪", "#9B59B6"),
    IDEA("idea", "想法", "#FF9F43");

    companion object {
        fun fromStorage(key: String): ColorTag =
            entries.firstOrNull { it.storageKey == key } ?: DAILY
    }
}

enum class Category(val storageKey: String) {
    LOG("log"),
    IDEA("idea");

    companion object {
        fun fromStorage(key: String): Category =
            entries.firstOrNull { it.storageKey == key } ?: LOG
    }
}

enum class EmotionLevel(val value: Int, val displayName: String, val colorHex: String) {
    VERY_UNHAPPY(-3, "非常不开心", "#800080"),
    UNHAPPY(-2, "很不开心", "#DDA0DD"),
    SLIGHTLY_UNHAPPY(-1, "不开心", "#B0C4DE"),
    NEUTRAL(0, "中性", "#B0E0E6"),
    SLIGHTLY_HAPPY(1, "开心", "#90EE90"),
    HAPPY(2, "很开心", "#F0D878"),
    VERY_HAPPY(3, "非常开心", "#FFB347");

    val isNegative: Boolean get() = value < 0

    companion object {
        fun fromValue(value: Int): EmotionLevel =
            entries.firstOrNull { it.value == value } ?: NEUTRAL
    }
}

enum class SubEmotion(val storageKey: String, val displayName: String, val colorHex: String) {
    SAD("sad", "伤心", "#A78BFA"),
    ANGRY("angry", "生气", "#F87171"),
    UNCOMFORTABLE("uncomfortable", "难受", "#FB923C");

    companion object {
        fun fromStorage(key: String): SubEmotion? =
            entries.firstOrNull { it.storageKey == key }
    }
}

data class LogItem(
    val id: String,
    val content: String,
    val colorTag: ColorTag,
    val category: Category,
    val importance: Int,
    val createdAt: String,
    val recordDate: String,
)

data class EmotionRecord(
    val id: String,
    val level: EmotionLevel,
    val subEmotion: SubEmotion?,
    val status: String?,
    val note: String?,
    val recordDate: String,
    val createdAt: String,
)

enum class TaskDueKind(val storageKey: String) {
    ALL_DAY("allDay"),
    DATE_TIME("dateTime");

    companion object {
        fun fromStorage(key: String): TaskDueKind? = entries.firstOrNull { it.storageKey == key }
    }
}

data class TaskItem(
    val id: String,
    val title: String,
    val notes: String?,
    val colorTag: ColorTag,
    val importance: Int,
    val dueKind: TaskDueKind,
    val dueDate: String?,
    val dueAt: String?,
    val timeZone: String?,
    val reminderAt: String?,
    val completedAt: String?,
    val createdAt: String,
    val updatedAt: String,
) {
    val calendarDate: String
        get() = when (dueKind) {
            TaskDueKind.ALL_DAY -> requireNotNull(dueDate)
            TaskDueKind.DATE_TIME -> Instant.parse(requireNotNull(dueAt))
                .atZone(ZoneId.of(requireNotNull(timeZone)))
                .toLocalDate()
                .toString()
        }

    val isCompleted: Boolean get() = completedAt != null
}

/** 对应 PRD 的 emoji 情绪模型：😍😊🙂😐😔😣😡（level 3→-3） */
val EmotionLevel.emoji: String
    get() = when (this) {
        EmotionLevel.VERY_HAPPY -> "😍"
        EmotionLevel.HAPPY -> "😊"
        EmotionLevel.SLIGHTLY_HAPPY -> "🙂"
        EmotionLevel.NEUTRAL -> "😐"
        EmotionLevel.SLIGHTLY_UNHAPPY -> "😔"
        EmotionLevel.UNHAPPY -> "😣"
        EmotionLevel.VERY_UNHAPPY -> "😡"
    }

/** 与 Web 版 getImportanceFromContent 对齐：从内容中的 !! 标记推断重要度 */
fun importanceFromContent(content: String): Int = when {
    content.contains("!!!!") -> 4
    content.contains("!!!") -> 3
    content.contains("!!") -> 2
    else -> 0
}
