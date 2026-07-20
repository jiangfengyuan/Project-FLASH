package com.flash.app.ui.emotion

import androidx.compose.animation.animateColorAsState
import androidx.compose.foundation.background
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
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.CenterAlignedTopAppBar
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilterChip
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.ListItem
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Slider
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
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
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import com.flash.app.FlashApplication
import com.flash.app.data.model.EmotionLevel
import com.flash.app.data.model.EmotionRecord
import com.flash.app.data.model.SubEmotion
import com.flash.app.ui.components.hexToColor

/** 情绪 Tab：等级滑块 + 子情绪 + 备注 + 统计 + 历史，对应 Web 版 CurrentEmotion 页 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun EmotionScreen(onOpenSettings: () -> Unit) {
    val app = LocalContext.current.applicationContext as FlashApplication
    val viewModel: EmotionViewModel = viewModel(factory = EmotionViewModel.factory(app.repository))
    val emotions by viewModel.emotions.collectAsStateWithLifecycle()
    var deletingRecord by remember { mutableStateOf<EmotionRecord?>(null) }

    Scaffold(
        containerColor = Color.Transparent,
        topBar = {
            CenterAlignedTopAppBar(
                title = { Text("当下情绪") },
                colors = TopAppBarDefaults.topAppBarColors(containerColor = Color.Transparent),
                actions = {
                    IconButton(onClick = onOpenSettings) {
                        Icon(Icons.Filled.Settings, contentDescription = "设置")
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
            LevelIndicator(level = viewModel.selectedLevel)
            Spacer(Modifier.height(16.dp))
            LevelSlider(
                level = viewModel.selectedLevel,
                onLevelChange = viewModel::selectLevel,
            )
            if (viewModel.selectedLevel.isNegative) {
                Spacer(Modifier.height(8.dp))
                SubEmotionChips(
                    selected = viewModel.selectedSubEmotion,
                    onSelect = viewModel::selectSubEmotion,
                )
            }
            Spacer(Modifier.height(8.dp))
            OutlinedTextField(
                value = viewModel.note,
                onValueChange = viewModel::updateNote,
                label = { Text("备注（可选）") },
                singleLine = true,
                modifier = Modifier.fillMaxWidth(),
            )
            Spacer(Modifier.height(12.dp))
            Button(
                onClick = viewModel::save,
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
            LazyColumn(
                modifier = Modifier.weight(1f),
                verticalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                item(key = "stats") {
                    EmotionStatsSection(emotions = emotions)
                }
                items(items = emotions, key = { it.id }) { record ->
                    EmotionRow(record, onDelete = { deletingRecord = record })
                    HorizontalDivider(thickness = 0.5.dp)
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

@Composable
private fun LevelIndicator(level: EmotionLevel) {
    val color by animateColorAsState(
        targetValue = level.colorHex.hexToColor(),
        label = "levelColor",
    )
    Column(horizontalAlignment = Alignment.CenterHorizontally) {
        Box(
            Modifier
                .size(80.dp)
                .clip(CircleShape)
                .background(color)
        )
        Spacer(Modifier.height(8.dp))
        Text(level.displayName, style = MaterialTheme.typography.headlineSmall)
    }
}

/** MD3 Slider：离散 7 档（-3..+3），符合 PRD 3.5 的 MD3 输入规范 */
@Composable
private fun LevelSlider(level: EmotionLevel, onLevelChange: (EmotionLevel) -> Unit) {
    Slider(
        value = level.value.toFloat(),
        onValueChange = { onLevelChange(EmotionLevel.fromValue(it.toInt())) },
        valueRange = -3f..3f,
        steps = 5,
        modifier = Modifier.fillMaxWidth(),
    )
}

@Composable
private fun SubEmotionChips(selected: SubEmotion?, onSelect: (SubEmotion?) -> Unit) {
    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        SubEmotion.entries.forEach { sub ->
            FilterChip(
                selected = selected == sub,
                onClick = { onSelect(sub) },
                label = { Text(sub.displayName) },
            )
        }
    }
}

@Composable
private fun EmotionRow(record: EmotionRecord, onDelete: () -> Unit) {
    ListItem(
        leadingContent = {
            Box(
                Modifier
                    .size(12.dp)
                    .clip(CircleShape)
                    .background(record.level.colorHex.hexToColor())
            )
        },
        headlineContent = {
            val sub = record.subEmotion?.let { " · ${it.displayName}" } ?: ""
            Text(record.level.displayName + sub)
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
