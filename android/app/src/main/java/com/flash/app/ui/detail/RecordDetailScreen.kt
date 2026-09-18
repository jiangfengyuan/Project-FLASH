// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package com.flash.app.ui.detail

import android.content.Intent
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.text.selection.SelectionContainer
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.Edit
import androidx.compose.material.icons.filled.Share
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.CenterAlignedTopAppBar
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import com.flash.app.FlashApplication
import com.flash.app.data.TextLimits
import com.flash.app.data.model.Category
import com.flash.app.data.model.ColorTag
import com.flash.app.data.model.LogItem
import com.flash.app.ui.components.FlashFilterChipItem
import com.flash.app.ui.components.FlashFilterChipRow
import com.flash.app.ui.components.FlashFormSection
import com.flash.app.ui.components.FlashSegmentedControl
import com.flash.app.ui.components.StyleCard
import com.flash.app.ui.theme.FlashTokens
import kotlinx.coroutines.launch

private val IMPORTANCE_OPTIONS = listOf(0 to "无", 2 to "!!", 3 to "!!!", 4 to "!!!!")

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun RecordDetailScreen(recordId: String, onBack: () -> Unit) {
    val context = LocalContext.current
    val app = context.applicationContext as FlashApplication
    val viewModel: RecordDetailViewModel = viewModel(
        key = recordId,
        factory = RecordDetailViewModel.factory(app.repository, recordId),
    )
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()
    val record = uiState.record
    val snackbar = remember { SnackbarHostState() }
    val scope = rememberCoroutineScope()
    var editing by remember { mutableStateOf(false) }
    var deleting by remember { mutableStateOf(false) }

    // 编辑态在顶层持有，顶部圆形保存按钮与表单共用同一份草稿
    var editContent by remember(record?.id, editing) { mutableStateOf(record?.content.orEmpty()) }
    var editTag by remember(record?.id, editing) {
        mutableStateOf(record?.colorTag ?: ColorTag.DAILY)
    }
    var editCategory by remember(record?.id, editing) {
        mutableStateOf(record?.category ?: Category.LOG)
    }
    var editImportance by remember(record?.id, editing) {
        mutableIntStateOf(record?.importance ?: 0)
    }
    // 超限不静默截断：允许继续输入，给出可见错误态并阻止保存（对齐 macOS TextLimits 行为）
    val editOverLimit = !TextLimits.fits(editContent)
    val editBlank = editContent.isBlank()

    LaunchedEffect(viewModel) {
        viewModel.events.collect { event ->
            when (event) {
                RecordDetailEvent.Saved -> {
                    editing = false
                    snackbar.showSnackbar("已保存")
                }
                RecordDetailEvent.Deleted -> onBack()
                is RecordDetailEvent.Failed -> snackbar.showSnackbar(event.message)
            }
        }
    }

    Scaffold(
        containerColor = Color.Transparent,
        snackbarHost = { SnackbarHost(snackbar) },
        topBar = {
            if (editing && record != null) {
                // 编辑态：圆形关闭 + 居中标题 + 圆形保存
                CenterAlignedTopAppBar(
                    title = { Text(if (record.category == Category.IDEA) "编辑灵感" else "编辑记录") },
                    colors = TopAppBarDefaults.topAppBarColors(containerColor = Color.Transparent),
                    navigationIcon = {
                        CircularIconButton(onClick = { editing = false }) {
                            Icon(Icons.Filled.Close, contentDescription = "关闭")
                        }
                    },
                    actions = {
                        CircularIconButton(
                            onClick = {
                                viewModel.save(editContent, editTag, editCategory, editImportance)
                            },
                            enabled = !editBlank && !editOverLimit && !uiState.busy,
                            emphasis = true,
                        ) {
                            Icon(Icons.Filled.Check, contentDescription = "保存")
                        }
                    },
                )
            } else {
                TopAppBar(
                    title = { Text(if (record?.category == Category.IDEA) "灵感详情" else "记录详情") },
                    colors = TopAppBarDefaults.topAppBarColors(containerColor = Color.Transparent),
                    navigationIcon = {
                        IconButton(onClick = onBack) {
                            Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "返回")
                        }
                    },
                    actions = {
                        if (record != null) {
                            IconButton(onClick = {
                                val intent = Intent(Intent.ACTION_SEND).apply {
                                    type = "text/plain"
                                    putExtra(
                                        Intent.EXTRA_SUBJECT,
                                        if (record.category == Category.IDEA) "Flash 灵感" else "Flash 记录",
                                    )
                                    putExtra(Intent.EXTRA_TEXT, record.content)
                                }
                                runCatching {
                                    context.startActivity(Intent.createChooser(intent, "分享记录"))
                                }.onFailure {
                                    scope.launch { snackbar.showSnackbar("没有可用的分享应用") }
                                }
                            }) {
                                Icon(Icons.Filled.Share, contentDescription = "分享")
                            }
                            IconButton(onClick = { editing = true }) {
                                Icon(Icons.Filled.Edit, contentDescription = "编辑")
                            }
                            IconButton(onClick = { deleting = true }) {
                                Icon(
                                    Icons.Filled.Delete,
                                    contentDescription = "删除",
                                    tint = MaterialTheme.colorScheme.error,
                                )
                            }
                        }
                    },
                )
            }
        },
    ) { innerPadding ->
        when {
            !uiState.loaded -> Column(
                modifier = Modifier.padding(innerPadding).fillMaxSize(),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.Center,
            ) { CircularProgressIndicator() }
            record == null -> Column(
                modifier = Modifier.padding(innerPadding).fillMaxSize().padding(24.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.Center,
            ) {
                Text("这条记录已不存在", style = MaterialTheme.typography.titleMedium)
                Spacer(Modifier.height(12.dp))
                TextButton(onClick = onBack) { Text("返回") }
            }
            else -> AnimatedContent(
                targetState = editing,
                transitionSpec = { fadeIn() togetherWith fadeOut() },
                label = "record-detail-mode",
                modifier = Modifier.padding(innerPadding),
            ) { isEditing ->
                if (isEditing) {
                    RecordEditor(
                        record = record,
                        content = editContent,
                        onContentChange = { editContent = it },
                        overLimit = editOverLimit,
                        blank = editBlank,
                        tag = editTag,
                        onTagChange = { editTag = it },
                        category = editCategory,
                        onCategoryChange = { editCategory = it },
                        importance = editImportance,
                        onImportanceChange = { editImportance = it },
                    )
                } else {
                    RecordViewer(record)
                }
            }
        }
    }

    if (deleting && record != null) {
        AlertDialog(
            onDismissRequest = { deleting = false },
            title = { Text("删除这条${if (record.category == Category.IDEA) "灵感" else "记录"}？") },
            text = { Text("删除后无法撤销。") },
            confirmButton = {
                TextButton(
                    enabled = !uiState.busy,
                    onClick = {
                        deleting = false
                        viewModel.delete()
                    },
                ) { Text("删除", color = MaterialTheme.colorScheme.error) }
            },
            dismissButton = { TextButton(onClick = { deleting = false }) { Text("取消") } },
        )
    }
}

