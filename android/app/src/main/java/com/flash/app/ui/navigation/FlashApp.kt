// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package com.flash.app.ui.navigation

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInHorizontally
import androidx.compose.animation.slideOutHorizontally
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.asPaddingValues
import androidx.compose.foundation.layout.navigationBars
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.consumeWindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SnackbarDuration
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.SnackbarResult
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
import androidx.compose.ui.unit.dp
import androidx.core.content.ContextCompat
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.navigation.NavGraph.Companion.findStartDestination
import androidx.navigation.NavHostController
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.rememberNavController
import com.flash.app.FlashApplication
import com.flash.app.data.model.Category
import com.flash.app.domain.quickAdd
import com.flash.app.domain.shouldShowIdeaReminder
import com.flash.app.i18n.tr
import com.flash.app.ui.calendar.CalendarScreen
import com.flash.app.ui.calendar.TaskEditorDialog
import com.flash.app.ui.capture.QuickCaptureSheet
import com.flash.app.ui.detail.RecordDetailScreen
import com.flash.app.ui.emotion.EmotionScreen
import com.flash.app.ui.explore.ExploreScreen
import com.flash.app.ui.home.HomeScreen
import com.flash.app.ui.logflow.LogFlowScreen
import com.flash.app.ui.memory.MemoryScreen
import com.flash.app.ui.paper.paperBackground
import com.flash.app.ui.search.SearchScreen
import com.flash.app.ui.settings.BackupSettingsScreen
import com.flash.app.ui.settings.IdeaReminderSettingsScreen
import com.flash.app.ui.settings.SettingsScreen
import com.flash.app.ui.settings.TransferInfoScreen
import com.flash.app.ui.stats.StatsScreen
import com.flash.app.ui.theme.FlashTokens
import com.flash.app.ui.welcome.WelcomeScreen
import kotlinx.coroutines.launch
import kotlinx.coroutines.withTimeoutOrNull

private data class TaskRequest(val sourceLogId: String? = null, val title: String = "")

private data class CaptureRequest(val category: Category, val sharedText: String? = null)

private fun NavHostController.openTab(route: String) {
    navigate(route) {
        popUpTo(graph.findStartDestination().id) { saveState = true }
        launchSingleTop = true
        restoreState = true
    }
}

