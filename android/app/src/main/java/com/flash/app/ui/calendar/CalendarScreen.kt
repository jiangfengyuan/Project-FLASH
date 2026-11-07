// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package com.flash.app.ui.calendar

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.selection.selectable
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyListState
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowLeft
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material.icons.filled.Add
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.ScaffoldDefaults
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.core.content.ContextCompat
import com.flash.app.FlashApplication
import com.flash.app.data.model.TaskItem
import com.flash.app.ui.components.LogCard
import com.flash.app.ui.components.StyleCard
import com.flash.app.ui.theme.moodColor
import com.flash.app.data.model.emoji
import androidx.compose.animation.togetherWith
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.ui.unit.sp
import java.time.LocalDate
import java.time.YearMonth
import kotlinx.coroutines.launch

private val WEEKDAYS get() = listOf("一", "二", "三", "四", "五", "六", "日")

/** Calendar Tab：真实月视图 + 选中日详情 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun CalendarScreen(
    onOpenRecord: (String) -> Unit,
    embedded: Boolean = false,
    listState: LazyListState = rememberLazyListState(),
    onBack: (() -> Unit)? = null,
    initialDate: LocalDate? = null,
) {
    val context = LocalContext.current
    val app = context.applicationContext as FlashApplication
    val viewModel: CalendarViewModel = viewModel(
        factory = CalendarViewModel.factory(app.repository, app.taskReminders)
    )
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()
    val snackbar = remember { SnackbarHostState() }
    val scope = rememberCoroutineScope()
    var editorOpen by remember { mutableStateOf(false) }
    var editingTask by remember { mutableStateOf<TaskItem?>(null) }
    var deletingTask by remember { mutableStateOf<TaskItem?>(null) }
    val notificationPermission = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestPermission(),
    ) { granted ->
        if (!granted) scope.launch {
            snackbar.showSnackbar(com.flash.app.i18n.tr("任务已保存；允许通知后才能收到提醒"))
        }
    }

    LaunchedEffect(initialDate) { initialDate?.let(viewModel::selectDate) }

    LaunchedEffect(viewModel) {
        viewModel.events.collect { event ->
            when (event) {
                is CalendarEvent.Failed -> snackbar.showSnackbar(event.message)
            }
        }
    }

    Scaffold(
        containerColor = Color.Transparent,
        contentWindowInsets = if (embedded) WindowInsets(0, 0, 0, 0) else ScaffoldDefaults.contentWindowInsets,
        topBar = {
            if (!embedded) TopAppBar(
                title = { Text(com.flash.app.i18n.tr("日历")) },
                colors = TopAppBarDefaults.topAppBarColors(containerColor = Color.Transparent),
                navigationIcon = {
                    if (onBack != null) {
                        IconButton(onClick = onBack) {
                            Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = com.flash.app.i18n.tr("返回"))
                        }
                    }
                },
                actions = {
                    IconButton(onClick = {
                        editingTask = null
                        editorOpen = true
                    }) {
                        Icon(Icons.Filled.Add, contentDescription = com.flash.app.i18n.tr("新建任务"))
                    }
                },
            )
        },
        snackbarHost = { SnackbarHost(snackbar) },
    ) { innerPadding ->
        LazyColumn(
            state = listState,
            modifier = Modifier
                .padding(innerPadding)
                .fillMaxSize(),
            contentPadding = PaddingValues(start = com.flash.app.ui.paper.pageGutter(), end = com.flash.app.ui.paper.pageGutter(), top = 8.dp,
                bottom = 8.dp + com.flash.app.ui.navigation.LocalPageBottomPadding.current),
            verticalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            item(key = "month-header") {
                MonthHeader(
                    month = uiState.month,
                    onPrev = viewModel::prevMonth,
                    onNext = viewModel::nextMonth,
                    onToday = viewModel::backToToday,
                    onNewTask = if (embedded) {
                        {
                            editingTask = null
                            editorOpen = true
                        }
                    } else {
                        null
                    },
                )
            }
            item(key = "weekdays") {
                Row {
                    WEEKDAYS.forEach { day ->
                        Text(
                            day,
                            modifier = Modifier.weight(1f),
                            textAlign = TextAlign.Center,
                            style = MaterialTheme.typography.labelMedium,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                    }
                }
            }
            item(key = "grid") {
                // 换月：方向性横移（减弱动画时由系统动画缩放归零）
                val monthState = uiState
                androidx.compose.animation.AnimatedContent(
                    targetState = monthState.month,
                    transitionSpec = {
                        val forward = targetState > initialState
                        (androidx.compose.animation.slideInHorizontally(androidx.compose.animation.core.tween(220)) { if (forward) it / 14 else -it / 14 } +
                            androidx.compose.animation.fadeIn(androidx.compose.animation.core.tween(220)))
                            .togetherWith(androidx.compose.animation.fadeOut(androidx.compose.animation.core.tween(120)))
                    },
                    label = "calendar-month",
                ) { _ ->
                    MonthGrid(uiState = monthState, onSelect = viewModel::selectDate)
                }
            }
            item(key = "detail-header") {
                Spacer(Modifier.height(8.dp))
                Text(
                    com.flash.app.i18n.tr("{0} 详情", uiState.selectedDate),
                    style = MaterialTheme.typography.titleSmall,
                    color = MaterialTheme.colorScheme.onSurface,
                )
            }
            item(key = "detail") {
                DayDetail(
                    aggregate = uiState.selectedAggregate,
                    onOpenRecord = onOpenRecord,
                    ideaExists = { id -> uiState.ideaIds.contains(id) },
                    onCompletedChange = viewModel::setCompleted,
                    onEditTask = { task ->
                        editingTask = task
                        editorOpen = true
                    },
                    onDeleteTask = { deletingTask = it },
                )
            }
        }
    }

    if (editorOpen) {
        TaskEditorDialog(
            selectedDate = uiState.selectedDate,
            existing = editingTask,
            onDismiss = { editorOpen = false },
            onSave = { draft ->
                viewModel.saveTask(editingTask, draft)
                editorOpen = false
                if (draft.reminderAt != null &&
                    Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
                    ContextCompat.checkSelfPermission(context, Manifest.permission.POST_NOTIFICATIONS) !=
                    PackageManager.PERMISSION_GRANTED
                ) {
                    notificationPermission.launch(Manifest.permission.POST_NOTIFICATIONS)
                }
            },
        )
    }

    deletingTask?.let { task ->
        AlertDialog(
            onDismissRequest = { deletingTask = null },
            title = { Text(com.flash.app.i18n.tr("删除任务？")) },
            text = { Text(task.title) },
            confirmButton = {
                TextButton(onClick = {
                    viewModel.deleteTask(task)
                    deletingTask = null
                }) { Text(com.flash.app.i18n.tr("删除"), color = MaterialTheme.colorScheme.error) }
            },
            dismissButton = {
                TextButton(onClick = { deletingTask = null }) { Text(com.flash.app.i18n.tr("取消")) }
            },
        )
    }
}

@Composable
private fun MonthHeader(
    month: YearMonth,
    onPrev: () -> Unit,
    onNext: () -> Unit,
    onToday: () -> Unit,
    onNewTask: (() -> Unit)? = null,
) {
    val rtl = androidx.compose.ui.platform.LocalLayoutDirection.current == androidx.compose.ui.unit.LayoutDirection.Rtl
    Row(verticalAlignment = Alignment.CenterVertically) {
        IconButton(onClick = onPrev) {
            Icon(Icons.AutoMirrored.Filled.KeyboardArrowLeft, contentDescription = com.flash.app.i18n.tr("上一月"), tint = MaterialTheme.colorScheme.onSurface)
        }
        Text(
            monthTitle(month),
            color = MaterialTheme.colorScheme.onSurface,
            style = MaterialTheme.typography.titleMedium,
            fontWeight = FontWeight.Medium,
            modifier = Modifier.weight(1f),
            textAlign = TextAlign.Center,
        )
        TextButton(onClick = onToday) { Text(com.flash.app.i18n.tr("回到今天")) }
        onNewTask?.let {
            IconButton(onClick = it) { Icon(Icons.Filled.Add, contentDescription = com.flash.app.i18n.tr("新建任务"), tint = MaterialTheme.colorScheme.primary) }
        }
        IconButton(onClick = onNext) {
            Icon(Icons.AutoMirrored.Filled.KeyboardArrowRight, contentDescription = com.flash.app.i18n.tr("下一月"), tint = MaterialTheme.colorScheme.onSurface)
        }
    }
}

@Composable
private fun MonthGrid(uiState: CalendarUiState, onSelect: (LocalDate) -> Unit) {
    Column {
        uiState.weeks.forEach { week ->
            Row {
                week.forEach { date ->
                    DayCell(
                        date = date,
                        inMonth = YearMonth.from(date) == uiState.month,
                        isToday = date == uiState.today,
                        isSelected = date == uiState.selectedDate,
                        aggregate = uiState.aggregates[date.toString()],
                        onClick = { onSelect(date) },
                        modifier = Modifier.weight(1f),
                    )
                }
            }
        }
    }
}

@Composable
private fun DayCell(
    date: LocalDate,
    inMonth: Boolean,
    isToday: Boolean,
    isSelected: Boolean,
    aggregate: DayAggregate?,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val borderColor = when {
        isSelected -> MaterialTheme.colorScheme.primary
        isToday -> MaterialTheme.colorScheme.outline
        else -> MaterialTheme.colorScheme.outlineVariant
    }
    Column(
        modifier = modifier
            .heightIn(min = 48.dp)
            .padding(2.dp)
            .border(1.dp, borderColor, androidx.compose.foundation.shape.RoundedCornerShape(com.flash.app.ui.theme.FlashTokens.Radius.Field))
            .selectable(selected = isSelected, role = Role.Button, onClick = onClick)
            .semantics {
                contentDescription = com.flash.app.i18n.tr("{0}，{1} 条记录，", date, aggregate?.logs?.size ?: 0) +
                    com.flash.app.i18n.tr("{0} 次情绪，{1} 项任务", aggregate?.emotions?.size ?: 0, aggregate?.tasks?.size ?: 0) +
                    if (isToday) com.flash.app.i18n.tr("，今天") else ""
            }
            .padding(2.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Text(
            "${date.dayOfMonth}",
            style = MaterialTheme.typography.labelMedium,
            fontWeight = if (isToday) FontWeight.Bold else FontWeight.Normal,
            color = when {
                // 非当月日期：用语义次文字色保持 ≥4.5:1，与当月主文字色区分
                !inMonth -> MaterialTheme.colorScheme.onSurfaceVariant
                isToday -> MaterialTheme.colorScheme.primary
                else -> MaterialTheme.colorScheme.onSurface
            },
        )
        if (aggregate != null) {
            // 记录数 · 任务数 + 当天第一个情绪 emoji（对齐 iOS）
            val tasks = aggregate.tasks.count { !it.isCompleted }
            if (aggregate.logs.isNotEmpty() || tasks > 0) {
                Row(horizontalArrangement = Arrangement.spacedBy(3.dp)) {
                    if (aggregate.logs.isNotEmpty()) {
                        Text(
                            "${aggregate.logs.size}",
                            style = MaterialTheme.typography.labelSmall,
                            color = com.flash.app.ui.theme.ModuleColors.Log,
                        )
                    }
                    if (tasks > 0) {
                        Text(
                            "$tasks",
                            style = MaterialTheme.typography.labelSmall,
                            color = com.flash.app.ui.theme.ModuleColors.CalendarText,
                        )
                    }
                }
            }
            aggregate.emotions.firstOrNull()?.let { emotion ->
                Text(emotion.level.emoji, fontSize = 11.sp)
            }
        }
    }
}

/** 月份标题：按当前语言的习惯排列（只用于显示） */
private fun monthTitle(month: YearMonth): String {
    val locale = java.util.Locale.getDefault()
    val pattern = android.text.format.DateFormat.getBestDateTimePattern(locale, "yMMMM")
    return java.time.format.DateTimeFormatter.ofPattern(pattern, locale).format(month)
}

