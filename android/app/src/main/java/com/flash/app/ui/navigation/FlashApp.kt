// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package com.flash.app.ui.navigation

import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.NavigationBarItemDefaults
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.navigation.NavGraph.Companion.findStartDestination
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.rememberNavController
import com.flash.app.FlashApplication
import com.flash.app.data.UiStyle
import com.flash.app.ui.calendar.CalendarScreen
import com.flash.app.ui.emotion.EmotionScreen
import com.flash.app.ui.explore.ExploreScreen
import com.flash.app.ui.home.HomeScreen
import com.flash.app.ui.logflow.LogFlowScreen
import com.flash.app.ui.settings.SettingsScreen
import com.flash.app.ui.stats.StatsScreen
import com.flash.app.ui.theme.LocalUiStyle
import com.flash.app.ui.theme.glass.GlassBackground
import com.flash.app.ui.theme.glass.LocalHazeState
import com.flash.app.ui.theme.glass.glass
import com.flash.app.ui.welcome.WelcomeScreen
import dev.chrisbanes.haze.HazeState

@Composable
fun FlashApp(darkTheme: Boolean, uiStyle: UiStyle) {
    val app = LocalContext.current.applicationContext as FlashApplication
    val welcomed by app.settings.welcomed.collectAsStateWithLifecycle()

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
                                    // 选中态统一用品牌紫（primary 系），不再用默认的橙系 secondaryContainer
                                    colors = NavigationBarItemDefaults.colors(
                                        selectedIconColor = MaterialTheme.colorScheme.onPrimaryContainer,
                                        selectedTextColor = MaterialTheme.colorScheme.primary,
                                        indicatorColor = MaterialTheme.colorScheme.primaryContainer,
                                        unselectedIconColor = MaterialTheme.colorScheme.onSurfaceVariant,
                                        unselectedTextColor = MaterialTheme.colorScheme.onSurfaceVariant,
                                    ),
                                )
                            }
                        }
                    }
                },
            ) { innerPadding ->
                NavHost(
                    navController = navController,
                    startDestination = if (welcomed) Routes.HOME else Routes.WELCOME,
                    modifier = Modifier.padding(innerPadding),
                    // 全局转场：交叉淡入淡出，保持克制
                    enterTransition = { fadeIn(animationSpec = tween(280)) },
                    exitTransition = { fadeOut(animationSpec = tween(280)) },
                    popEnterTransition = { fadeIn(animationSpec = tween(280)) },
                    popExitTransition = { fadeOut(animationSpec = tween(280)) },
                ) {
                    composable(Routes.WELCOME) {
                        WelcomeScreen(onStart = {
                            app.settings.setWelcomed()
                            navController.navigate(Routes.HOME) {
                                popUpTo(Routes.WELCOME) { inclusive = true }
                            }
                        })
                    }
                    composable(Routes.HOME) {
                        HomeScreen(
                            onOpenExplore = { navController.navigate(Routes.EXPLORE) },
                            onOpenCalendar = { navController.navigate(Routes.CALENDAR) },
                            onOpenEmotion = { navController.navigate(Routes.EMOTION) },
                        )
                    }
                    composable(Routes.EXPLORE) {
                        ExploreScreen(
                            onOpenLogFlow = { navController.navigate(Routes.LOG_FLOW) },
                            onOpenCalendar = { navController.navigate(Routes.CALENDAR) },
                        )
                    }
                    composable(Routes.STATS) {
                        StatsScreen()
                    }
                    composable(Routes.PROFILE) {
                        SettingsScreen()
                    }
                    composable(Routes.EMOTION) {
                        EmotionScreen(onBack = { navController.popBackStack() })
                    }
                    composable(Routes.CALENDAR) {
                        CalendarScreen(onOpenSettings = { navController.navigate(Routes.PROFILE) })
                    }
                    composable(Routes.LOG_FLOW) {
                        LogFlowScreen(onBack = { navController.popBackStack() })
                    }
                }
            }
        }
    }
}
