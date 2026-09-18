// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package com.flash.app.ui.navigation

import android.net.Uri
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.BarChart
import androidx.compose.material.icons.filled.Home
import androidx.compose.material.icons.filled.Person
import androidx.compose.material.icons.outlined.EditNote
import androidx.compose.ui.graphics.vector.ImageVector

/**
 * 路由：新 IA（PRD 05 / 效果图）— 4 Tab（此刻/记录/回顾/设置）
 * + Welcome（首启）+ Emotion/Calendar/LogFlow 子页面。
 * route 字符串保持不变，仅用户可见显示名称按阶段一导航映射调整。
 */
object Routes {
    const val WELCOME = "welcome"
    const val HOME = "home"
    const val EXPLORE = "explore"
    const val STATS = "stats"
    const val PROFILE = "profile"
    const val EMOTION = "emotion"
    const val CALENDAR = "calendar"
    const val LOG_FLOW = "logFlow"
    const val RECORD_DETAIL = "recordDetail"
    const val RECORD_DETAIL_PATTERN = "$RECORD_DETAIL/{recordId}"

    fun recordDetail(recordId: String): String = "$RECORD_DETAIL/${Uri.encode(recordId)}"
}

data class TabDest(val route: String, val label: String, val icon: ImageVector)

val TABS = listOf(
    TabDest(Routes.HOME, "此刻", Icons.Filled.Home),
    // 一级页图标：记录/文档类线性图标，与搜索语义脱钩
    TabDest(Routes.EXPLORE, "记录", Icons.Outlined.EditNote),
    TabDest(Routes.STATS, "回顾", Icons.Filled.BarChart),
    TabDest(Routes.PROFILE, "设置", Icons.Filled.Person),
)
