// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package com.flash.app.ui.navigation

import androidx.activity.compose.BackHandler
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInHorizontally
import androidx.compose.animation.slideOutHorizontally
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.navigationBars
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.navigation.NavGraph.Companion.findStartDestination
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.rememberNavController
import com.flash.app.FlashApplication
import com.flash.app.data.UiStyle
import com.flash.app.data.model.Category
import com.flash.app.domain.quickAdd
import com.flash.app.domain.shouldShowIdeaReminder
import com.flash.app.ui.calendar.CalendarScreen
import com.flash.app.ui.calendar.TaskEditorDialog
import com.flash.app.ui.components.QuickCreateFab
import com.flash.app.ui.components.QuickInputDialog
import com.flash.app.ui.detail.RecordDetailScreen
import com.flash.app.ui.emotion.EmotionScreen
import com.flash.app.ui.explore.ExploreScreen
import com.flash.app.ui.home.HomeScreen
import com.flash.app.ui.logflow.LogFlowScreen
import com.flash.app.ui.settings.SettingsScreen
import com.flash.app.ui.stats.StatsScreen
import com.flash.app.ui.theme.FlashTokens
import com.flash.app.ui.theme.LocalUiStyle
import com.flash.app.ui.theme.glass.GlassBackground
import com.flash.app.ui.theme.glass.LocalHazeState
import com.flash.app.ui.welcome.WelcomeScreen
import dev.chrisbanes.haze.HazeState
import kotlinx.coroutines.launch

