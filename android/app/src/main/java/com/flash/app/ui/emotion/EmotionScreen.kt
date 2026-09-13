// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package com.flash.app.ui.emotion

import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.scaleIn
import androidx.compose.animation.scaleOut
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilterChip
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.ListItem
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.derivedStateOf
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import com.flash.app.FlashApplication
import com.flash.app.data.model.EmotionLevel
import com.flash.app.data.model.EmotionRecord
import com.flash.app.data.model.SubEmotion
import com.flash.app.data.model.emoji
import com.flash.app.ui.components.StyleCard
import com.flash.app.ui.components.hexToColor
import com.flash.app.ui.theme.ModuleColors

/** 情绪页（PRD 7.4 / 效果图）：emoji 选择器 + 简短文字 + 周趋势 + 历史 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun EmotionScreen(onBack: () -> Unit) {
    val app = LocalContext.current.applicationContext as FlashApplication
    val viewModel: EmotionViewModel = viewModel(factory = EmotionViewModel.factory(app.repository))
    val emotions by viewModel.emotions.collectAsStateWithLifecycle()
    val statsEmotions by viewModel.statsEmotions.collectAsStateWithLifecycle()
    val hasMoreHistory by viewModel.hasMoreHistory.collectAsStateWithLifecycle()
    var deletingRecord by remember { mutableStateOf<EmotionRecord?>(null) }
    val snackbar = remember { SnackbarHostState() }

    LaunchedEffect(viewModel) {
        viewModel.events.collect { event ->
            when (event) {
                is EmotionEvent.Failed -> snackbar.showSnackbar(event.message)
            }
        }
    }

    Scaffold(
        containerColor = Color.Transparent,
        snackbarHost = { SnackbarHost(snackbar) },
        topBar = {
            TopAppBar(
                title = { Text("情绪记录") },
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
                .fillMaxSize()
                .padding(horizontal = 16.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Spacer(Modifier.height(8.dp))
            // 当前选中情绪大展示
            StyleCard(modifier = Modifier.fillMaxWidth()) {
                Column(
                    horizontalAlignment = Alignment.CenterHorizontally,
                    modifier = Modifier.fillMaxWidth(),
                ) {
                    AnimatedContent(
                        targetState = viewModel.selectedLevel,
                        transitionSpec = {
                            (scaleIn(tween(220)) + fadeIn(tween(220)))
                                .togetherWith(scaleOut(tween(180)) + fadeOut(tween(180)))
                        },
                        label = "emojiSwap",
                    ) { level ->
                        Text(level.emoji, fontSize = 96.sp)
                    }
                    Text(
                        viewModel.selectedLevel.displayName,
                        style = MaterialTheme.typography.headlineMedium,
                    )
                }
            }
            Spacer(Modifier.height(16.dp))
            Text(
                "此刻的心情是...",
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.align(Alignment.Start),
            )
            Spacer(Modifier.height(8.dp))
            EmojiSelector(
                selected = viewModel.selectedLevel,
                onSelect = viewModel::selectLevel,
            )
            Spacer(Modifier.height(12.dp))
            if (viewModel.selectedLevel.isNegative) {
                SubEmotionSelector(
                    selected = viewModel.selectedSubEmotion,
                    onSelect = viewModel::selectSubEmotion,
                )
                Spacer(Modifier.height(12.dp))
            }
            OutlinedTextField(
                value = viewModel.note,
                onValueChange = viewModel::updateNote,
                label = { Text("想说点什么？（可选）") },
                singleLine = true,
                modifier = Modifier.fillMaxWidth(),
            )
            Spacer(Modifier.height(12.dp))
            Button(
                onClick = viewModel::save,
                enabled = !viewModel.saving,
                colors = ButtonDefaults.buttonColors(containerColor = ModuleColors.Emotion),
                modifier = Modifier.fillMaxWidth(),
            ) {
                Text("记录当下")
            }
            Spacer(Modifier.height(16.dp))
            HorizontalDivider()
            Spacer(Modifier.height(8.dp))
            Text(
                "统计与历史",
                style = MaterialTheme.typography.titleMedium,
                modifier = Modifier.align(Alignment.Start),
            )
            Spacer(Modifier.height(8.dp))
            val listState = rememberLazyListState()
            // 滑到接近底部时增量加载下一页（DAO LIMIT 随 limit 增大）
            val shouldLoadMore by remember {
                derivedStateOf {
                    val info = listState.layoutInfo
                    val lastVisible = info.visibleItemsInfo.lastOrNull()?.index ?: 0
                    info.totalItemsCount > 0 && lastVisible >= info.totalItemsCount - 3
                }
            }
            LaunchedEffect(shouldLoadMore) {
                if (shouldLoadMore) viewModel.loadMoreHistory()
            }
            LazyColumn(
                state = listState,
                modifier = Modifier.weight(1f),
                verticalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                item(key = "stats") {
                    // 情绪页对应 macOS「本周趋势」：短档用周一对齐自然周
                    EmotionStatsSection(emotions = statsEmotions, weekAligned = true)
                }
                items(items = emotions, key = { it.id }) { record ->
                    Column(modifier = Modifier.animateItem()) {
                        EmotionRow(record, onDelete = { deletingRecord = record })
                        HorizontalDivider(thickness = 0.5.dp)
                    }
                }
                if (hasMoreHistory) {
                    item(key = "loading") {
                        Text(
                            "正在加载更多…",
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                            modifier = Modifier.fillMaxWidth().padding(vertical = 12.dp),
                        )
                    }
                }
            }
        }
    }

    deletingRecord?.let { record ->
        AlertDialog(
            onDismissRequest = { deletingRecord = null },
            title = { Text("删除这条情绪记录？") },
            text = { Text("${record.recordDate} · ${record.level.displayName}") },
            confirmButton = {
                TextButton(onClick = {
                    viewModel.delete(record)
                    deletingRecord = null
                }) {
                    Text("删除", color = MaterialTheme.colorScheme.error)
                }
            },
            dismissButton = {
                TextButton(onClick = { deletingRecord = null }) { Text("取消") }
            },
        )
    }
}

/** 负面情绪子类型选择器（伤心/生气/难受） */
@Composable
private fun SubEmotionSelector(
    selected: SubEmotion?,
    onSelect: (SubEmotion?) -> Unit,
) {
    Row(
        horizontalArrangement = Arrangement.spacedBy(8.dp),
        modifier = Modifier.fillMaxWidth(),
    ) {
        SubEmotion.entries.forEach { sub ->
            val isSelected = selected == sub
            FilterChip(
                selected = isSelected,
                onClick = { onSelect(if (isSelected) null else sub) },
                label = { Text(sub.displayName) },
                leadingIcon = {
                    Box(
                        modifier = Modifier
                            .size(10.dp)
                            .background(
                                color = sub.colorHex.hexToColor(),
                                shape = CircleShape,
                            ),
                    )
                },
                modifier = Modifier.weight(1f),
            )
        }
    }
}

