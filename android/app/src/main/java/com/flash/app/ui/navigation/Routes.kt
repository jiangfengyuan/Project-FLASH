package com.flash.app.ui.navigation

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
}

data class TabDest(val route: String, val label: String, val icon: ImageVector)

val TABS = listOf(
    TabDest(Routes.HOME, "首页", Icons.Filled.Home),
    TabDest(Routes.EXPLORE, "探索", Icons.Filled.Search),
    TabDest(Routes.STATS, "统计", Icons.Filled.BarChart),
    TabDest(Routes.PROFILE, "我的", Icons.Filled.Person),
)
