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
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.MenuBook
import androidx.compose.material.icons.filled.CalendarMonth
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.filled.Lightbulb
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import com.flash.app.FlashApplication
import com.flash.app.data.model.Category
import com.flash.app.data.model.emoji
import com.flash.app.ui.components.LogCard
import com.flash.app.ui.components.QuickCreateFab
import com.flash.app.ui.components.StyleCard
import com.flash.app.ui.theme.ModuleColors
import java.time.LocalTime

/** 首页（PRD 08）：问候 → 四模块卡 → 今日概览 → 最近记录，右下 FAB 快速创建 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun HomeScreen(
    onOpenExplore: () -> Unit,
    onOpenCalendar: () -> Unit,
    onOpenEmotion: () -> Unit,
) {
    val app = LocalContext.current.applicationContext as FlashApplication
    val viewModel: HomeViewModel = viewModel(factory = HomeViewModel.factory(app.repository))
    val ui by viewModel.uiState.collectAsStateWithLifecycle()
    var quickCreate by remember { mutableStateOf<Category?>(null) }

    Scaffold(
        containerColor = Color.Transparent,
        floatingActionButton = {
            QuickCreateFab(
                onCreateLog = { quickCreate = Category.LOG },
                onCreateIdea = { quickCreate = Category.IDEA },
                onCreateEmotion = onOpenEmotion,
                onCreateCalendar = onOpenCalendar,
            )
        },
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

            item(key = "modules") {
                Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                    Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                        ModuleCard("日志", Icons.AutoMirrored.Filled.MenuBook, ModuleColors.Log, ui.todayLogCount, Modifier.weight(1f), onOpenExplore)
                        ModuleCard("想法", Icons.Filled.Lightbulb, ModuleColors.Idea, ui.todayIdeaCount, Modifier.weight(1f), onOpenExplore)
                    }
                    Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                        ModuleCard("日程", Icons.Filled.CalendarMonth, ModuleColors.Calendar, null, Modifier.weight(1f), onOpenCalendar)
                        ModuleCard("情绪", Icons.Filled.Favorite, ModuleColors.Emotion, ui.todayEmotionCount, Modifier.weight(1f), onOpenEmotion)
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
                LogCard(log = log, modifier = Modifier.animateItem())
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
            item(key = "fab-space") { Spacer(Modifier.height(72.dp)) }
        }
    }

    quickCreate?.let { category ->
        QuickInputDialog(
            category = category,
            onDismiss = { quickCreate = null },
            onSave = { text ->
                viewModel.quickAdd(text, category)
                quickCreate = null
            },
        )
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

@Composable
private fun QuickInputDialog(
    category: Category,
    onDismiss: () -> Unit,
    onSave: (String) -> Unit,
) {
    var text by remember { mutableStateOf("") }
    val isIdea = category == Category.IDEA
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(if (isIdea) "记录灵感" else "记录日志") },
        text = {
            OutlinedTextField(
                value = text,
                onValueChange = { text = it.take(140) },
                placeholder = { Text(if (isIdea) "此刻的想法是..." else "闪过即留...") },
                supportingText = { Text("${text.length}/140") },
                modifier = Modifier.fillMaxWidth(),
            )
        },
        confirmButton = {
            TextButton(
                onClick = { if (text.isNotBlank()) onSave(text) },
            ) { Text("保存") }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) { Text("取消") }
        },
    )
}

private fun greeting(): String = when (LocalTime.now().hour) {
    in 5..10 -> "早上好"
    in 11..12 -> "中午好"
    in 13..17 -> "下午好"
    in 18..22 -> "晚上好"
    else -> "夜深了"
}
