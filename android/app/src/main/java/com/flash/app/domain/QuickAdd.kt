// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package com.flash.app.domain

import com.flash.app.data.FlashRepository
import com.flash.app.data.model.Category
import com.flash.app.data.model.ColorTag
import com.flash.app.data.model.importanceFromContent

/**
 * 快速记录（Quick Add）的唯一口径：此刻页快速捕捉卡与全局 FAB 轻输入面板共用。
 * 空白内容返回 null（不写入）；灵感按内容中的 !! 标记推断重要度，日志重要度恒为 0。
 */
data class QuickAddDraft(
    val content: String,
    val colorTag: ColorTag,
    val category: Category,
    val importance: Int,
)

fun quickAddDraft(content: String, category: Category): QuickAddDraft? {
    val trimmed = content.trim()
    if (trimmed.isEmpty()) return null
    return when (category) {
        Category.LOG -> QuickAddDraft(trimmed, ColorTag.DAILY, Category.LOG, importance = 0)
        Category.IDEA -> QuickAddDraft(
            trimmed,
            ColorTag.IDEA,
            Category.IDEA,
            importance = importanceFromContent(trimmed),
        )
    }
}

/** 空白内容静默忽略；其余写库失败原样抛出，由调用方提示。 */
suspend fun FlashRepository.quickAdd(content: String, category: Category) {
    val draft = quickAddDraft(content, category) ?: return
    addLog(draft.content, draft.colorTag, draft.category, draft.importance)
}
