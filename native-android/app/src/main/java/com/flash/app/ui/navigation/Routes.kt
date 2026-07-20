package com.flash.app.ui.navigation

import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.List
import androidx.compose.material.icons.filled.DateRange
import androidx.compose.material.icons.filled.Face
import androidx.compose.material.icons.filled.Star
import androidx.compose.ui.graphics.vector.ImageVector

/** 路由与 Web 版 navigationStore 对齐：4 个 Tab + 2 个子页面 */
object Routes {
    const val LOG = "log"
    const val IDEA = "idea"
    const val CALENDAR = "calendar"
    const val EMOTION = "emotion"
    const val LOG_FLOW = "logFlow"
    const val SETTINGS = "settings"
}

data class TabDest(val route: String, val label: String, val icon: ImageVector)

val TABS = listOf(
    TabDest(Routes.LOG, "Log", Icons.AutoMirrored.Filled.List),
    TabDest(Routes.IDEA, "Idea", Icons.Filled.Star),
    TabDest(Routes.CALENDAR, "日历", Icons.Filled.DateRange),
    TabDest(Routes.EMOTION, "情绪", Icons.Filled.Face),
)
