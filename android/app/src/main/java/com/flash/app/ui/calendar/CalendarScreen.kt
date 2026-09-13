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
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
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
import com.flash.app.ui.components.hexToColor
import java.time.LocalDate
import java.time.YearMonth
import kotlinx.coroutines.launch

private val WEEKDAYS = listOf("一", "二", "三", "四", "五", "六", "日")

/** Calendar Tab：真实月视图 + 选中日详情 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun CalendarScreen(onOpenSettings: () -> Unit, onOpenRecord: (String) -> Unit) {
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
            snackbar.showSnackbar("任务已保存；允许通知后才能收到提醒")
        }
    }

    LaunchedEffect(viewModel) {
        viewModel.events.collect { event ->
            when (event) {
                is CalendarEvent.Failed -> snackbar.showSnackbar(event.message)
            }
        }
    }

    Scaffold(
        containerColor = Color.Transparent,
        topBar = {
            TopAppBar(
                title = { Text("日历") },
                colors = TopAppBarDefaults.topAppBarColors(containerColor = Color.Transparent),
                actions = {
                    IconButton(onClick = {
                        editingTask = null
                        editorOpen = true
                    }) {
                        Icon(Icons.Filled.Add, contentDescription = "新建任务")
                    }
                    IconButton(onClick = onOpenSettings) {
                        Icon(Icons.Filled.Settings, contentDescription = "设置")
                    }
                },
            )
        },
        snackbarHost = { SnackbarHost(snackbar) },
    ) { innerPadding ->
        LazyColumn(
            modifier = Modifier
                .padding(innerPadding)
                .fillMaxSize(),
            contentPadding = PaddingValues(horizontal = 16.dp, vertical = 8.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            item(key = "month-header") {
                MonthHeader(
                    month = uiState.month,
                    onPrev = viewModel::prevMonth,
                    onNext = viewModel::nextMonth,
                    onToday = viewModel::backToToday,
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
                MonthGrid(
                    uiState = uiState,
                    onSelect = viewModel::selectDate,
                )
            }
            item(key = "detail-header") {
                Spacer(Modifier.height(8.dp))
                Text(
                    "${uiState.selectedDate} 详情",
                    style = MaterialTheme.typography.titleSmall,
                )
            }
            item(key = "detail") {
                DayDetail(
                    aggregate = uiState.selectedAggregate,
                    onOpenRecord = onOpenRecord,
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
            title = { Text("删除任务？") },
            text = { Text(task.title) },
            confirmButton = {
                TextButton(onClick = {
                    viewModel.deleteTask(task)
                    deletingTask = null
                }) { Text("删除", color = MaterialTheme.colorScheme.error) }
            },
            dismissButton = {
                TextButton(onClick = { deletingTask = null }) { Text("取消") }
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
) {
    Row(verticalAlignment = Alignment.CenterVertically) {
        IconButton(onClick = onPrev) {
            Icon(Icons.AutoMirrored.Filled.KeyboardArrowLeft, contentDescription = "上一月")
        }
        Text(
            "${month.year} 年 ${month.monthValue} 月",
            style = MaterialTheme.typography.titleMedium,
            fontWeight = FontWeight.Medium,
            modifier = Modifier.weight(1f),
            textAlign = TextAlign.Center,
        )
        TextButton(onClick = onToday) { Text("今天") }
        IconButton(onClick = onNext) {
            Icon(Icons.AutoMirrored.Filled.KeyboardArrowRight, contentDescription = "下一月")
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
        else -> MaterialTheme.colorScheme.surface
    }
    Column(
        modifier = modifier
            .aspectRatio(1f)
            .padding(2.dp)
            .border(1.dp, borderColor, MaterialTheme.shapes.small)
            .clickable(onClick = onClick)
            .padding(2.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Text(
            "${date.dayOfMonth}",
            style = MaterialTheme.typography.labelMedium,
            fontWeight = if (isToday) FontWeight.Bold else FontWeight.Normal,
            color = when {
                // 非当月日期：比当月弱但在浅渐变背景上仍可辨
                !inMonth -> MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.6f)
                isToday -> MaterialTheme.colorScheme.primary
                else -> MaterialTheme.colorScheme.onSurface
            },
        )
        if (aggregate != null) {
            // 情绪圆点（最多 3 个）+ 当天内容数
            Row(
                horizontalArrangement = Arrangement.Center,
                modifier = Modifier.padding(top = 2.dp),
            ) {
                aggregate.emotions.take(3).forEach { emotion ->
                    Box(
                        Modifier
                            .size(5.dp)
                            .clip(CircleShape)
                            .background(emotion.level.colorHex.hexToColor())
                    )
                    Spacer(Modifier.width(1.dp))
                }
            }
            val itemCount = aggregate.logs.size + aggregate.tasks.count { !it.isCompleted }
            if (itemCount > 0) {
                Text(
                    "$itemCount",
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
        }
    }
}

@Composable
private fun DayDetail(
    aggregate: DayAggregate?,
    onOpenRecord: (String) -> Unit,
    onCompletedChange: (TaskItem, Boolean) -> Unit,
    onEditTask: (TaskItem) -> Unit,
    onDeleteTask: (TaskItem) -> Unit,
) {
    if (aggregate == null ||
        (aggregate.logs.isEmpty() && aggregate.emotions.isEmpty() && aggregate.tasks.isEmpty())
    ) {
        Text(
            "这一天还没有计划或记录",
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
            )
        }
        if (aggregate.logs.isNotEmpty() || aggregate.emotions.isNotEmpty()) {
            StyleCard(modifier = Modifier.fillMaxWidth()) {
                if (aggregate.emotions.isNotEmpty()) {
                    val avg = aggregate.emotions.map { it.level.value }.average()
                    Text(
                        "平均情绪 %.1f · 共 %d 条".format(avg, aggregate.emotions.size),
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
                                    .background(emotion.level.colorHex.hexToColor())
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
