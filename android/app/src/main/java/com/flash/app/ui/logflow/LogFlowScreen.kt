// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package com.flash.app.ui.logflow

import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.Edit
import androidx.compose.material.icons.filled.Search
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.DatePicker
import androidx.compose.material3.DatePickerDialog
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilterChip
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SegmentedButton
import androidx.compose.material3.SegmentedButtonDefaults
import androidx.compose.material3.SingleChoiceSegmentedButtonRow
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.material3.rememberDatePickerState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import com.flash.app.FlashApplication
import com.flash.app.data.Backup
import com.flash.app.data.model.ColorTag
import com.flash.app.data.model.LogItem
import com.flash.app.ui.components.LogCard
import java.time.Instant
import java.time.ZoneOffset

/** 日志管理页：搜索 / 标签筛选 / 排序 / 编辑 / 删除，对应 Web 版 LogFlow */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun LogFlowScreen(onBack: () -> Unit, onOpenRecord: (String) -> Unit) {
    val app = LocalContext.current.applicationContext as FlashApplication
    val viewModel: LogFlowViewModel = viewModel(factory = LogFlowViewModel.factory(app.repository))
    val logs by viewModel.logs.collectAsStateWithLifecycle()
    val filter by viewModel.filter.collectAsStateWithLifecycle()

    var editingLog by remember { mutableStateOf<LogItem?>(null) }
    var deletingLog by remember { mutableStateOf<LogItem?>(null) }
    var showStartPicker by remember { mutableStateOf(false) }
    var showEndPicker by remember { mutableStateOf(false) }

    Scaffold(
        containerColor = Color.Transparent,
        topBar = {
            TopAppBar(
                title = { Text("日志管理") },
                colors = TopAppBarDefaults.topAppBarColors(containerColor = Color.Transparent),
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "返回")
                    }
                },
            )
        },
    ) { innerPadding ->
        Column(
            modifier = Modifier
                .padding(innerPadding)
                .fillMaxSize(),
        ) {
            OutlinedTextField(
                value = filter.query,
                onValueChange = viewModel::setQuery,
                placeholder = { Text("搜索日志...") },
                leadingIcon = { Icon(Icons.Filled.Search, contentDescription = null) },
                singleLine = true,
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp),
            )
            Row(
                horizontalArrangement = Arrangement.spacedBy(8.dp),
                modifier = Modifier
                    .fillMaxWidth()
                    .horizontalScroll(rememberScrollState())
                    .padding(horizontal = 16.dp, vertical = 8.dp),
            ) {
                ColorTag.entries.forEach { tag ->
                    FilterChip(
                        selected = tag in filter.tags,
                        onClick = { viewModel.toggleTag(tag) },
                        label = { Text(tag.displayName) },
                    )
                }
            }
            // 日期范围筛选（对应 Web 版 startDate/endDate）
            Row(
                horizontalArrangement = Arrangement.spacedBy(8.dp),
                verticalAlignment = Alignment.CenterVertically,
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp),
            ) {
                OutlinedButton(onClick = { showStartPicker = true }) {
                    Text(filter.startDate?.let { "自 $it" } ?: "开始日期")
                }
                OutlinedButton(onClick = { showEndPicker = true }) {
                    Text(filter.endDate?.let { "至 $it" } ?: "结束日期")
                }
                if (filter.startDate != null || filter.endDate != null) {
                    TextButton(onClick = { viewModel.setDateRange(null, null) }) {
                        Text("清除")
                    }
                }
            }
            SingleChoiceSegmentedButtonRow(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp),
            ) {
                LogSort.entries.forEachIndexed { index, sort ->
                    SegmentedButton(
                        selected = filter.sort == sort,
                        onClick = { viewModel.setSort(sort) },
                        shape = SegmentedButtonDefaults.itemShape(
                            index = index,
                            count = LogSort.entries.size,
                        ),
                    ) {
                        Text(sort.displayName)
                    }
                }
            }
            Text(
                "${logs.size} 条",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.padding(horizontal = 16.dp, vertical = 8.dp),
            )
            LazyColumn(
                modifier = Modifier.fillMaxSize(),
                contentPadding = PaddingValues(horizontal = 16.dp, vertical = 4.dp),
                verticalArrangement = Arrangement.spacedBy(8.dp),
            ) { 
                if (logs.isEmpty()) {
                    item(key = "empty") {
                        Text(
                            "没有符合条件的日志",
                            style = MaterialTheme.typography.bodyMedium,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                            modifier = Modifier.fillMaxWidth().padding(vertical = 32.dp),
                        )
                    }
                }
                items(items = logs, key = { it.id }) { log ->
                    LogCard(
                        log = log,
                        onClick = { onOpenRecord(log.id) },
                        actions = {
                            IconButton(onClick = { editingLog = log }) {
                                Icon(Icons.Filled.Edit, contentDescription = "编辑")
                            }
                            IconButton(onClick = { deletingLog = log }) {
                                Icon(
                                    Icons.Filled.Delete,
                                    contentDescription = "删除",
                                    tint = MaterialTheme.colorScheme.error,
                                )
                            }
                        },
                    )
                }
            }
        }
    }

    editingLog?.let { log ->
        EditLogDialog(
            log = log,
            onDismiss = { editingLog = null },
            onSave = { updated ->
                viewModel.updateLog(updated)
                editingLog = null
            },
        )
    }

    if (showStartPicker) {
        DatePickDialog(
            title = "开始日期",
            onConfirm = { date ->
                viewModel.setDateRange(date, filter.endDate)
                showStartPicker = false
            },
            onDismiss = { showStartPicker = false },
        )
    }

    if (showEndPicker) {
        DatePickDialog(
            title = "结束日期",
            onConfirm = { date ->
                viewModel.setDateRange(filter.startDate, date)
                showEndPicker = false
            },
            onDismiss = { showEndPicker = false },
        )
    }

    deletingLog?.let { log ->
        AlertDialog(
            onDismissRequest = { deletingLog = null },
            title = { Text("删除这条日志？") },
            text = { Text(log.content.take(50)) },
            confirmButton = {
                TextButton(onClick = {
                    viewModel.deleteLog(log.id)
                    deletingLog = null
                }) {
                    Text("删除", color = MaterialTheme.colorScheme.error)
                }
            },
            dismissButton = {
                TextButton(onClick = { deletingLog = null }) { Text("取消") }
            },
        )
    }
}