@Composable
fun FlashApp(darkTheme: Boolean, uiStyle: UiStyle) {
    val app = LocalContext.current.applicationContext as FlashApplication
    val welcomed by app.settings.welcomed.collectAsStateWithLifecycle()
    val unviewedIdeas by app.repository.unviewedIdeas.collectAsStateWithLifecycle(emptyList())
    val showIdeaReminder = shouldShowIdeaReminder(unviewedIdeas.size)

    val navController = rememberNavController()
    val backStackEntry by navController.currentBackStackEntryAsState()
    val currentRoute = backStackEntry?.destination?.route
    val showBottomBar = currentRoute in TABS.map { it.route }
    val hazeState = remember { HazeState() }
    val isGlass = uiStyle == UiStyle.GLASS
    val snackbar = remember { SnackbarHostState() }
    val scope = rememberCoroutineScope()

    var fabExpanded by remember { mutableStateOf(false) }
    var quickCreateKey by rememberSaveable { mutableStateOf<String?>(null) }
    val quickCreate = quickCreateKey?.let { Category.valueOf(it) }
    // FAB「任务」直达任务编辑器（方案 §4.5），不再绕道日历页
    var taskEditorOpen by rememberSaveable { mutableStateOf(false) }

    // Dock 悬浮于内容之上：为一级页面预留底部空间，内容不被 Dock 或系统手势区遮挡
    val density = LocalDensity.current
    val dockReserve = WindowInsets.navigationBars.getBottom(density).let {
        with(density) { it.toDp() }
    } + FlashTokens.Dock.BottomMargin + FlashTokens.Dock.Height

    // 离开一级页面（Dock 隐藏）时收起展开菜单
    LaunchedEffect(showBottomBar) {
        if (!showBottomBar) fabExpanded = false
    }

    CompositionLocalProvider(LocalHazeState provides hazeState, LocalUiStyle provides uiStyle) {
        Box(Modifier.fillMaxSize()) {
            // 玻璃风格：渐变天空作为模糊源；MD3 风格：纯色背景即可
            if (isGlass) {
                GlassBackground(darkTheme = darkTheme, hazeState = hazeState)
            }

            Scaffold(
                containerColor = if (isGlass) Color.Transparent else MaterialTheme.colorScheme.background,
                snackbarHost = { SnackbarHost(snackbar) },
            ) { innerPadding ->
                NavHost(
                    navController = navController,
                    startDestination = if (welcomed) Routes.HOME else Routes.WELCOME,
                    modifier = Modifier
                        .padding(innerPadding)
                        .padding(bottom = if (showBottomBar) dockReserve else 0.dp),
                    // 轻微横移配合淡入淡出，保留页面连续性并避免纯交叉淡化的闪屏感。
                    enterTransition = {
                        fadeIn(animationSpec = tween(240)) +
                            slideInHorizontally(animationSpec = tween(240)) { it / 14 }
                    },
                    exitTransition = {
                        fadeOut(animationSpec = tween(180)) +
                            slideOutHorizontally(animationSpec = tween(180)) { -it / 20 }
                    },
                    popEnterTransition = {
                        fadeIn(animationSpec = tween(240)) +
                            slideInHorizontally(animationSpec = tween(240)) { -it / 14 }
                    },
                    popExitTransition = {
                        fadeOut(animationSpec = tween(180)) +
                            slideOutHorizontally(animationSpec = tween(180)) { it / 20 }
                    },
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
                            onOpenSearch = { navController.navigate(Routes.EXPLORE) },
                            onOpenRecord = { navController.navigate(Routes.recordDetail(it)) },
                        )
                    }
                    composable(Routes.EXPLORE) {
                        ExploreScreen(
                            onOpenLogFlow = { navController.navigate(Routes.LOG_FLOW) },
                            onOpenRecord = { navController.navigate(Routes.recordDetail(it)) },
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
                        CalendarScreen(
                            onOpenSettings = { navController.navigate(Routes.PROFILE) },
                            onOpenRecord = { navController.navigate(Routes.recordDetail(it)) },
                        )
                    }
                    composable(Routes.LOG_FLOW) {
                        LogFlowScreen(
                            onBack = { navController.popBackStack() },
                            onOpenRecord = { navController.navigate(Routes.recordDetail(it)) },
                        )
                    }
                    composable(Routes.RECORD_DETAIL_PATTERN) { entry ->
                        val recordId = entry.arguments?.getString("recordId") ?: return@composable
                        RecordDetailScreen(recordId = recordId, onBack = { navController.popBackStack() })
                    }
                }
            }

            if (showBottomBar) {
                // FAB 展开时的遮罩：渐入，点击或返回键收起
                AnimatedVisibility(
                    visible = fabExpanded,
                    enter = fadeIn(tween(FlashTokens.Motion.SelectionMs)),
                    exit = fadeOut(tween(150)),
                ) {
                    Box(
                        Modifier
                            .fillMaxSize()
                            .background(Color.Black.copy(alpha = 0.32f))
                            .clickable { fabExpanded = false },
                    )
                }
                // 悬浮 Dock + 右侧独立圆形 “+” FAB
                Row(
                    modifier = Modifier
                        .align(Alignment.BottomCenter)
                        .navigationBarsPadding()
                        .padding(
                            horizontal = FlashTokens.Spacing.PageHorizontal,
                            vertical = FlashTokens.Dock.BottomMargin,
                        ),
                    horizontalArrangement = Arrangement.spacedBy(FlashTokens.Spacing.SM),
                    verticalAlignment = Alignment.Bottom,
                ) {
                    FlashDock(
                        currentRoute = currentRoute,
                        onSelect = { tab ->
                            navController.navigate(tab.route) {
                                popUpTo(navController.graph.findStartDestination().id) {
                                    saveState = true
                                }
                                launchSingleTop = true
                                restoreState = true
                            }
                        },
                        badgeCount = { route ->
                            if (route == Routes.EXPLORE && showIdeaReminder) unviewedIdeas.size else 0
                        },
                        modifier = Modifier.weight(1f),
                    )
                    QuickCreateFab(
                        expanded = fabExpanded,
                        onExpandedChange = { fabExpanded = it },
                        onCreateLog = { quickCreateKey = Category.LOG.name },
                        onCreateIdea = { quickCreateKey = Category.IDEA.name },
                        onCreateEmotion = { navController.navigate(Routes.EMOTION) },
                        onCreateTask = { taskEditorOpen = true },
                    )
                }
            }
        }
    }

    BackHandler(enabled = fabExpanded && showBottomBar) { fabExpanded = false }

    quickCreate?.let { category ->
        QuickInputDialog(
            category = category,
            onDismiss = { quickCreateKey = null },
            onSave = { text ->
                quickCreateKey = null
                // 与 HomeViewModel.quickAdd 同一用例：domain/QuickAdd.kt
                scope.launch {
                    runCatching { app.repository.quickAdd(text, category) }.onFailure {
                        snackbar.showSnackbar(it.message ?: "保存失败，请重试")
                    }
                }
            },
        )
    }

    if (taskEditorOpen) {
        TaskEditorDialog(
            selectedDate = java.time.LocalDate.now(),
            existing = null,
            onDismiss = { taskEditorOpen = false },
            onSave = { draft ->
                taskEditorOpen = false
                scope.launch {
                    runCatching {
                        val task = app.repository.newTask(
                            draft.title,
                            draft.notes,
                            draft.colorTag,
                            draft.importance,
                            draft.dueKind,
                            draft.dueDate,
                            draft.dueAt,
                            draft.timeZone,
                            draft.reminderAt,
                        )
                        app.repository.addTask(task)
                        app.taskReminders.schedule(task)
                    }.onFailure {
                        snackbar.showSnackbar(it.message ?: "任务保存失败")
                    }
                }
            },
        )
    }
}
