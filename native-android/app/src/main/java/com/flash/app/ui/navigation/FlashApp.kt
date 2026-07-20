package com.flash.app.ui.navigation

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.navigation.NavGraph.Companion.findStartDestination
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.rememberNavController
import com.flash.app.data.UiStyle
import com.flash.app.ui.calendar.CalendarScreen
import com.flash.app.ui.emotion.EmotionScreen
import com.flash.app.ui.idea.IdeaFlowScreen
import com.flash.app.ui.logflow.LogFlowScreen
import com.flash.app.ui.logstream.LogStreamScreen
import com.flash.app.ui.settings.SettingsScreen
import com.flash.app.ui.theme.LocalUiStyle
import com.flash.app.ui.theme.glass.GlassBackground
import com.flash.app.ui.theme.glass.LocalHazeState
import com.flash.app.ui.theme.glass.glass
import dev.chrisbanes.haze.HazeState

@Composable
fun FlashApp(darkTheme: Boolean, uiStyle: UiStyle) {
    val navController = rememberNavController()
    val backStackEntry by navController.currentBackStackEntryAsState()
    val currentRoute = backStackEntry?.destination?.route
    val showBottomBar = currentRoute in TABS.map { it.route }
    val hazeState = remember { HazeState() }
    val isGlass = uiStyle == UiStyle.GLASS

    CompositionLocalProvider(LocalHazeState provides hazeState, LocalUiStyle provides uiStyle) {
        Box(Modifier.fillMaxSize()) {
            // 玻璃风格：渐变天空作为模糊源；MD3 风格：纯色背景即可
            if (isGlass) {
                GlassBackground(darkTheme = darkTheme, hazeState = hazeState)
            }

            Scaffold(
                containerColor = if (isGlass) Color.Transparent else MaterialTheme.colorScheme.background,
                bottomBar = {
                    if (showBottomBar) {
                        NavigationBar(
                            containerColor = if (isGlass) {
                                Color.Transparent
                            } else {
                                MaterialTheme.colorScheme.surfaceContainer
                            },
                            tonalElevation = if (isGlass) 0.dp else 3.dp,
                            modifier = if (isGlass) {
                                Modifier.glass(
                                    shape = RoundedCornerShape(topStart = 24.dp, topEnd = 24.dp),
                                    strong = true,
                                )
                            } else {
                                Modifier
                            },
                        ) {
                            TABS.forEach { tab ->
                                NavigationBarItem(
                                    selected = currentRoute == tab.route,
                                    onClick = {
                                        navController.navigate(tab.route) {
                                            popUpTo(navController.graph.findStartDestination().id) {
                                                saveState = true
                                            }
                                            launchSingleTop = true
                                            restoreState = true
                                        }
                                    },
                                    icon = { Icon(tab.icon, contentDescription = tab.label) },
                                    label = { Text(tab.label) },
                                )
                            }
                        }
                    }
                },
            ) { innerPadding ->
                NavHost(
                    navController = navController,
                    startDestination = Routes.LOG,
                    modifier = Modifier.padding(innerPadding),
                ) {
                    composable(Routes.LOG) {
                        LogStreamScreen(
                            onOpenLogFlow = { navController.navigate(Routes.LOG_FLOW) },
                            onOpenSettings = { navController.navigate(Routes.SETTINGS) },
                        )
                    }
                    composable(Routes.IDEA) {
                        IdeaFlowScreen(onOpenSettings = { navController.navigate(Routes.SETTINGS) })
                    }
                    composable(Routes.CALENDAR) {
                        CalendarScreen(onOpenSettings = { navController.navigate(Routes.SETTINGS) })
                    }
                    composable(Routes.EMOTION) {
                        EmotionScreen(onOpenSettings = { navController.navigate(Routes.SETTINGS) })
                    }
                    composable(Routes.LOG_FLOW) {
                        LogFlowScreen(onBack = { navController.popBackStack() })
                    }
                    composable(Routes.SETTINGS) {
                        SettingsScreen(onBack = { navController.popBackStack() })
                    }
                }
            }
        }
    }
}
