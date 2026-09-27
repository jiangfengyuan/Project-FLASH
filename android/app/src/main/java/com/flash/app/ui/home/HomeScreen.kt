// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package com.flash.app.ui.home

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.Send
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.filled.Lightbulb
import androidx.compose.material.icons.filled.Search
import androidx.compose.material.icons.filled.Tune
import androidx.compose.material.icons.outlined.EditNote
import androidx.compose.material3.AlertDialog
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
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.draw.clip
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import com.flash.app.FlashApplication
import com.flash.app.data.model.Category
import com.flash.app.data.model.EmotionRecord
import com.flash.app.data.model.emoji
import com.flash.app.domain.shouldShowIdeaReminder
import com.flash.app.ui.components.FlashEmptyState
import com.flash.app.ui.components.FlashSegmentedControl
import com.flash.app.ui.components.MAX_QUICK_INPUT_LENGTH
import com.flash.app.ui.components.RecordCard
import com.flash.app.ui.components.StyleCard
import com.flash.app.ui.theme.FlashTokens
import com.flash.app.ui.theme.ModuleColors
import java.time.LocalDate
import java.time.format.DateTimeFormatter
import java.util.Locale

private val DATE_SUBTITLE_FORMAT: DateTimeFormatter =
    DateTimeFormatter.ofPattern("EEEE，M 月 d 日", Locale.CHINESE)

