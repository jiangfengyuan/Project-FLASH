// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package com.flash.app.domain

import com.flash.app.data.model.EmotionRecord
import com.flash.app.data.model.LogItem
import com.flash.app.data.model.TaskItem
import com.flash.app.data.model.emoji
import com.flash.app.i18n.tr

enum class SearchMatchKind {
    LOG, EMOTION, TASK;

    val displayName: String
        get() = when (this) {
            LOG -> tr("记录")
            EMOTION -> tr("情绪")
            TASK -> tr("任务")
        }
}

data class SearchMatch(val id: String, val kind: SearchMatchKind, val title: String, val createdAt: String)

/**
 * 全局搜索，口径与 FlashCore/Domain/GlobalSearch.swift 一致：大小写不敏感；日志匹配正文与
 * 标签名（当前语言），情绪匹配备注或情绪名，任务匹配标题与备注；按创建时间倒序取前 limit 条。
 */
object GlobalSearch {
    fun search(
        logs: List<LogItem>,
        emotions: List<EmotionRecord>,
        tasks: List<TaskItem>,
        query: String,
        limit: Int = 20,
    ): List<SearchMatch> {
        val needle = query.trim()
        if (needle.isEmpty()) return emptyList()
        val logMatches = logs
            .filter { it.content.contains(needle, true) || it.colorTag.displayName.contains(needle, true) }
            .map { SearchMatch(it.id, SearchMatchKind.LOG, it.content, it.createdAt) }
        val emotionMatches = emotions.mapNotNull { emotion ->
            val title = "${emotion.level.emoji} ${emotion.note ?: emotion.level.displayName}"
            if (title.contains(needle, true)) SearchMatch(emotion.id, SearchMatchKind.EMOTION, title, emotion.createdAt) else null
        }
        val taskMatches = tasks
            .filter { it.title.contains(needle, true) || it.notes?.contains(needle, true) == true }
            .map { SearchMatch(it.id, SearchMatchKind.TASK, it.title, it.createdAt) }
        return (logMatches + emotionMatches + taskMatches)
            .sortedByDescending { it.createdAt }
            .take(limit)
    }
}