@Composable
private fun EditLogDialog(log: LogItem, onDismiss: () -> Unit, onSave: (LogItem) -> Unit) {
    var content by remember(log.id) { mutableStateOf(log.content) }
    var tag by remember(log.id) { mutableStateOf(log.colorTag) }
    var importance by remember(log.id) { mutableIntStateOf(log.importance) }

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("编辑日志") },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                OutlinedTextField(
                    value = content,
                    onValueChange = { content = it.take(MAX_CONTENT_LENGTH) },
                    label = { Text("内容") },
                    supportingText = { Text("${content.length}/$MAX_CONTENT_LENGTH") },
                    modifier = Modifier.fillMaxWidth(),
                )
                Row(
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                    modifier = Modifier.horizontalScroll(rememberScrollState()),
                ) {
                    ColorTag.entries.forEach { t ->
                        FilterChip(
                            selected = tag == t,
                            onClick = { tag = t },
                            label = { Text(t.displayName) },
                        )
                    }
                }
                Row(
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Text("重要性", style = MaterialTheme.typography.bodyMedium)
                    IMPORTANCE_OPTIONS.forEach { (value, label) ->
                        FilterChip(
                            selected = importance == value,
                            onClick = { importance = value },
                            label = { Text(label.ifEmpty { "无" }) },
                        )
                    }
                }
            }
        },
        confirmButton = {
            TextButton(
                onClick = {
                    if (content.isNotBlank()) {
                        onSave(log.copy(content = content.trim(), colorTag = tag, importance = importance))
                    }
                },
            ) { Text("保存") }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) { Text("取消") }
        },
    )
}

private val IMPORTANCE_OPTIONS = listOf(0 to "", 2 to "!!", 3 to "!!!", 4 to "!!!!")

private const val MAX_CONTENT_LENGTH = Backup.MAX_FIELD_LENGTH

/** MD3 DatePicker 弹窗；返回的毫秒值为 UTC 零点，按 UTC 解析避免时区偏移 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun DatePickDialog(
    title: String,
    onConfirm: (String?) -> Unit,
    onDismiss: () -> Unit,
) {
    val state = rememberDatePickerState()
    DatePickerDialog(
        onDismissRequest = onDismiss,
        confirmButton = {
            TextButton(onClick = {
                val date = state.selectedDateMillis?.let { millis ->
                    Instant.ofEpochMilli(millis).atZone(ZoneOffset.UTC).toLocalDate().toString()
                }
                onConfirm(date)
            }) { Text("确定") }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) { Text("取消") }
        },
    ) {
        Column {
            Text(
                title,
                style = MaterialTheme.typography.titleMedium,
                modifier = Modifier.padding(start = 24.dp, top = 16.dp),
            )
            DatePicker(state = state, showModeToggle = false)
        }
    }
}
