package com.flash.app.ui.explore

import androidx.compose.foundation.background
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
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.Send
import androidx.compose.material.icons.filled.CalendarMonth
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilterChip
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import com.flash.app.FlashApplication
import com.flash.app.data.UiStyle
import com.flash.app.data.model.ColorTag
import com.flash.app.ui.components.LogCard
import com.flash.app.ui.theme.LocalUiStyle
import com.flash.app.ui.theme.glass.glass

/** 探索 Tab：统一信息流 + 模块筛选 + 快速输入坞 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ExploreScreen(onOpenLogFlow: () -> Unit, onOpenCalendar: () -> Unit) {
    val app = LocalContext.current.applicationContext as FlashApplication
    val viewModel: ExploreViewModel = viewModel(factory = ExploreViewModel.factory(app.repository))
    val logs by viewModel.logs.collectAsStateWithLifecycle()
    val filter by viewModel.filter.collectAsStateWithLifecycle()
    val text by viewModel.text.collectAsStateWithLifecycle()
    val selectedTag by viewModel.selectedTag.collectAsStateWithLifecycle()

    Scaffold(
        containerColor = Color.Transparent,
        topBar = {
            TopAppBar(
                title = { Text("探索") },
                colors = TopAppBarDefaults.topAppBarColors(containerColor = Color.Transparent),
                actions = {
                    IconButton(onClick = onOpenCalendar) {
                        Icon(Icons.Filled.CalendarMonth, contentDescription = "日历")
                    }
                    TextButton(onClick = onOpenLogFlow) { Text("管理") }
                },
            )
        },
        bottomBar = {
            Box(modifier = Modifier.imePadding()) {
                InputDock(
                    text = text,
                    onTextChange = viewModel::updateText,
                    selectedTag = selectedTag,
                    onToggleTag = viewModel::toggleTag,
                    onSend = viewModel::save,
                )
            }
        },
    ) { innerPadding ->
        Column(
            modifier = Modifier
                .padding(innerPadding)
                .fillMaxSize(),
        ) {
            Row(
                horizontalArrangement = Arrangement.spacedBy(8.dp),
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp, vertical = 4.dp),
            ) {
                ExploreFilter.entries.forEach { f ->
                    FilterChip(
                        selected = filter == f,
                        onClick = { viewModel.setFilter(f) },
                        label = { Text(f.displayName) },
                    )
                }
            }
            if (logs.isEmpty()) {
                Column(
                    modifier = Modifier.fillMaxSize(),
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.Center,
                ) {
                    Text("✈️", fontSize = 56.sp)
                    Spacer(Modifier.height(12.dp))
                    Text(
                        "闪过即留，写下第一条吧",
                        style = MaterialTheme.typography.bodyLarge,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
            } else {
                LazyColumn(
                    modifier = Modifier.fillMaxSize(),
                    contentPadding = PaddingValues(horizontal = 16.dp, vertical = 8.dp),
                    verticalArrangement = Arrangement.spacedBy(10.dp),
                ) {
                    items(items = logs, key = { it.id }) { log ->
                        LogCard(log = log, modifier = Modifier.animateItem())
                    }
                }
            }
        }
    }
}

@Composable
private fun InputDock(
    text: String,
    onTextChange: (String) -> Unit,
    selectedTag: ColorTag?,
    onToggleTag: (ColorTag) -> Unit,
    onSend: () -> Unit,
) {
    Column(
        modifier = Modifier
            .padding(horizontal = 12.dp, vertical = 8.dp)
            .then(dockContainerModifier())
            .padding(horizontal = 12.dp, vertical = 8.dp),
    ) {
        Row(
            horizontalArrangement = Arrangement.spacedBy(8.dp),
            modifier = Modifier
                .fillMaxWidth()
                .horizontalScroll(rememberScrollState()),
        ) {
            ColorTag.entries.forEach { tag ->
                FilterChip(
                    selected = selectedTag == tag,
                    onClick = { onToggleTag(tag) },
                    label = { Text(tag.displayName) },
                )
            }
        }
        Spacer(Modifier.height(8.dp))
        Row(verticalAlignment = Alignment.CenterVertically) {
            OutlinedTextField(
                value = text,
                onValueChange = onTextChange,
                placeholder = { Text("闪过即留...") },
                supportingText = {
                    Text("${text.length}/${ExploreViewModel.MAX_LENGTH}")
                },
                singleLine = true,
                modifier = Modifier.weight(1f),
            )
            IconButton(onClick = onSend, enabled = text.isNotBlank()) {
                Icon(Icons.AutoMirrored.Filled.Send, contentDescription = "发送")
            }
        }
    }
}

/** 输入坞容器：GLASS → 浮空玻璃胶囊；MD3 → 标准圆角浮起卡片 */
@Composable
private fun dockContainerModifier(): Modifier {
    return if (LocalUiStyle.current == UiStyle.GLASS) {
        Modifier.glass(strong = true)
    } else {
        Modifier
            .shadow(8.dp, RoundedCornerShape(24.dp))
            .clip(RoundedCornerShape(24.dp))
            .background(MaterialTheme.colorScheme.surface)
    }
}
