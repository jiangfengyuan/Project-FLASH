// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package com.flash.app.ui.explore

import android.app.DatePickerDialog
import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.border
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.Sort
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Search
import androidx.compose.material.icons.filled.Tune
import androidx.compose.material.icons.outlined.EditNote
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import com.flash.app.FlashApplication
import com.flash.app.data.model.Category
import com.flash.app.data.model.ColorTag
import com.flash.app.ui.components.FlashEmptyState
import com.flash.app.ui.components.FlashFilterChipItem
import com.flash.app.ui.components.FlashFilterChipRow
import com.flash.app.ui.components.FlashFormSection
import com.flash.app.ui.components.RecordCard
import com.flash.app.ui.theme.FlashTokens
import java.time.LocalDate

private val IMPORTANCE_OPTIONS = listOf(0 to "全部", 2 to "!!", 3 to "!!!", 4 to "!!!!")

/** 记录页（方案 §4.2）：大标题 + 搜索/筛选 → 统计摘要 → 筛选胶囊 → 记录列表 */
@OptIn(ExperimentalMaterial3Api::class, ExperimentalFoundationApi::class)
@Composable
fun ExploreScreen(
    onOpenLogFlow: () -> Unit,
    onOpenRecord: (String) -> Unit,
) {
    val app = LocalContext.current.applicationContext as FlashApplication
    val viewModel: ExploreViewModel = viewModel(factory = ExploreViewModel.factory(app.repository))
    val logs by viewModel.logs.collectAsStateWithLifecycle()
    val filter by viewModel.filter.collectAsStateWithLifecycle()
    val query by viewModel.query.collectAsStateWithLifecycle()
    val panel by viewModel.panel.collectAsStateWithLifecycle()
    val newestFirst by viewModel.newestFirst.collectAsStateWithLifecycle()
    val summary by viewModel.summary.collectAsStateWithLifecycle()
    val unviewedIdeaIds by viewModel.unviewedIdeaIds.collectAsStateWithLifecycle()
    val selection by viewModel.selection.collectAsStateWithLifecycle()
    val snackbar = remember { SnackbarHostState() }
    val searchFocus = remember { FocusRequester() }
    var filterSheetOpen by remember { mutableStateOf(false) }
    var batchDialog by remember { mutableStateOf<BatchDialog?>(null) }

    LaunchedEffect(viewModel) {
        viewModel.events.collect { event ->
            when (event) {
                is ExploreEvent.Failed -> snackbar.showSnackbar(event.message)
            }
        }
    }

    val selecting = filter == ExploreFilter.UNSORTED && selection.isNotEmpty()
    val anyFilterActive = filter != ExploreFilter.ALL || query.isNotBlank() || panel.isActive

    Scaffold(
        containerColor = Color.Transparent,
        snackbarHost = { SnackbarHost(snackbar) },
    ) { innerPadding ->
        LazyColumn(
            modifier = Modifier
                .padding(innerPadding)
                .fillMaxSize(),
            contentPadding = PaddingValues(
                start = FlashTokens.Spacing.PageHorizontal,
                end = FlashTokens.Spacing.PageHorizontal,
                top = FlashTokens.Spacing.XS,
                bottom = FlashTokens.Spacing.XS + com.flash.app.ui.navigation.LocalPageBottomPadding.current,
            ),
            verticalArrangement = Arrangement.spacedBy(FlashTokens.Spacing.XS),
        ) {
            item(key = "header") {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(vertical = FlashTokens.Spacing.SM),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Text(
                        "记录",
                        style = MaterialTheme.typography.headlineMedium,
                        color = MaterialTheme.colorScheme.onSurface,
                        modifier = Modifier.weight(1f),
                    )
                    Surface(
                        onClick = { searchFocus.requestFocus() },
                        shape = RoundedCornerShape(50),
                        color = MaterialTheme.colorScheme.surfaceContainerHigh,
                        modifier = Modifier.heightIn(min = FlashTokens.Touch.IconButtonMin),
                    ) {
                        Row(
                            modifier = Modifier.padding(
                                horizontal = FlashTokens.Spacing.MD,
                                vertical = FlashTokens.Spacing.XS,
                            ),
                            verticalAlignment = Alignment.CenterVertically,
                        ) {
                            Icon(
                                Icons.Filled.Search,
                                contentDescription = null,
                                tint = MaterialTheme.colorScheme.primary,
                                modifier = Modifier.size(18.dp),
                            )
                            Spacer(Modifier.width(6.dp))
                            Text("搜索", style = MaterialTheme.typography.labelLarge)
                        }
                    }
                    Spacer(Modifier.width(FlashTokens.Spacing.XS))
                    Surface(
                        onClick = { filterSheetOpen = true },
                        shape = RoundedCornerShape(50),
                        color = if (panel.isActive) {
                            MaterialTheme.colorScheme.primaryContainer
                        } else {
                            MaterialTheme.colorScheme.surfaceContainerHigh
                        },
                        modifier = Modifier.heightIn(min = FlashTokens.Touch.IconButtonMin),
                    ) {
                        Row(
                            modifier = Modifier.padding(
                                horizontal = FlashTokens.Spacing.MD,
                                vertical = FlashTokens.Spacing.XS,
                            ),
                            verticalAlignment = Alignment.CenterVertically,
                        ) {
                            Icon(
                                Icons.Filled.Tune,
                                contentDescription = null,
                                tint = MaterialTheme.colorScheme.primary,
                                modifier = Modifier.size(18.dp),
                            )
                            Spacer(Modifier.width(6.dp))
                            Text("筛选", style = MaterialTheme.typography.labelLarge)
                        }
                    }
                }
            }

            item(key = "search") {
                OutlinedTextField(
                    value = query,
                    onValueChange = viewModel::setQuery,
                    placeholder = { Text("输入关键词或标签") },
                    leadingIcon = {
                        Icon(
                            Icons.Filled.Search,
                            contentDescription = null,
                            tint = MaterialTheme.colorScheme.primary,
                        )
                    },
                    trailingIcon = if (query.isNotEmpty()) {
                        {
                            IconButton(onClick = { viewModel.setQuery("") }) {
                                Icon(Icons.Filled.Close, contentDescription = "清除搜索")
                            }
                        }
                    } else {
                        null
                    },
                    singleLine = true,
                    shape = RoundedCornerShape(28.dp),
                    colors = OutlinedTextFieldDefaults.colors(
                        focusedContainerColor = MaterialTheme.colorScheme.surfaceContainerHigh,
                        unfocusedContainerColor = MaterialTheme.colorScheme.surfaceContainerLow,
                    ),
                    modifier = Modifier
                        .fillMaxWidth()
                        .focusRequester(searchFocus),
                )
            }

            item(key = "summary") {
                Text(
                    summary,
                    style = MaterialTheme.typography.labelMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }

            item(key = "chips") {
                FlashFilterChipRow(
                    items = ExploreFilter.entries.map {
                        FlashFilterChipItem(it.name, it.displayName)
                    },
                    selectedKey = filter.name,
                    onSelect = { viewModel.setFilter(ExploreFilter.valueOf(it)) },
                )
            }

            if (filter == ExploreFilter.UNSORTED) {
                item(key = "inbox-help") {
                    Text(
                        "待整理：使用日常标签的日志。长按记录可批量整理。",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
            }

            item(key = "sort-header") {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Text(
                        if (newestFirst) "按最新记录" else "按最早记录",
                        style = MaterialTheme.typography.labelLarge,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        modifier = Modifier.weight(1f),
                    )
                    IconButton(onClick = viewModel::toggleSort) {
                        Icon(
                            Icons.AutoMirrored.Filled.Sort,
                            contentDescription = "切换排序",
                            tint = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                    }
                    TextButton(onClick = onOpenLogFlow) { Text("管理") }
                }
            }

            if (selecting) {
                item(key = "batch-bar") {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Text(
                            "已选 ${selection.size} 项",
                            style = MaterialTheme.typography.labelLarge,
                            modifier = Modifier.weight(1f),
                        )
                        TextButton(onClick = { batchDialog = BatchDialog.CATEGORY }) { Text("分类") }
                        TextButton(onClick = { batchDialog = BatchDialog.TAG }) { Text("标签") }
                        TextButton(onClick = viewModel::clearSelection) { Text("完成") }
                    }
                }
            }

            if (logs.isEmpty()) {
                item(key = "empty") {
                    FlashEmptyState(
                        title = if (anyFilterActive) "没有找到相关记录" else "闪过即留，写下第一条吧",
                        icon = Icons.Outlined.EditNote,
                        actionLabel = if (anyFilterActive) "清除筛选" else null,
                        onAction = if (anyFilterActive) {
                            { viewModel.clearFilters() }
                        } else {
                            null
                        },
                    )
                }
            } else {
                items(items = logs, key = { it.id }) { log ->
                    if (filter == ExploreFilter.UNSORTED) {
                        val selected = log.id in selection
                        Box(
                            Modifier
                                .animateItem()
                                .border(
                                    width = if (selected) 2.dp else 0.dp,
                                    color = if (selected) {
                                        MaterialTheme.colorScheme.primary
                                    } else {
                                        Color.Transparent
                                    },
                                    shape = RoundedCornerShape(FlashTokens.Radius.Card),
                                )
                                .combinedClickable(
                                    onClick = {
                                        if (selection.isNotEmpty()) {
                                            viewModel.toggleSelect(log.id)
                                        } else {
                                            onOpenRecord(log.id)
                                        }
                                    },
                                    onLongClick = { viewModel.toggleSelect(log.id) },
                                ),
                        ) {
                            RecordCard(
                                log = log,
                                showIdeaReminder = log.id in unviewedIdeaIds,
                            )
                        }
                    } else {
                        RecordCard(
                            log = log,
                            modifier = Modifier.animateItem(),
                            onClick = { onOpenRecord(log.id) },
                            onEdit = { onOpenRecord(log.id) },
                            showIdeaReminder = log.id in unviewedIdeaIds,
                        )
                    }
                }
            }
        }
    }

    if (filterSheetOpen) {
        ModalBottomSheet(
            onDismissRequest = { filterSheetOpen = false },
            shape = RoundedCornerShape(
                topStart = FlashTokens.Radius.Focus,
                topEnd = FlashTokens.Radius.Focus,
            ),
        ) {
            Column(
                modifier = Modifier.padding(
                    horizontal = FlashTokens.Spacing.LG,
                    vertical = FlashTokens.Spacing.MD,
                ),
                verticalArrangement = Arrangement.spacedBy(FlashTokens.Spacing.MD),
            ) {
                FlashFormSection(title = "类型") {
                    FlashFilterChipRow(
                        items = listOf(
                            FlashFilterChipItem(ExploreFilter.ALL.name, "全部"),
                            FlashFilterChipItem(ExploreFilter.LOG.name, "日志"),
                            FlashFilterChipItem(ExploreFilter.IDEA.name, "灵感"),
                        ),
                        selectedKey = when (filter) {
                            ExploreFilter.UNSORTED -> null
                            else -> filter.name
                        },
                        onSelect = { viewModel.setFilter(ExploreFilter.valueOf(it)) },
                    )
                }
                FlashFormSection(title = "标签") {
                    FlashFilterChipRow(
                        items = ColorTag.entries.map {
                            FlashFilterChipItem(it.name, it.displayName)
                        },
                        selectedKey = null,
                        onSelect = { viewModel.togglePanelTag(ColorTag.valueOf(it)) },
                    )
                    if (panel.tags.isNotEmpty()) {
                        Text(
                            "已选：${panel.tags.joinToString("、") { it.displayName }}",
                            style = MaterialTheme.typography.labelSmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                    }
                }
                FlashFormSection(title = "日期范围") {
                    DateRangeRow(
                        startDate = panel.startDate,
                        endDate = panel.endDate,
                        onStartChange = viewModel::setStartDate,
                        onEndChange = viewModel::setEndDate,
                    )
                }
                FlashFormSection(title = "重要度") {
                    FlashFilterChipRow(
                        items = IMPORTANCE_OPTIONS.map { (value, label) ->
                            FlashFilterChipItem(value.toString(), label)
                        },
                        selectedKey = panel.minImportance.toString(),
                        onSelect = { viewModel.setMinImportance(it.toInt()) },
                    )
                }
            }
        }
    }

    when (batchDialog) {
        BatchDialog.CATEGORY -> AlertDialog(
            onDismissRequest = { batchDialog = null },
            title = { Text("批量修改分类") },
            text = {
                Column {
                    TextButton(onClick = {
                        viewModel.batchSetCategory(Category.LOG)
                        batchDialog = null
                    }) { Text("日志") }
                    TextButton(onClick = {
                        viewModel.batchSetCategory(Category.IDEA)
                        batchDialog = null
                    }) { Text("灵感") }
                }
            },
            confirmButton = {},
            dismissButton = { TextButton(onClick = { batchDialog = null }) { Text("取消") } },
        )
        BatchDialog.TAG -> AlertDialog(
            onDismissRequest = { batchDialog = null },
            title = { Text("批量修改标签") },
            text = {
                Column {
                    ColorTag.entries.forEach { tag ->
                        TextButton(onClick = {
                            viewModel.batchSetTag(tag)
                            batchDialog = null
                        }) { Text(tag.displayName) }
                    }
                }
            },
            confirmButton = {},
            dismissButton = { TextButton(onClick = { batchDialog = null }) { Text("取消") } },
        )
        null -> Unit
    }
}

private enum class BatchDialog { CATEGORY, TAG }

@Composable
private fun DateRangeRow(
    startDate: String?,
    endDate: String?,
    onStartChange: (String?) -> Unit,
    onEndChange: (String?) -> Unit,
) {
    val context = LocalContext.current

    @Composable
    fun dateButton(label: String, value: String?, onChange: (String?) -> Unit) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            TextButton(
                onClick = {
                    val initial = runCatching { LocalDate.parse(value) }.getOrNull()
                        ?: LocalDate.now()
                    DatePickerDialog(
                        context,
                        { _, year, month, day ->
                            onChange(LocalDate.of(year, month + 1, day).toString())
                        },
                        initial.year,
                        initial.monthValue - 1,
                        initial.dayOfMonth,
                    ).show()
                },
            ) { Text("$label：${value ?: "不限"}") }
            if (value != null) {
                TextButton(onClick = { onChange(null) }) { Text("清除") }
            }
        }
    }

    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(FlashTokens.Spacing.SM),
    ) {
        dateButton("开始", startDate, onStartChange)
        dateButton("结束", endDate, onEndChange)
    }
}