/** 七档 emoji 选择器（😍😊🙂😐😔😣😡，对应 level 3→-3） */
@Composable
private fun EmojiSelector(selected: EmotionLevel, onSelect: (EmotionLevel) -> Unit) {
    Row(
        horizontalArrangement = Arrangement.spacedBy(6.dp),
        modifier = Modifier
            .fillMaxWidth()
            .horizontalScroll(rememberScrollState()),
    ) {
        EmotionLevel.entries.sortedByDescending { it.value }.forEach { level ->
            val isSelected = level == selected
            Column(
                horizontalAlignment = Alignment.CenterHorizontally,
                modifier = Modifier
                    .clip(CircleShape)
                    .background(
                        if (isSelected) {
                            MaterialTheme.colorScheme.primaryContainer
                        } else {
                            Color.Transparent
                        },
                    )
                    .clickable { onSelect(level) }
                    .padding(horizontal = 8.dp, vertical = 6.dp),
            ) {
                Text(level.emoji, fontSize = if (isSelected) 34.sp else 28.sp)
                Text(
                    level.displayName,
                    style = MaterialTheme.typography.labelSmall,
                    color = if (isSelected) {
                        MaterialTheme.colorScheme.onSurface
                    } else {
                        MaterialTheme.colorScheme.onSurfaceVariant
                    },
                )
            }
        }
    }
}

@Composable
private fun EmotionRow(record: EmotionRecord, onDelete: () -> Unit) {
    ListItem(
        leadingContent = {
            Text(record.level.emoji, fontSize = 24.sp)
        },
        headlineContent = {
            Text(record.level.displayName)
        },
        supportingContent = {
            val note = record.note?.takeIf { it.isNotBlank() }
            Text(listOfNotNull(record.recordDate, note).joinToString("  "))
        },
        trailingContent = {
            IconButton(onClick = onDelete) {
                Icon(
                    Icons.Filled.Delete,
                    contentDescription = "删除",
                    tint = MaterialTheme.colorScheme.error,
                )
            }
        },
    )
}
