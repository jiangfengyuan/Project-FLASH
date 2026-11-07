// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package com.flash.app.ui.memory

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowLeft
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material.icons.automirrored.filled.Notes
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Lightbulb
import androidx.compose.material.icons.filled.Mood
import androidx.compose.material.icons.outlined.AutoAwesome
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.flash.app.FlashApplication
import com.flash.app.domain.WeeklyMemory
import com.flash.app.i18n.tr
import com.flash.app.ui.components.FlashEmptyState
import com.flash.app.ui.paper.PaperCard
import com.flash.app.ui.paper.pageGutter
import com.flash.app.ui.theme.FlashTokens
import com.flash.app.ui.theme.ModuleColors
import com.flash.app.ui.theme.StatNumberStyle
import java.time.LocalDate

/** Memory 周报（对齐 iOS）：周导航、四类计数、本周情绪、亮点；不进入未来周。 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun MemoryScreen(onBack: () -> Unit) {
    val app = LocalContext.current.applicationContext as FlashApplication
    val logs by app.repository.logs.collectAsState(emptyList())
    val emotions by app.repository.emotions.collectAsState(emptyList())
    val tasks by app.repository.tasks.collectAsState(emptyList())
    var weekOffset by remember { mutableIntStateOf(0) }
    val base = remember(weekOffset) { LocalDate.now().plusWeeks(weekOffset.toLong()) }
    val report = remember(logs, emotions, tasks, base) { WeeklyMemory.report(logs, emotions, tasks, base) }

    Scaffold(
        containerColor = Color.Transparent,
        topBar = {
            TopAppBar(
                title = { Text(tr("Memory")) },
                colors = TopAppBarDefaults.topAppBarColors(containerColor = Color.Transparent),
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = tr("返回"))
                    }
                },
            )
        },
    ) { padding ->
        Column(
            Modifier
                .padding(padding)
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .padding(horizontal = pageGutter())
                .padding(bottom = FlashTokens.Spacing.XL),
            verticalArrangement = Arrangement.spacedBy(FlashTokens.Spacing.LG),
        ) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                IconButton(onClick = { weekOffset -= 1 }) {
                    Icon(Icons.AutoMirrored.Filled.KeyboardArrowLeft, contentDescription = tr("上一周"))
                }
                TextButton(onClick = { weekOffset = 0 }, enabled = weekOffset != 0) { Text(tr("回到本周")) }
                IconButton(onClick = { weekOffset += 1 }, enabled = weekOffset != 0) {
                    Icon(Icons.AutoMirrored.Filled.KeyboardArrowRight, contentDescription = tr("下一周"))
                }
                Spacer(Modifier.weight(1f))
                Text(
                    "${report.weekStart} — ${report.weekEnd}",
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
            if (!report.hasData) {
                FlashEmptyState(
                    title = tr("再记录一点，未来的你会看到。"),
                    icon = Icons.Outlined.AutoAwesome,
                    ringSeed = "memory-empty",
                )
                return@Column
            }
            Column(verticalArrangement = Arrangement.spacedBy(FlashTokens.Spacing.XS)) {
                Text(tr("You recorded"), style = MaterialTheme.typography.titleMedium, modifier = Modifier.semantics { heading() })
                val entries = listOf(
                    CountEntry(tr("moments"), report.moments, Icons.AutoMirrored.Filled.Notes, ModuleColors.Log),
                    CountEntry(tr("ideas"), report.ideas, Icons.Filled.Lightbulb, ModuleColors.Idea),
                    CountEntry(tr("tasks"), report.tasks, Icons.Filled.CheckCircle, ModuleColors.Calendar),
                    CountEntry(tr("emotions"), report.emotions, Icons.Filled.Mood, ModuleColors.Emotion),
                )
                val perRow = if (LocalDensity.current.fontScale >= 1.5f) 2 else 4
                entries.chunked(perRow).forEach { row ->
                    Row(horizontalArrangement = Arrangement.spacedBy(FlashTokens.Spacing.SM)) {
                        row.forEach { CountCard(it, Modifier.weight(1f)) }
                    }
                }
            }
            report.mood?.let { mood ->
                PaperCard(seed = "memory-mood", modifier = Modifier.fillMaxWidth()) {
                    Text(tr("This week felt..."), style = MaterialTheme.typography.titleMedium, modifier = Modifier.semantics { heading() })
                    Spacer(Modifier.height(FlashTokens.Spacing.XS))
                    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(FlashTokens.Spacing.SM)) {
                        Text(mood.emoji, fontSize = 28.sp)
                        Text(mood.text, style = MaterialTheme.typography.bodyMedium)
                    }
                }
            }
            if (report.highlights.isNotEmpty()) {
                PaperCard(seed = "memory-highlights", frayed = true, modifier = Modifier.fillMaxWidth()) {
                    Text(tr("Highlights"), style = MaterialTheme.typography.titleMedium, modifier = Modifier.semantics { heading() })
                    Spacer(Modifier.height(FlashTokens.Spacing.XS))
                    report.highlights.forEach { title ->
                        Row(horizontalArrangement = Arrangement.spacedBy(FlashTokens.Spacing.XS), modifier = Modifier.padding(vertical = 2.dp)) {
                            Text("•", color = MaterialTheme.colorScheme.onSurfaceVariant)
                            // 单行关键摘录：展示字体
                            Text(
                                title,
                                style = MaterialTheme.typography.titleMedium,
                                maxLines = 2,
                                overflow = TextOverflow.Ellipsis,
                            )
                        }
                    }
                }
            }
            Text(
                tr("A week worth remembering. ✦"),
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.align(Alignment.CenterHorizontally),
            )
        }
    }
}

private data class CountEntry(val title: String, val value: Int, val icon: ImageVector, val tint: Color)

@Composable
private fun CountCard(entry: CountEntry, modifier: Modifier = Modifier) {
    PaperCard(
        seed = "memory-${entry.title}",
        cornerRadius = FlashTokens.Radius.CardSmall,
        contentPadding = FlashTokens.Spacing.SM,
        modifier = modifier,
    ) {
        Icon(entry.icon, null, tint = entry.tint, modifier = Modifier.size(20.dp))
        Spacer(Modifier.height(4.dp))
        Text("${entry.value}", style = MaterialTheme.typography.titleLarge.merge(StatNumberStyle))
        Text(
            entry.title,
            style = MaterialTheme.typography.labelSmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
        )
    }
}
