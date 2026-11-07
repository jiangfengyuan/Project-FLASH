// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package com.flash.app.ui.explore

import android.app.DatePickerDialog
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
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.rememberScrollState
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.Star
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.runtime.rememberCoroutineScope
import kotlinx.coroutines.launch
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

private val IMPORTANCE_OPTIONS get() = listOf(0 to com.flash.app.i18n.tr("全部"), 2 to "!!", 3 to "!!!", 4 to "!!!!")

/** 记录页（方案 §4.2）：大标题 + 搜索/筛选 → 统计摘要 → 筛选胶囊 → 记录列表 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ExploreScreen(
    onOpenLogFlow: () -> Unit,
    onOpenRecord: (String) -> Unit,
    presetIdeas: Boolean = false,
    onPresetConsumed: () -> Unit = {},
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

    val actions = com.flash.app.ui.navigation.LocalAppActions.current
    val haptics = com.flash.app.ui.components.rememberFlashHaptics()
    val scope = rememberCoroutineScope()
    var selectMode by remember { mutableStateOf(false) }
    // flash://ideas：打开灵感筛选
    LaunchedEffect(presetIdeas) {
        if (presetIdeas) {
            viewModel.setFilter(ExploreFilter.IDEA)
            onPresetConsumed()
        }
    }
    fun delete(log: com.flash.app.data.model.LogItem) {
        scope.launch {
            val undo = viewModel.deleteWithUndo(log) ?: return@launch
            haptics.light()
            actions.toast(com.flash.app.i18n.tr("已删除"), com.flash.app.i18n.tr("撤销"), undo)
        }
    }

    LaunchedEffect(viewModel) {
        viewModel.events.collect { event ->
            when (event) {
                is ExploreEvent.Failed -> snackbar.showSnackbar(event.message)
            }
        }
    }

    val selecting = filter == ExploreFilter.UNSORTED && (selectMode || selection.isNotEmpty())
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
                start = com.flash.app.ui.paper.pageGutter(),
                end = com.flash.app.ui.paper.pageGutter(),
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
                        com.flash.app.i18n.tr("记录"),
                        style = MaterialTheme.typography.headlineMedium,
                        color = MaterialTheme.colorScheme.onSurface,
                        modifier = Modifier.weight(1f),
                    )
                    IconButton(onClick = { filterSheetOpen = true }) {
                        Icon(
                            Icons.Filled.Tune,
                            contentDescription = com.flash.app.i18n.tr("筛选"),
                            tint = if (panel.isActive) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                    }
                    Box {
                        var addOpen by remember { mutableStateOf(false) }
                        IconButton(onClick = { addOpen = true }) {
                            Icon(Icons.Filled.Add, contentDescription = com.flash.app.i18n.tr("新建"), tint = MaterialTheme.colorScheme.primary)
                        }
                        DropdownMenu(expanded = addOpen, onDismissRequest = { addOpen = false }) {
                            DropdownMenuItem(text = { Text(com.flash.app.i18n.tr("新建记录")) }, onClick = { addOpen = false; actions.quickCapture(Category.LOG) })
                            DropdownMenuItem(text = { Text(com.flash.app.i18n.tr("新建灵感")) }, onClick = { addOpen = false; actions.quickCapture(Category.IDEA) })
                            DropdownMenuItem(text = { Text(com.flash.app.i18n.tr("日志流")) }, onClick = { addOpen = false; onOpenLogFlow() })
                            DropdownMenuItem(text = { Text(com.flash.app.i18n.tr("全局搜索")) }, onClick = { addOpen = false; actions.openSearch() })
                        }
                    }
                }
            }

            item(key = "search") {
                OutlinedTextField(
                    value = query,
                    onValueChange = viewModel::setQuery,
                    placeholder = { Text(com.flash.app.i18n.tr("输入关键词或标签")) },
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
                                Icon(Icons.Filled.Close, contentDescription = com.flash.app.i18n.tr("清除搜索"))
                            }
                        }
                    } else {
                        null
                    },
                    singleLine = true,
                    shape = RoundedCornerShape(FlashTokens.Radius.Field),
                    colors = OutlinedTextFieldDefaults.colors(
                        focusedContainerColor = MaterialTheme.colorScheme.surfaceVariant,
                        unfocusedContainerColor = MaterialTheme.colorScheme.surfaceVariant,
                        unfocusedBorderColor = MaterialTheme.colorScheme.outlineVariant,
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
                // 单选类型 + 可叠加的「已收藏」开关（对齐 iOS）
                Row(
                    Modifier.fillMaxWidth().horizontalScroll(rememberScrollState()),
                    horizontalArrangement = Arrangement.spacedBy(FlashTokens.Spacing.XS),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    ExploreFilter.entries.forEach { item ->
                        com.flash.app.ui.components.FlashFilterChip(
                            label = item.displayName,
                            selected = filter == item,
                            onClick = {
                                viewModel.setFilter(item)
                                haptics.selection()
                            },
                        )
                    }
                    com.flash.app.ui.paper.VerticalHandDivider("explore-chips", Modifier.height(24.dp))
                    com.flash.app.ui.components.FlashFilterChip(
                        label = com.flash.app.i18n.tr("★ 已收藏"),
                        selected = panel.favoritesOnly,
                        onClick = {
                            viewModel.toggleFavoritesOnly()
                            haptics.selection()
                        },
                    )
                }
            }

            if (filter == ExploreFilter.UNSORTED) {
                item(key = "inbox-help") {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Text(
                            com.flash.app.i18n.tr("待整理：使用日常标签的日志。长按记录可批量整理。"),
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                            modifier = Modifier.weight(1f),
                        )
                        TextButton(onClick = {
                            selectMode = !selectMode
                            if (!selectMode) viewModel.clearSelection()
                        }) { Text(if (selectMode) com.flash.app.i18n.tr("完成") else com.flash.app.i18n.tr("选择")) }
                    }
                }
            }

            item(key = "sort-header") {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Text(
                        if (newestFirst) com.flash.app.i18n.tr("按最新记录") else com.flash.app.i18n.tr("按最早记录"),
                        style = MaterialTheme.typography.labelLarge,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        modifier = Modifier.weight(1f),
                    )
                    IconButton(onClick = viewModel::toggleSort) {
                        Icon(
                            Icons.AutoMirrored.Filled.Sort,
                            contentDescription = com.flash.app.i18n.tr("切换排序"),
                            tint = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                    }
                    TextButton(onClick = onOpenLogFlow) { Text(com.flash.app.i18n.tr("管理")) }
                }
            }

            if (selecting) {
                item(key = "batch-bar") {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Text(
                            com.flash.app.i18n.tr("已选 {0} 项", selection.size),
                            style = MaterialTheme.typography.labelLarge,
                            modifier = Modifier.weight(1f),
                        )
                        TextButton(onClick = { batchDialog = BatchDialog.CATEGORY }) { Text(com.flash.app.i18n.tr("分类")) }
                        TextButton(onClick = { batchDialog = BatchDialog.TAG }) { Text(com.flash.app.i18n.tr("标签")) }
                        TextButton(onClick = {
                            selectMode = false
                            viewModel.clearSelection()
                        }) { Text(com.flash.app.i18n.tr("完成")) }
                    }
                }
            }

            if (logs.isEmpty()) {
                item(key = "empty") {
                    FlashEmptyState(
                        title = if (anyFilterActive) com.flash.app.i18n.tr("没有找到相关记录") else com.flash.app.i18n.tr("闪过即留，写下第一条吧"),
                        icon = Icons.Outlined.EditNote,
                        actionLabel = if (anyFilterActive) com.flash.app.i18n.tr("清除筛选") else null,
                        onAction = if (anyFilterActive) {
                            { viewModel.clearFilters() }
                        } else {
                            null
                        },
                    )
                }
            } else {
                items(items = logs, key = { it.id }) { log ->
                    if (selecting) {
                        RecordCard(
                            log = log,
                            modifier = Modifier.animateItem(),
                            isUnread = log.id in unviewedIdeaIds,
                            selected = log.id in selection,
                            onClick = { viewModel.toggleSelect(log.id) },
                            onLongClick = { viewModel.toggleSelect(log.id) },
                        )
                    } else {
                        SwipeableRecord(
                            log = log,
                            modifier = Modifier.animateItem(),
                            onFavorite = { viewModel.toggleFavorite(log) },
                            onDelete = { delete(log) },
                        ) {
                            RecordCard(
                                log = log,
                                onClick = { onOpenRecord(log.id) },
                                isUnread = log.id in unviewedIdeaIds,
                                onLongClick = if (filter == ExploreFilter.UNSORTED) {
                                    { viewModel.toggleSelect(log.id) }
                                } else {
                                    null
                                },
                                menu = com.flash.app.ui.components.RecordMenu(
                                    onEdit = { onOpenRecord(log.id) },
                                    onToggleFavorite = { viewModel.toggleFavorite(log) },
                                    onConvertToTask = { actions.newTaskFromIdea(log.id, log.content) },
                                    onDelete = { delete(log) },
                                ),
                            )
                        }
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
                FlashFormSection(title = com.flash.app.i18n.tr("类型")) {
                    FlashFilterChipRow(
                        items = listOf(
                            FlashFilterChipItem(ExploreFilter.ALL.name, com.flash.app.i18n.tr("全部")),
                            FlashFilterChipItem(ExploreFilter.LOG.name, com.flash.app.i18n.tr("日志")),
                            FlashFilterChipItem(ExploreFilter.IDEA.name, com.flash.app.i18n.tr("灵感")),
                        ),
                        selectedKey = when (filter) {
                            ExploreFilter.UNSORTED -> null
                            else -> filter.name
                        },
                        onSelect = { viewModel.setFilter(ExploreFilter.valueOf(it)) },
                    )
                }
                FlashFormSection(title = com.flash.app.i18n.tr("标签")) {
                    Row(
                        Modifier.horizontalScroll(rememberScrollState()),
                        horizontalArrangement = Arrangement.spacedBy(FlashTokens.Spacing.XS),
                    ) {
                        ColorTag.entries.forEach { tag ->
                            com.flash.app.ui.components.FlashFilterChip(
                                label = tag.displayName,
                                selected = tag in panel.tags,
                                onClick = { viewModel.togglePanelTag(tag) },
                            )
                        }
                    }
                }
                FlashFormSection(title = com.flash.app.i18n.tr("日期范围")) {
                    DateRangeRow(
                        startDate = panel.startDate,
                        endDate = panel.endDate,
                        onStartChange = viewModel::setStartDate,
                        onEndChange = viewModel::setEndDate,
                    )
                }
                FlashFormSection(title = com.flash.app.i18n.tr("重要度")) {
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
            title = { Text(com.flash.app.i18n.tr("批量修改分类")) },
            text = {
                Column {
                    TextButton(onClick = {
                        viewModel.batchSetCategory(Category.LOG)
                        batchDialog = null
                    }) { Text(com.flash.app.i18n.tr("日志")) }
                    TextButton(onClick = {
                        viewModel.batchSetCategory(Category.IDEA)
                        batchDialog = null
                    }) { Text(com.flash.app.i18n.tr("灵感")) }
                }
            },
            confirmButton = {},
            dismissButton = { TextButton(onClick = { batchDialog = null }) { Text(com.flash.app.i18n.tr("取消")) } },
        )
        BatchDialog.TAG -> AlertDialog(
            onDismissRequest = { batchDialog = null },
            title = { Text(com.flash.app.i18n.tr("批量修改标签")) },
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
            dismissButton = { TextButton(onClick = { batchDialog = null }) { Text(com.flash.app.i18n.tr("取消")) } },
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
            ) { Text(com.flash.app.i18n.tr("{0}：{1}", label, value ?: "不限")) }
            if (value != null) {
                TextButton(onClick = { onChange(null) }) { Text(com.flash.app.i18n.tr("清除")) }
            }
        }
    }

    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(FlashTokens.Spacing.SM),
    ) {
        dateButton(com.flash.app.i18n.tr("开始"), startDate, onStartChange)
        dateButton(com.flash.app.i18n.tr("结束"), endDate, onEndChange)
    }
}

/** 轻扫：起始方向切换收藏（不移除），结束方向删除。从右到左时方向随布局翻转 */
@OptIn(androidx.compose.material3.ExperimentalMaterial3Api::class)
@Composable
private fun SwipeableRecord(
    log: com.flash.app.data.model.LogItem,
    modifier: Modifier = Modifier,
    onFavorite: () -> Unit,
    onDelete: () -> Unit,
    content: @Composable () -> Unit,
) {
    val state = androidx.compose.material3.rememberSwipeToDismissBoxState(
        confirmValueChange = { value ->
            when (value) {
                androidx.compose.material3.SwipeToDismissBoxValue.StartToEnd -> {
                    onFavorite()
                    false
                }
                androidx.compose.material3.SwipeToDismissBoxValue.EndToStart -> {
                    onDelete()
                    false
                }
                else -> true
            }
        },
    )
    androidx.compose.material3.SwipeToDismissBox(
        state = state,
        modifier = modifier,
        backgroundContent = {
            val direction = state.dismissDirection
            val isFavorite = direction == androidx.compose.material3.SwipeToDismissBoxValue.StartToEnd
            val isDelete = direction == androidx.compose.material3.SwipeToDismissBoxValue.EndToStart
            Box(
                Modifier
                    .fillMaxSize()
                    .padding(horizontal = FlashTokens.Spacing.LG),
                contentAlignment = if (isDelete) Alignment.CenterEnd else Alignment.CenterStart,
            ) {
                when {
                    isFavorite -> Icon(
                        Icons.Filled.Star,
                        contentDescription = if (log.isFavorite == true) com.flash.app.i18n.tr("取消收藏") else com.flash.app.i18n.tr("收藏"),
                        tint = com.flash.app.ui.theme.ModuleColors.IdeaText,
                    )
                    isDelete -> Icon(
                        Icons.Filled.Delete,
                        contentDescription = com.flash.app.i18n.tr("删除"),
                        tint = MaterialTheme.colorScheme.error,
                    )
                }
            }
        },
    ) { content() }
}