@Composable
fun FlashApp() {
    val context = LocalContext.current
    val app = context.applicationContext as FlashApplication
    val welcomed by app.settings.welcomed.collectAsStateWithLifecycle()
    val unviewedIdeas by app.repository.unviewedIdeas.collectAsStateWithLifecycle(emptyList())
    val showIdeaReminder = shouldShowIdeaReminder(unviewedIdeas.size)
    val pendingEntry by app.pendingEntry.collectAsStateWithLifecycle()

    val navController = rememberNavController()
    val backStackEntry by navController.currentBackStackEntryAsState()
    val currentRoute = backStackEntry?.destination?.route
    val showBottomBar = currentRoute in TABS.map { it.route }
    val snackbar = remember { SnackbarHostState() }
    val scope = rememberCoroutineScope()

    var capture by remember { mutableStateOf<CaptureRequest?>(null) }
    var taskRequest by remember { mutableStateOf<TaskRequest?>(null) }
    var pendingCalendarFocus by rememberSaveable { mutableStateOf(false) }
    var explorePresetIdeas by rememberSaveable { mutableStateOf(false) }

    val notificationPermission = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { granted ->
        if (!granted) scope.launch { snackbar.showSnackbar(tr("任务已保存；允许通知后才能收到提醒")) }
    }

    fun toast(message: String, actionLabel: String?, action: (suspend () -> Unit)?) {
        scope.launch {
            snackbar.currentSnackbarData?.dismiss()
            val result = withTimeoutOrNull(if (action == null) 1600L else 4000L) {
                snackbar.showSnackbar(message, actionLabel, withDismissAction = false, duration = SnackbarDuration.Indefinite)
            }
            if (result == SnackbarResult.ActionPerformed) action?.invoke()
        }
    }

    val actions = remember(navController) {
        AppActions(
            quickCapture = { capture = CaptureRequest(it) },
            newTask = { taskRequest = TaskRequest() },
            newTaskFromIdea = { id, title -> taskRequest = TaskRequest(id, title) },
            openTab = { navController.openTab(it) },
            openSearch = { navController.navigate(Routes.SEARCH) { launchSingleTop = true } },
            openRecord = { navController.navigate(Routes.recordDetail(it)) },
            toast = ::toast,
        )
    }

    // 深链 / 通知 / 系统分享：首启欢迎页完成后才处理，避免把用户从欢迎页带走
    LaunchedEffect(pendingEntry, welcomed) {
        val entry = pendingEntry ?: return@LaunchedEffect
        if (!welcomed) return@LaunchedEffect
        app.pendingEntry.value = null
        when (entry) {
            is AppEntry.Capture -> capture = CaptureRequest(entry.category)
            is AppEntry.Shared -> capture = CaptureRequest(Category.IDEA, entry.text)
            AppEntry.Today -> navController.openTab(Routes.HOME)
            AppEntry.Ideas -> {
                explorePresetIdeas = true
                navController.openTab(Routes.EXPLORE)
            }
            is AppEntry.OpenRecord -> navController.navigate(Routes.recordDetail(entry.id))
        }
    }

    BoxWithConstraints(Modifier.fillMaxSize().paperBackground()) {
        val wide = maxWidth >= 600.dp
        // 底栏悬浮于内容之上：一级页面预留底部空间
        val navBar = WindowInsets.navigationBars.asPaddingValues().calculateBottomPadding()
        val chromeReserve = navBar + FlashTokens.Dock.BottomMargin * 2 + FlashTokens.Dock.Height +
            if (wide) 0.dp else FlashTokens.Dock.CaptureBarHeight + FlashTokens.Spacing.XS
        CompositionLocalProvider(
            LocalAppActions provides actions,
            LocalPageBottomPadding provides if (showBottomBar) chromeReserve else 0.dp,
        ) {
            Scaffold(
                containerColor = Color.Transparent,
                contentColor = MaterialTheme.colorScheme.onSurface,
                // 内容铺到屏幕边缘（纸面连续），由各页处理系统栏
                contentWindowInsets = WindowInsets(0, 0, 0, 0),
                snackbarHost = {
                    SnackbarHost(
                        snackbar,
                        Modifier.padding(bottom = if (showBottomBar) chromeReserve else navBar),
                    )
                },
            ) { innerPadding ->
                NavHost(
                    navController = navController,
                    startDestination = if (welcomed) Routes.HOME else Routes.WELCOME,
                    modifier = Modifier.padding(innerPadding).consumeWindowInsets(innerPadding),
                    enterTransition = {
                        fadeIn(animationSpec = tween(240)) + slideInHorizontally(animationSpec = tween(240)) { it / 14 }
                    },
                    exitTransition = {
                        fadeOut(animationSpec = tween(180)) + slideOutHorizontally(animationSpec = tween(180)) { -it / 20 }
                    },
                    popEnterTransition = {
                        fadeIn(animationSpec = tween(240)) + slideInHorizontally(animationSpec = tween(240)) { -it / 14 }
                    },
                    popExitTransition = {
                        fadeOut(animationSpec = tween(180)) + slideOutHorizontally(animationSpec = tween(180)) { it / 20 }
                    },
                ) {
                    composable(Routes.WELCOME) {
                        WelcomeScreen(onStart = {
                            app.settings.setWelcomed()
                            navController.navigate(Routes.HOME) { popUpTo(Routes.WELCOME) { inclusive = true } }
                        })
                    }
                    composable(Routes.HOME) { HomeScreen() }
                    composable(Routes.EXPLORE) {
                        ExploreScreen(
                            onOpenLogFlow = { navController.navigate(Routes.LOG_FLOW) },
                            onOpenRecord = actions.openRecord,
                            presetIdeas = explorePresetIdeas,
                            onPresetConsumed = { explorePresetIdeas = false },
                        )
                    }
                    composable(Routes.EMOTION) { EmotionScreen() }
                    composable(Routes.STATS) {
                        StatsScreen(
                            onOpenMemory = { navController.navigate(Routes.MEMORY) },
                            onOpenRecord = actions.openRecord,
                        )
                    }
                    composable(Routes.PROFILE) {
                        SettingsScreen(
                            onOpenIdeaReminder = { navController.navigate(Routes.SETTINGS_IDEA_REMINDER) },
                            onOpenBackup = { navController.navigate(Routes.SETTINGS_BACKUP) },
                            onOpenTransfer = { navController.navigate(Routes.SETTINGS_TRANSFER) },
                        )
                    }
                    composable(Routes.SETTINGS_IDEA_REMINDER) {
                        IdeaReminderSettingsScreen(onBack = { navController.popBackStack() })
                    }
                    composable(Routes.SETTINGS_BACKUP) { BackupSettingsScreen(onBack = { navController.popBackStack() }) }
                    composable(Routes.SETTINGS_TRANSFER) { TransferInfoScreen(onBack = { navController.popBackStack() }) }
                    composable(Routes.CALENDAR) {
                        CalendarScreen(
                            onOpenRecord = actions.openRecord,
                            onBack = { navController.popBackStack() },
                            initialDate = null,
                        )
                    }
                    composable(Routes.LOG_FLOW) {
                        LogFlowScreen(onBack = { navController.popBackStack() }, onOpenRecord = actions.openRecord)
                    }
                    composable(Routes.MEMORY) { MemoryScreen(onBack = { navController.popBackStack() }) }
                    composable(Routes.SEARCH) {
                        SearchScreen(
                            onBack = { navController.popBackStack() },
                            onOpenLog = { id ->
                                navController.popBackStack()
                                actions.openRecord(id)
                            },
                            onOpenEmotion = {
                                navController.popBackStack()
                                navController.openTab(Routes.EMOTION)
                            },
                            onOpenTask = {
                                navController.popBackStack()
                                navController.navigate(Routes.CALENDAR)
                            },
                        )
                    }
                    composable(Routes.RECORD_DETAIL_PATTERN) { entry ->
                        val recordId = entry.arguments?.getString("recordId") ?: return@composable
                        RecordDetailScreen(recordId = recordId, onBack = { navController.popBackStack() })
                    }
                }
            }

            if (showBottomBar) {
                Column(
                    modifier = Modifier
                        .align(Alignment.BottomCenter)
                        .navigationBarsPadding()
                        .padding(horizontal = FlashTokens.Spacing.PageHorizontal, vertical = FlashTokens.Dock.BottomMargin)
                        .fillMaxWidth(),
                    verticalArrangement = Arrangement.spacedBy(FlashTokens.Spacing.XS),
                ) {
                    AnimatedVisibility(visible = !wide) {
                        QuickCaptureBar(onClick = { capture = CaptureRequest(Category.IDEA) })
                    }
                    FlashDock(
                        currentRoute = currentRoute,
                        onSelect = { navController.openTab(it.route) },
                        badgeCount = { route ->
                            if (route == Routes.EXPLORE && showIdeaReminder) unviewedIdeas.size else 0
                        },
                    )
                }
                if (wide) {
                    QuickCaptureFab(
                        onClick = { capture = CaptureRequest(Category.IDEA) },
                        modifier = Modifier
                            .align(Alignment.BottomEnd)
                            .navigationBarsPadding()
                            .padding(end = FlashTokens.Spacing.PageHorizontal, bottom = FlashTokens.Dock.BottomMargin * 2 + FlashTokens.Dock.Height + FlashTokens.Spacing.SM),
                    )
                }
            }
        }
    }

    capture?.let { request ->
        var draft by remember { mutableStateOf(app.settings.quickCaptureDraft) }
        QuickCaptureSheet(
            initialCategory = request.category,
            initialText = request.sharedText,
            draft = draft,
            onDraftChange = {
                draft = it
                app.settings.quickCaptureDraft = it
            },
            onDismiss = { capture = null },
            onSave = { text, category ->
                app.repository.quickAdd(text, category)
                toast(if (category == Category.IDEA) tr("✓ 已保存到灵感") else tr("✓ 已保存到日志"), null, null)
            },
        )
    }

    taskRequest?.let { request ->
        TaskEditorDialog(
            selectedDate = java.time.LocalDate.now(),
            existing = null,
            initialTitle = request.title,
            sourceLogId = request.sourceLogId,
            onDismiss = { taskRequest = null },
            onSave = { draft ->
                taskRequest = null
                scope.launch {
                    runCatching {
                        val task = app.repository.newTask(
                            draft.title, draft.notes, draft.colorTag, draft.importance, draft.dueKind,
                            draft.dueDate, draft.dueAt, draft.timeZone, draft.reminderAt,
                            sourceLogId = request.sourceLogId,
                            isFavorite = draft.isFavorite,
                        )
                        app.repository.addTask(task)
                        app.taskReminders.schedule(task)
                        // 从「+」创建的任务同样要申请通知权限，否则提醒会静默丢失
                        if (draft.reminderAt != null && Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
                            ContextCompat.checkSelfPermission(context, Manifest.permission.POST_NOTIFICATIONS) !=
                            PackageManager.PERMISSION_GRANTED
                        ) {
                            notificationPermission.launch(Manifest.permission.POST_NOTIFICATIONS)
                        }
                    }.onFailure {
                        snackbar.showSnackbar(it.message ?: tr("任务保存失败"))
                    }
                }
            },
        )
    }
}