@Composable
private fun DayDetail(
    aggregate: DayAggregate?,
    onOpenRecord: (String) -> Unit,
    ideaExists: (String) -> Boolean,
    onCompletedChange: (TaskItem, Boolean) -> Unit,
    onEditTask: (TaskItem) -> Unit,
    onDeleteTask: (TaskItem) -> Unit,
) {
    if (aggregate == null ||
        (aggregate.logs.isEmpty() && aggregate.emotions.isEmpty() && aggregate.tasks.isEmpty())
    ) {
        Text(
            com.flash.app.i18n.tr("这一天还没有计划或记录"),
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            modifier = Modifier.padding(vertical = 16.dp),
        )
        return
    }
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        aggregate.tasks.sortedWith(
            compareBy<com.flash.app.data.model.TaskItem> { it.isCompleted }.thenBy { it.dueAt ?: it.dueDate }
        ).forEach { task ->
            TaskCard(
                task = task,
                onCompletedChange = { onCompletedChange(task, it) },
                onEdit = { onEditTask(task) },
                onDelete = { onDeleteTask(task) },
                onOpenSource = task.sourceLogId?.takeIf(ideaExists)?.let { id -> { onOpenRecord(id) } },
            )
        }
        if (aggregate.logs.isNotEmpty() || aggregate.emotions.isNotEmpty()) {
            StyleCard(modifier = Modifier.fillMaxWidth()) {
                if (aggregate.emotions.isNotEmpty()) {
                    val avg = aggregate.emotions.map { it.level.value }.average()
                    Text(
                        com.flash.app.i18n.tr("平均情绪 {0} · 共 {1} 条", "%.1f".format(java.util.Locale.ROOT, avg), aggregate.emotions.size),
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                    aggregate.emotions.forEach { emotion ->
                        Row(
                            verticalAlignment = Alignment.CenterVertically,
                            modifier = Modifier.padding(top = 4.dp),
                        ) {
                            Box(
                                Modifier
                                    .size(10.dp)
                                    .clip(CircleShape)
                                    .background(emotion.level.moodColor(com.flash.app.ui.theme.LocalIsDarkTheme.current))
                            )
                            Spacer(Modifier.width(8.dp))
                            Text(
                                emotion.level.displayName +
                                    (emotion.subEmotion?.let { " · ${it.displayName}" } ?: ""),
                                style = MaterialTheme.typography.bodyMedium,
                            )
                        }
                    }
                }
                aggregate.logs.forEach { log ->
                    LogCard(
                        log = log,
                        modifier = Modifier.padding(top = 8.dp),
                        onClick = { onOpenRecord(log.id) },
                    )
                }
            }
        }
    }
}