/** 此刻页（方案 §4.1）：标题+搜索筛选胶囊 → 今日一览 → 快速捕捉 → 最近闪念 */
@Composable
fun HomeScreen(
    onOpenSearch: () -> Unit,
    onOpenRecord: (String) -> Unit,
) {
    val app = LocalContext.current.applicationContext as FlashApplication
    val viewModel: HomeViewModel = viewModel(factory = HomeViewModel.factory(app.repository))
    val ui by viewModel.uiState.collectAsStateWithLifecycle()
    val snackbar = remember { SnackbarHostState() }
    val captureFocus = remember { FocusRequester() }
    var captureText by remember { mutableStateOf("") }
    var captureCategory by remember { mutableStateOf(Category.LOG) }
    var deletingId by remember { mutableStateOf<String?>(null) }
    val captureOverLimit = captureText.length > MAX_QUICK_INPUT_LENGTH
    val stackHeaderActions = LocalDensity.current.fontScale > 1.2f

    LaunchedEffect(viewModel) {
        viewModel.events.collect { event ->
            when (event) {
                HomeEvent.Saved -> {
                    captureText = ""
                    snackbar.showSnackbar("已保存")
                }
                is HomeEvent.Failed -> snackbar.showSnackbar(event.message)
            }
        }
    }

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
            verticalArrangement = Arrangement.spacedBy(FlashTokens.Spacing.SM),
        ) {
            item(key = "header") {
                // 仅此页顶部允许极克制的蓝紫光晕，向下消散为底色
                Box(
                    Modifier
                        .fillMaxWidth()
                        .clip(RoundedCornerShape(FlashTokens.Radius.Card))
                        .background(
                            Brush.verticalGradient(
                                listOf(
                                    Color(0xFF6C5CE7).copy(alpha = 0.10f),
                                    Color(0xFF4D96FF).copy(alpha = 0.04f),
                                    Color.Transparent,
                                ),
                            ),
                        )
                        .padding(vertical = FlashTokens.Spacing.SM),
                ) {
                    Column {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Column(Modifier.weight(1f)) {
                            Text(
                                "此刻",
                                style = MaterialTheme.typography.headlineMedium,
                                color = MaterialTheme.colorScheme.onSurface,
                            )
                            Spacer(Modifier.height(4.dp))
                            Text(
                                LocalDate.now().format(DATE_SUBTITLE_FORMAT),
                                style = MaterialTheme.typography.bodyMedium,
                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                            )
                        }
                        if (!stackHeaderActions) {
                            HeaderCapsule("搜索", Icons.Filled.Search, onOpenSearch)
                            Spacer(Modifier.width(FlashTokens.Spacing.XS))
                            HeaderCapsule("筛选", Icons.Filled.Tune, onOpenSearch)
                        }
                    }
                    if (stackHeaderActions) {
                        Spacer(Modifier.height(FlashTokens.Spacing.XS))
                        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.End) {
                            HeaderCapsule("搜索", Icons.Filled.Search, onOpenSearch)
                            Spacer(Modifier.width(FlashTokens.Spacing.XS))
                            HeaderCapsule("筛选", Icons.Filled.Tune, onOpenSearch)
                        }
                    }
                    }
                }
            }

            item(key = "today") {
                TodayCard(ui = ui, modifier = Modifier.fillMaxWidth())
            }

            item(key = "capture") {
                StyleCard(modifier = Modifier.fillMaxWidth()) {
                    OutlinedTextField(
                        value = captureText,
                        onValueChange = { captureText = it },
                        placeholder = { Text("写下刚刚闪过的念头……") },
                        isError = captureOverLimit,
                        supportingText = {
                            if (captureOverLimit) {
                                Text(
                                    "超出长度限制（${captureText.length}/$MAX_QUICK_INPUT_LENGTH）",
                                    color = MaterialTheme.colorScheme.error,
                                )
                            }
                        },
                        minLines = 2,
                        shape = RoundedCornerShape(FlashTokens.Radius.Card),
                        modifier = Modifier
                            .fillMaxWidth()
                            .focusRequester(captureFocus),
                    )
                    Spacer(Modifier.height(FlashTokens.Spacing.XS))
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        FlashSegmentedControl(
                            options = listOf(Category.LOG to "日志", Category.IDEA to "灵感"),
                            selected = captureCategory,
                            onSelect = { captureCategory = it },
                            modifier = Modifier.weight(1f),
                        )
                        Spacer(Modifier.width(FlashTokens.Spacing.SM))
                        IconButton(
                            onClick = { viewModel.quickAdd(captureText, captureCategory) },
                            enabled = captureText.isNotBlank() && !captureOverLimit,
                        ) {
                            Icon(
                                Icons.AutoMirrored.Filled.Send,
                                contentDescription = "保存",
                                tint = if (captureText.isNotBlank() && !captureOverLimit) {
                                    MaterialTheme.colorScheme.primary
                                } else {
                                    MaterialTheme.colorScheme.onSurfaceVariant
                                },
                            )
                        }
                    }
                }
            }

            if (shouldShowIdeaReminder(ui.unviewedIdeaCount)) {
                item(key = "idea-reminder") {
                    StyleCard(
                        modifier = Modifier.fillMaxWidth(),
                        onClick = {
                            ui.oldestUnviewedIdeaId?.let(onOpenRecord)
                        },
                    ) {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Icon(
                                Icons.Filled.Lightbulb,
                                contentDescription = null,
                                tint = ModuleColors.Idea,
                                modifier = Modifier.size(28.dp),
                            )
                            Spacer(Modifier.width(12.dp))
                            Column(Modifier.weight(1f)) {
                                Text("想法等待梳理", style = MaterialTheme.typography.titleSmall)
                                Text(
                                    "你还有 ${ui.unviewedIdeaCount} 个想法，先看看最早的一条",
                                    style = MaterialTheme.typography.bodySmall,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                                )
                            }
                            Text(
                                "${ui.unviewedIdeaCount}",
                                style = MaterialTheme.typography.titleMedium,
                                color = MaterialTheme.colorScheme.onSurface,
                            )
                        }
                    }
                }
            }

            item(key = "recent-header") {
                Text(
                    "最近闪念",
                    style = MaterialTheme.typography.titleMedium,
                    color = MaterialTheme.colorScheme.onSurface,
                    modifier = Modifier.padding(top = FlashTokens.Spacing.XS),
                )
            }
            items(items = ui.recentLogs, key = { it.id }) { log ->
                RecordCard(
                    log = log,
                    modifier = Modifier.animateItem(),
                    onClick = { onOpenRecord(log.id) },
                    onEdit = { onOpenRecord(log.id) },
                    onDelete = { deletingId = log.id },
                )
            }
            if (ui.recentLogs.isEmpty()) {
                item(key = "empty") {
                    FlashEmptyState(
                        title = "今天还没有记录。",
                        icon = Icons.Outlined.EditNote,
                        actionLabel = "记下第一个念头",
                        onAction = { captureFocus.requestFocus() },
                    )
                }
            }
        }
    }

    deletingId?.let { id ->
        AlertDialog(
            onDismissRequest = { deletingId = null },
            title = { Text("删除这条记录？") },
            text = { Text("删除后无法撤销。") },
            confirmButton = {
                TextButton(
                    onClick = {
                        deletingId = null
                        viewModel.deleteLog(id)
                    },
                ) { Text("删除", color = MaterialTheme.colorScheme.error) }
            },
            dismissButton = { TextButton(onClick = { deletingId = null }) { Text("取消") } },
        )
    }
}

