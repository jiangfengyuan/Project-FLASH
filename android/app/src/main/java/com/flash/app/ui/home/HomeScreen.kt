// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package com.flash.app.ui.home

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.MenuBook
import androidx.compose.material.icons.filled.CalendarMonth
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.filled.Lightbulb
import androidx.compose.material.icons.filled.Search
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import com.flash.app.FlashApplication
import com.flash.app.data.model.emoji
import com.flash.app.domain.shouldShowIdeaReminder
import com.flash.app.ui.components.LogCard
import com.flash.app.ui.components.StyleCard
import com.flash.app.ui.theme.ModuleColors
import java.time.LocalTime

/** 首页（PRD 08）：问候 → 四模块卡 → 今日概览 → 最近记录；快速创建入口在全局 Dock 右侧 FAB */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun HomeScreen(
    onOpenExplore: () -> Unit,
    onOpenSearch: () -> Unit,
    onOpenCalendar: () -> Unit,
    onOpenEmotion: () -> Unit,
    onOpenRecord: (String) -> Unit,
) {
    val app = LocalContext.current.applicationContext as FlashApplication
    val viewModel: HomeViewModel = viewModel(factory = HomeViewModel.factory(app.repository))
    val ui by viewModel.uiState.collectAsStateWithLifecycle()

    Scaffold(
        containerColor = Color.Transparent,
    ) { innerPadding ->
        LazyColumn(
            modifier = Modifier
                .padding(innerPadding)
                .fillMaxSize(),
            contentPadding = PaddingValues(horizontal = 16.dp, vertical = 8.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            item(key = "greeting") {
                Column(modifier = Modifier.padding(vertical = 12.dp)) {
                    Text(
                        "${greeting()} 👋",
                        style = MaterialTheme.typography.headlineMedium,
                        color = MaterialTheme.colorScheme.onSurface,
                    )
                    Spacer(Modifier.height(4.dp))
                    Text(
                        "今天也记录一点什么吧。",
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
            }

            item(key = "search") {
                Surface(
                    onClick = onOpenSearch,
                    modifier = Modifier.fillMaxWidth(),
                    shape = RoundedCornerShape(28.dp),
                    color = MaterialTheme.colorScheme.surfaceContainerHigh,
                    tonalElevation = 2.dp,
                ) {
                    Row(
                        modifier = Modifier.padding(horizontal = 18.dp, vertical = 14.dp),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Icon(
                            Icons.Filled.Search,
                            contentDescription = null,
                            tint = MaterialTheme.colorScheme.primary,
                        )
                        Spacer(Modifier.width(12.dp))
                        Column(Modifier.weight(1f)) {
                            Text("搜索日志与灵感", style = MaterialTheme.typography.bodyLarge)
                            Text(
                                "按关键词或标签查找",
                                style = MaterialTheme.typography.labelMedium,
                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                            )
                        }
                        Text(
                            "搜索",
                            style = MaterialTheme.typography.labelLarge,
                            color = MaterialTheme.colorScheme.primary,
                        )
                    }
                }
            }

            item(key = "modules") {
                Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                    Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                        ModuleCard("日志", Icons.AutoMirrored.Filled.MenuBook, ModuleColors.Log, ui.todayLogCount, Modifier.weight(1f), onOpenExplore)
                        ModuleCard("想法", Icons.Filled.Lightbulb, ModuleColors.Idea, ui.todayIdeaCount, Modifier.weight(1f), onOpenExplore)
                    }
                    Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                        ModuleCard("日程", Icons.Filled.CalendarMonth, ModuleColors.Calendar, ui.todayTaskCount, Modifier.weight(1f), onOpenCalendar)
                        ModuleCard("情绪", Icons.Filled.Favorite, ModuleColors.Emotion, ui.todayEmotionCount, Modifier.weight(1f), onOpenEmotion)
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
                                color = ModuleColors.Idea,
                            )
                        }
                    }
                }
            }

            item(key = "overview") {
                StyleCard(modifier = Modifier.fillMaxWidth()) {
                    Text("今日概览", style = MaterialTheme.typography.titleSmall)
                    Spacer(Modifier.height(8.dp))
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceEvenly,
                    ) {
                        OverviewItem("${ui.todayLogCount}", "日志")
                        OverviewItem("${ui.todayIdeaCount}", "想法")
                        OverviewItem("${ui.todayEmotionCount}", "情绪")
                        OverviewItem(ui.latestEmotion?.level?.emoji ?: "—", "当前")
                    }
                }
            }

            item(key = "recent-header") {
                Text(
                    "最近记录",
                    style = MaterialTheme.typography.titleMedium,
                    modifier = Modifier.padding(top = 8.dp),
                )
            }
            items(items = ui.recentLogs, key = { it.id }) { log ->
                LogCard(log = log, modifier = Modifier.animateItem(), onClick = { onOpenRecord(log.id) })
            }
            if (ui.recentLogs.isEmpty()) {
                item(key = "empty") {
                    Text(
                        "还没有记录，点右下角 + 创建第一条吧",
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        modifier = Modifier.padding(vertical = 24.dp),
                    )
                }
            }
        }
    }
}

@Composable
private fun ModuleCard(
    name: String,
    icon: ImageVector,
    color: Color,
    todayCount: Int?,
    modifier: Modifier = Modifier,
    onClick: () -> Unit,
) {
    StyleCard(modifier = modifier, onClick = onClick) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Icon(
                icon,
                contentDescription = null,
                tint = color,
                modifier = Modifier.size(28.dp),
            )
            Spacer(Modifier.weight(1f))
            if (todayCount != null) {
                Text(
                    "$todayCount",
                    style = MaterialTheme.typography.titleMedium,
                    color = color,
                )
            }
        }
        Spacer(Modifier.height(8.dp))
        Text(name, style = MaterialTheme.typography.titleSmall)
        Text(
            if (todayCount != null) "今日新增" else "查看",
            style = MaterialTheme.typography.labelSmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
    }
}

@Composable
private fun OverviewItem(value: String, label: String) {
    Column(horizontalAlignment = Alignment.CenterHorizontally) {
        Text(value, style = MaterialTheme.typography.titleLarge)
        Text(
            label,
            style = MaterialTheme.typography.labelSmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
    }
}

private fun greeting(): String = when (LocalTime.now().hour) {
    in 5..10 -> "早上好"
    in 11..12 -> "中午好"
    in 13..17 -> "下午好"
    in 18..22 -> "晚上好"
    else -> "夜深了"
}
