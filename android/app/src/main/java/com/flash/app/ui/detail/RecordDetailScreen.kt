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
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.selection.SelectionContainer
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.Edit
import androidx.compose.material.icons.filled.Share
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilterChip
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SegmentedButton
import androidx.compose.material3.SegmentedButtonDefaults
import androidx.compose.material3.SingleChoiceSegmentedButtonRow
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
import com.flash.app.data.Backup
import com.flash.app.data.model.Category
import com.flash.app.data.model.ColorTag
import com.flash.app.data.model.LogItem
import com.flash.app.ui.components.StyleCard
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
            TopAppBar(
                title = { Text(if (record?.category == Category.IDEA) "灵感详情" else "记录详情") },
                colors = TopAppBarDefaults.topAppBarColors(containerColor = Color.Transparent),
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "返回")
                    }
                },
                actions = {
                    if (record != null && !editing) {
                        IconButton(onClick = {
                            val intent = Intent(Intent.ACTION_SEND).apply {
                                type = "text/plain"
                                putExtra(Intent.EXTRA_SUBJECT, if (record.category == Category.IDEA) "Flash 灵感" else "Flash 记录")
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
                            Icon(Icons.Filled.Delete, contentDescription = "删除", tint = MaterialTheme.colorScheme.error)
                        }
                    }
                },
            )
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
                        busy = uiState.busy,
                        onCancel = { editing = false },
                        onSave = viewModel::save,
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

@Composable
private fun RecordEditor(
    record: LogItem,
    busy: Boolean,
    onCancel: () -> Unit,
    onSave: (String, ColorTag, Category, Int) -> Unit,
) {
    var content by remember(record.id, record.content) { mutableStateOf(record.content) }
    var tag by remember(record.id, record.colorTag) { mutableStateOf(record.colorTag) }
    var category by remember(record.id, record.category) { mutableStateOf(record.category) }
    var importance by remember(record.id, record.importance) { mutableIntStateOf(record.importance) }

    LazyColumn(
        modifier = Modifier.fillMaxSize(),
        contentPadding = PaddingValues(horizontal = 20.dp, vertical = 12.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        item {
            OutlinedTextField(
                value = content,
                onValueChange = { content = it.take(Backup.MAX_FIELD_LENGTH) },
                label = { Text("内容") },
                supportingText = { Text("${content.length}/${Backup.MAX_FIELD_LENGTH}") },
                minLines = 8,
                modifier = Modifier.fillMaxWidth(),
            )
        }
        item {
            Text("分类", style = MaterialTheme.typography.titleSmall)
            SingleChoiceSegmentedButtonRow(modifier = Modifier.fillMaxWidth()) {
                Category.entries.forEachIndexed { index, item ->
                    SegmentedButton(
                        selected = category == item,
                        onClick = { category = item },
                        shape = SegmentedButtonDefaults.itemShape(index, Category.entries.size),
                    ) { Text(if (item == Category.LOG) "日志" else "灵感") }
                }
            }
        }
        item {
            Text("标签", style = MaterialTheme.typography.titleSmall)
            Row(
                horizontalArrangement = Arrangement.spacedBy(8.dp),
                modifier = Modifier.fillMaxWidth().horizontalScroll(rememberScrollState()),
            ) {
                ColorTag.entries.forEach { item ->
                    FilterChip(selected = tag == item, onClick = { tag = item }, label = { Text(item.displayName) })
                }
            }
        }
        item {
            Text("重要度", style = MaterialTheme.typography.titleSmall)
            Row(
                horizontalArrangement = Arrangement.spacedBy(8.dp),
                modifier = Modifier.fillMaxWidth().horizontalScroll(rememberScrollState()),
            ) {
                IMPORTANCE_OPTIONS.forEach { (value, label) ->
                    FilterChip(selected = importance == value, onClick = { importance = value }, label = { Text(label) })
                }
            }
        }
        item {
            Row(horizontalArrangement = Arrangement.spacedBy(12.dp), modifier = Modifier.fillMaxWidth()) {
                TextButton(onClick = onCancel, enabled = !busy, modifier = Modifier.weight(1f)) { Text("取消") }
                Button(
                    onClick = { onSave(content, tag, category, importance) },
                    enabled = content.isNotBlank() && !busy,
                    modifier = Modifier.weight(1f),
                ) { Text(if (busy) "保存中…" else "保存") }
            }
        }
    }
}
