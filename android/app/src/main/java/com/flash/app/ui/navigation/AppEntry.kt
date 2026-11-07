// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package com.flash.app.ui.navigation

import android.content.Intent
import com.flash.app.data.model.Category

/**
 * 外部入口。深链与快捷方式只打开界面，不携带正文、不写数据；
 * 系统分享的文字进入快速记录面板，由用户确认后才保存。
 */
sealed interface AppEntry {
    data class Capture(val category: Category) : AppEntry
    data object Today : AppEntry
    data object Ideas : AppEntry
    data class Shared(val text: String) : AppEntry
    data class OpenRecord(val id: String) : AppEntry

    companion object {
        const val EXTRA_OPEN_RECORD = "com.flash.app.extra.OPEN_RECORD"

        /** 分享内容的读取上限：足以覆盖正文上限，超长由面板提示，不静默截断到上限以内 */
        private const val MAX_SHARED_CHARS = 200_000

        fun from(intent: Intent?): AppEntry? {
            intent ?: return null
            intent.getStringExtra(EXTRA_OPEN_RECORD)?.let { return OpenRecord(it) }
            return when (intent.action) {
                Intent.ACTION_SEND -> sharedText(intent)?.let(::Shared)
                Intent.ACTION_VIEW -> parse(intent.dataString)
                else -> null
            }
        }

        private fun sharedText(intent: Intent): String? {
            if (intent.type?.startsWith("text/") != true) return null
            val subject = intent.getStringExtra(Intent.EXTRA_SUBJECT)?.trim()
            val body = intent.getCharSequenceExtra(Intent.EXTRA_TEXT)?.toString()?.trim()
            val text = listOfNotNull(subject?.ifEmpty { null }, body?.ifEmpty { null })
                .distinct()
                .joinToString("\n")
            return text.take(MAX_SHARED_CHARS).ifEmpty { null }
        }

        /** flash://capture[?category=idea|log]、flash://today、flash://ideas；其余一律忽略 */
        fun parse(uri: String?): AppEntry? {
            uri ?: return null
            val parts = uri.split("?", limit = 2)
            return when (parts[0].removeSuffix("/")) {
                "flash://capture" -> {
                    val query = parts.getOrNull(1).orEmpty()
                    Capture(if (query == "category=log") Category.LOG else Category.IDEA)
                }
                "flash://today" -> Today
                "flash://ideas" -> Ideas
                else -> null
            }
        }
    }
}
