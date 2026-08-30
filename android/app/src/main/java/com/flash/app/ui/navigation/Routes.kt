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
import androidx.compose.material.icons.filled.Search
import androidx.compose.ui.graphics.vector.ImageVector

/**
 * 路由：新 IA（PRD 05 / 效果图）— 4 Tab（首页/探索/统计/我的）
 * + Welcome（首启）+ Emotion/Calendar/LogFlow 子页面。
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
    TabDest(Routes.HOME, "首页", Icons.Filled.Home),
    TabDest(Routes.EXPLORE, "探索", Icons.Filled.Search),
    TabDest(Routes.STATS, "统计", Icons.Filled.BarChart),
    TabDest(Routes.PROFILE, "我的", Icons.Filled.Person),
)
