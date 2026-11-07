// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package com.flash.app.ui.navigation

import android.net.Uri
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.AutoGraph
import androidx.compose.material.icons.filled.EditNote
import androidx.compose.material.icons.filled.Home
import androidx.compose.material.icons.filled.Mood
import androidx.compose.material.icons.filled.Settings
import androidx.compose.ui.graphics.vector.ImageVector
import com.flash.app.i18n.tr

/**
 * 路由：5 Tab（此刻 / 记录 / 情绪 / 回顾 / 设置，对齐 iOS）
 * + Welcome（首启）+ 日历 / 日志流 / Memory / 搜索 / 记录编辑 / 设置子页。
 */
object Routes {
    const val WELCOME = "welcome"
    const val HOME = "home"
    const val EXPLORE = "explore"
    const val EMOTION = "emotion"
    const val STATS = "stats"
    const val PROFILE = "profile"
    const val CALENDAR = "calendar"
    const val LOG_FLOW = "logFlow"
    const val MEMORY = "memory"
    const val SEARCH = "search"
    const val SETTINGS_IDEA_REMINDER = "settings/ideaReminder"
    const val SETTINGS_BACKUP = "settings/backup"
    const val SETTINGS_TRANSFER = "settings/transfer"
    const val RECORD_DETAIL = "recordDetail"
    const val RECORD_DETAIL_PATTERN = "$RECORD_DETAIL/{recordId}"

    fun recordDetail(recordId: String): String = "$RECORD_DETAIL/${Uri.encode(recordId)}"
}

data class TabDest(val route: String, private val sourceLabel: String, val icon: ImageVector) {
    val label: String get() = tr(sourceLabel)
}

val TABS = listOf(
    TabDest(Routes.HOME, "此刻", Icons.Filled.Home),
    TabDest(Routes.EXPLORE, "记录", Icons.Filled.EditNote),
    TabDest(Routes.EMOTION, "情绪", Icons.Filled.Mood),
    TabDest(Routes.STATS, "回顾", Icons.Filled.AutoGraph),
    TabDest(Routes.PROFILE, "设置", Icons.Filled.Settings),
)