/** 顶栏圆形按钮；emphasis 用于保存（主色实心） */
@Composable
private fun CircularIconButton(
    onClick: () -> Unit,
    enabled: Boolean = true,
    emphasis: Boolean = false,
    content: @Composable () -> Unit,
) {
    Surface(
        onClick = onClick,
        enabled = enabled,
        shape = CircleShape,
        color = when {
            emphasis && enabled -> MaterialTheme.colorScheme.primary
            emphasis -> MaterialTheme.colorScheme.surfaceContainerHigh
            else -> MaterialTheme.colorScheme.surfaceContainerHigh
        },
        contentColor = if (emphasis && enabled) {
            MaterialTheme.colorScheme.onPrimary
        } else {
            MaterialTheme.colorScheme.onSurfaceVariant
        },
        modifier = Modifier.size(FlashTokens.Touch.IconButtonMin),
    ) {
        Box(contentAlignment = Alignment.Center, modifier = Modifier.fillMaxSize()) { content() }
    }
}

@Composable
private fun RecordViewer(record: LogItem) {
    LazyColumn(
        modifier = Modifier.fillMaxSize(),
        contentPadding = PaddingValues(horizontal = 20.dp, vertical = 16.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        item {
            Row(
                horizontalArrangement = Arrangement.spacedBy(8.dp),
                modifier = Modifier.fillMaxWidth().horizontalScroll(rememberScrollState()),
            ) {
                MetadataChip(if (record.category == Category.IDEA) "灵感" else "日志")
                MetadataChip(record.colorTag.displayName)
                if (record.importance > 0) {
                    MetadataChip("!".repeat(record.importance))
                }
            }
        }
        item {
            StyleCard(modifier = Modifier.fillMaxWidth()) {
                SelectionContainer {
                    Text(record.content, style = MaterialTheme.typography.bodyLarge)
                }
            }
        }
        item {
            Text(
                "记录于 ${record.recordDate} · ${record.createdAt}",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
    }
}

@Composable
private fun MetadataChip(label: String) {
    Surface(
        shape = MaterialTheme.shapes.large,
        color = MaterialTheme.colorScheme.secondaryContainer,
        contentColor = MaterialTheme.colorScheme.onSecondaryContainer,
    ) {
        Text(
            label,
            style = MaterialTheme.typography.labelLarge,
            modifier = Modifier.padding(horizontal = 14.dp, vertical = 8.dp),
        )
    }
}

/** 编辑表单：分组白卡（第一组正文与类型 / 第二组标签、重要度、日期） */
@Composable
private fun RecordEditor(
    record: LogItem,
    content: String,
    onContentChange: (String) -> Unit,
    overLimit: Boolean,
    blank: Boolean,
    tag: ColorTag,
    onTagChange: (ColorTag) -> Unit,
    category: Category,
    onCategoryChange: (Category) -> Unit,
    importance: Int,
    onImportanceChange: (Int) -> Unit,
) {
    LazyColumn(
        modifier = Modifier.fillMaxSize(),
        contentPadding = PaddingValues(
            horizontal = FlashTokens.Spacing.PageHorizontal,
            vertical = FlashTokens.Spacing.SM,
        ),
        verticalArrangement = Arrangement.spacedBy(FlashTokens.Spacing.MD),
    ) {
        item {
            FlashFormSection(title = "内容") {
                StyleCard(modifier = Modifier.fillMaxWidth()) {
                    OutlinedTextField(
                        value = content,
                        onValueChange = onContentChange,
                        placeholder = { Text("记录此刻……") },
                        isError = overLimit || blank,
                        supportingText = {
                            when {
                                blank -> Text(
                                    "请输入内容",
                                    color = MaterialTheme.colorScheme.error,
                                )
                                else -> Text(
                                    "${content.length}/${TextLimits.MAX_CONTENT_LENGTH}",
                                    color = if (overLimit) {
                                        MaterialTheme.colorScheme.error
                                    } else {
                                        Color.Unspecified
                                    },
                                )
                            }
                        },
                        minLines = 6,
                        modifier = Modifier.fillMaxWidth(),
                    )
                    Spacer(Modifier.height(FlashTokens.Spacing.XS))
                    FlashSegmentedControl(
                        options = listOf(Category.LOG to "日志", Category.IDEA to "灵感"),
                        selected = category,
                        onSelect = onCategoryChange,
                    )
                }
            }
        }
        item {
            FlashFormSection(title = "属性") {
                StyleCard(modifier = Modifier.fillMaxWidth()) {
                    Text("标签", style = MaterialTheme.typography.labelLarge)
                    FlashFilterChipRow(
                        items = ColorTag.entries.map {
                            FlashFilterChipItem(it.name, it.displayName)
                        },
                        selectedKey = tag.name,
                        onSelect = { onTagChange(ColorTag.valueOf(it)) },
                    )
                    Spacer(Modifier.height(FlashTokens.Spacing.SM))
                    Text("重要度", style = MaterialTheme.typography.labelLarge)
                    FlashFilterChipRow(
                        items = IMPORTANCE_OPTIONS.map { (value, label) ->
                            FlashFilterChipItem(value.toString(), label)
                        },
                        selectedKey = importance.toString(),
                        onSelect = { onImportanceChange(it.toInt()) },
                    )
                    Spacer(Modifier.height(FlashTokens.Spacing.SM))
                    Text("日期", style = MaterialTheme.typography.labelLarge)
                    Text(
                        record.recordDate,
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
            }
        }
    }
}