/** 顶部右侧搜索/筛选组合胶囊（触控高 44） */
@Composable
private fun HeaderCapsule(label: String, icon: ImageVector, onClick: () -> Unit) {
    Surface(
        onClick = onClick,
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
                icon,
                contentDescription = null,
                tint = MaterialTheme.colorScheme.primary,
                modifier = Modifier.size(18.dp),
            )
            Spacer(Modifier.width(6.dp))
            Text(label, style = MaterialTheme.typography.labelLarge)
        }
    }
}

/** 今日一览卡：今天的片段 + 两项主数据 + 情绪/已完成任务状态条 */
@Composable
private fun TodayCard(ui: HomeUiState, modifier: Modifier = Modifier) {
    StyleCard(modifier = modifier) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(
                "今天的片段",
                style = MaterialTheme.typography.titleSmall,
                modifier = Modifier.weight(1f),
            )
            Surface(
                shape = RoundedCornerShape(50),
                color = MaterialTheme.colorScheme.surfaceContainerHigh,
            ) {
                Text(
                    LocalDate.now().format(DateTimeFormatter.ofPattern("M/d")),
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.padding(horizontal = 10.dp, vertical = 4.dp),
                )
            }
        }
        Spacer(Modifier.height(FlashTokens.Spacing.SM))
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceEvenly,
        ) {
            TodayStat("${ui.todayRecordCount}", "今日记录")
            TodayStat("${ui.todayTaskCount}", "待办")
        }
        Spacer(Modifier.height(FlashTokens.Spacing.SM))
        if (ui.todayRecordCount == 0 && ui.todayEmotionCount == 0 && ui.todayDoneTaskCount == 0) {
            Text(
                "今天可以从一个念头开始",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        } else {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Icon(
                    Icons.Filled.Favorite,
                    contentDescription = null,
                    tint = ModuleColors.Emotion,
                    modifier = Modifier.size(16.dp),
                )
                Spacer(Modifier.width(6.dp))
                Text(
                    emotionStatus(ui.latestEmotion),
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
                Spacer(Modifier.width(FlashTokens.Spacing.MD))
                Icon(
                    Icons.Filled.CheckCircle,
                    contentDescription = null,
                    tint = ModuleColors.Calendar,
                    modifier = Modifier.size(16.dp),
                )
                Spacer(Modifier.width(6.dp))
                Text(
                    "已完成 ${ui.todayDoneTaskCount} 项任务",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
        }
    }
}

private fun emotionStatus(latest: EmotionRecord?): String =
    if (latest == null) "还没有记录情绪" else "当前情绪 ${latest.level.emoji} ${latest.level.displayName}"

@Composable
private fun TodayStat(value: String, label: String) {
    Column(horizontalAlignment = Alignment.CenterHorizontally) {
        Text(value, style = MaterialTheme.typography.titleLarge)
        Text(
            label,
            style = MaterialTheme.typography.labelSmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
    }
}
