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
import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.combinedClickable
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
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Star
import androidx.compose.material.icons.outlined.StarOutline
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Slider
import androidx.compose.material3.SliderDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.derivedStateOf
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import com.flash.app.FlashApplication
import com.flash.app.data.model.EmotionLevel
import com.flash.app.data.model.EmotionRecord
import com.flash.app.data.model.SubEmotion
import com.flash.app.data.model.emoji
import com.flash.app.i18n.tr
import com.flash.app.ui.components.FlashFilterChip
import com.flash.app.ui.components.rememberFlashHaptics
import com.flash.app.ui.navigation.LocalAppActions
import com.flash.app.ui.navigation.LocalPageBottomPadding
import com.flash.app.ui.paper.FlashDivider
import com.flash.app.ui.paper.PaperCard
import com.flash.app.ui.paper.handUnderline
import com.flash.app.ui.paper.pageGutter
import com.flash.app.ui.theme.FlashTokens
import com.flash.app.ui.theme.LocalIsDarkTheme
import com.flash.app.ui.theme.ModuleColors
import com.flash.app.ui.theme.moodColor
import java.time.DayOfWeek
import java.time.LocalDate
import java.time.temporal.TemporalAdjusters
import kotlin.math.roundToInt

/** 情绪页（对齐 iOS）：七级滑杆 + 强度 + 子情绪 + 备注 → 本周趋势 → 统计 → 近期记录 */
@Composable
fun EmotionScreen() {
    val app = LocalContext.current.applicationContext as FlashApplication
    val viewModel: EmotionViewModel = viewModel(factory = EmotionViewModel.factory(app.repository))
    val emotions by viewModel.emotions.collectAsStateWithLifecycle()
    val statsEmotions by viewModel.statsEmotions.collectAsStateWithLifecycle()
    val hasMoreHistory by viewModel.hasMoreHistory.collectAsStateWithLifecycle()
    var deletingRecord by remember { mutableStateOf<EmotionRecord?>(null) }
    val actions = LocalAppActions.current
    val haptics = rememberFlashHaptics()
    val listState = rememberLazyListState()
    val gutter = pageGutter()

    LaunchedEffect(viewModel) {
        viewModel.events.collect { event ->
            when (event) {
                is EmotionEvent.Failed -> actions.toast(event.message, null, null)
            }
        }
    }
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
        modifier = Modifier.fillMaxSize().statusBarsPadding(),
        contentPadding = PaddingValues(
            start = gutter,
            end = gutter,
            top = FlashTokens.Spacing.SM,
            bottom = FlashTokens.Spacing.LG + LocalPageBottomPadding.current,
        ),
        verticalArrangement = Arrangement.spacedBy(FlashTokens.Spacing.MD),
    ) {
        item(key = "title") {
            Text(
                tr("情绪"),
                style = MaterialTheme.typography.headlineLarge,
                modifier = Modifier.semantics { heading() },
            )
        }
        item(key = "hero") {
            PaperCard(seed = "emotion-hero", frayed = true, modifier = Modifier.fillMaxWidth()) {
                MoodSlider(viewModel.selectedLevel) {
                    viewModel.selectLevel(it)
                    haptics.selection()
                }
                Spacer(Modifier.height(FlashTokens.Spacing.SM))
                IntensityDots(viewModel.intensity, viewModel::selectIntensity)
                if (viewModel.selectedLevel.isNegative) {
                    Spacer(Modifier.height(FlashTokens.Spacing.SM))
                    SubEmotionSelector(viewModel.selectedSubEmotion, viewModel::selectSubEmotion)
                }
                Spacer(Modifier.height(FlashTokens.Spacing.SM))
                OutlinedTextField(
                    value = viewModel.note,
                    onValueChange = viewModel::updateNote,
                    label = { Text(tr("想说点什么？（可选）")) },
                    singleLine = true,
                    shape = androidx.compose.foundation.shape.RoundedCornerShape(FlashTokens.Radius.Field),
                    colors = androidx.compose.material3.OutlinedTextFieldDefaults.colors(
                        focusedContainerColor = MaterialTheme.colorScheme.surfaceVariant,
                        unfocusedContainerColor = MaterialTheme.colorScheme.surfaceVariant,
                        unfocusedBorderColor = MaterialTheme.colorScheme.outlineVariant,
                    ),
                    modifier = Modifier.fillMaxWidth(),
                )
                Spacer(Modifier.height(FlashTokens.Spacing.SM))
                Button(
                    onClick = {
                        viewModel.save()
                        haptics.success()
                    },
                    enabled = !viewModel.saving,
                    colors = ButtonDefaults.buttonColors(
                        containerColor = MaterialTheme.colorScheme.primary,
                        contentColor = MaterialTheme.colorScheme.onPrimary,
                    ),
                    modifier = Modifier.fillMaxWidth(),
                ) { Text(tr("记录情绪")) }
            }
        }
        item(key = "week") { WeekTrend(statsEmotions) }
        item(key = "stats") {
            // 短档用周一对齐自然周
            EmotionStatsSection(emotions = statsEmotions, weekAligned = true)
        }
        item(key = "recent-title") {
            Text(tr("近期记录"), style = MaterialTheme.typography.titleLarge, modifier = Modifier.semantics { heading() })
        }
        items(items = emotions, key = { it.id }) { record ->
            EmotionRow(
                record = record,
                modifier = Modifier.animateItem(),
                onToggleFavorite = { viewModel.toggleFavorite(record) },
                onDelete = { deletingRecord = record },
            )
        }
        if (hasMoreHistory) {
            item(key = "loading") {
                Text(
                    tr("正在加载更多…"),
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.fillMaxWidth().padding(vertical = FlashTokens.Spacing.SM),
                )
            }
        }
    }

    deletingRecord?.let { record ->
        AlertDialog(
            onDismissRequest = { deletingRecord = null },
            title = { Text(tr("删除这条情绪记录？")) },
            text = { Text("${record.recordDate} · ${record.level.displayName}") },
            confirmButton = {
                TextButton(onClick = {
                    viewModel.delete(record)
                    deletingRecord = null
                }) { Text(tr("删除"), color = MaterialTheme.colorScheme.error) }
            },
            dismissButton = { TextButton(onClick = { deletingRecord = null }) { Text(tr("取消")) } },
        )
    }
}

/** 七级滑杆：大 emoji 随档位切换；级别名按情绪色点缀（文字仍用可读墨色） */
@Composable
private fun MoodSlider(level: EmotionLevel, onChange: (EmotionLevel) -> Unit) {
    val dark = LocalIsDarkTheme.current
    val tint = level.moodColor(dark)
    Column(horizontalAlignment = Alignment.CenterHorizontally, modifier = Modifier.fillMaxWidth()) {
        AnimatedContent(
            targetState = level,
            transitionSpec = {
                (scaleIn(tween(220)) + fadeIn(tween(220))).togetherWith(scaleOut(tween(180)) + fadeOut(tween(180)))
            },
            label = "emojiSwap",
        ) { Text(it.emoji, fontSize = 64.sp) }
        Text(
            level.displayName,
            style = MaterialTheme.typography.headlineSmall,
            modifier = Modifier.handUnderline("mood", tint, 1f).padding(bottom = 2.dp),
        )
        Spacer(Modifier.height(FlashTokens.Spacing.XS))
        Slider(
            value = level.value.toFloat(),
            onValueChange = { onChange(EmotionLevel.fromValue(it.roundToInt())) },
            valueRange = -3f..3f,
            steps = 5,
            colors = SliderDefaults.colors(
                thumbColor = MaterialTheme.colorScheme.primary,
                activeTrackColor = tint,
                inactiveTrackColor = MaterialTheme.colorScheme.outlineVariant,
            ),
            modifier = Modifier.semantics {
                contentDescription = tr("情绪")
                stateDescription = level.displayName
            },
        )
    }
}

@Composable
private fun IntensityDots(value: Int?, onSelect: (Int) -> Unit) {
    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(FlashTokens.Spacing.XS)) {
        Text(
            tr("强度"),
            style = MaterialTheme.typography.labelLarge,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        (1..5).forEach { level ->
            val filled = value != null && level <= value
            Box(
                Modifier
                    .size(FlashTokens.Touch.IconButtonMin)
                    .clickable(onClickLabel = tr("强度 {0}", level)) { onSelect(level) },
                contentAlignment = Alignment.Center,
            ) {
                Box(
                    Modifier
                        .size(16.dp)
                        .background(if (filled) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.surfaceVariant, CircleShape)
                        .border(1.dp, MaterialTheme.colorScheme.outlineVariant, CircleShape),
                )
            }
        }
    }
}

@Composable
private fun SubEmotionSelector(selected: SubEmotion?, onSelect: (SubEmotion?) -> Unit) {
    Row(horizontalArrangement = Arrangement.spacedBy(FlashTokens.Spacing.XS), modifier = Modifier.fillMaxWidth()) {
        SubEmotion.entries.forEach { sub ->
            FlashFilterChip(
                label = sub.displayName,
                selected = selected == sub,
                onClick = { onSelect(if (selected == sub) null else sub) },
            )
        }
    }
}

/** 本周趋势：周一到周日的 emoji 行，空白日用虚线占位；一句摘要 */
@Composable
private fun WeekTrend(emotions: List<EmotionRecord>) {
    val today = LocalDate.now()
    val monday = today.with(TemporalAdjusters.previousOrSame(DayOfWeek.MONDAY))
    val days = (0L..6L).map { monday.plusDays(it) }
    val byDay = emotions.groupBy { it.recordDate }
    val week = days.mapNotNull { byDay[it.toString()] }.flatten()
    val mean = if (week.isEmpty()) null else week.sumOf { it.level.value }.toDouble() / week.size
    val labels = listOf("一", "二", "三", "四", "五", "六", "日")
    PaperCard(seed = "emotion-week", cornerRadius = FlashTokens.Radius.CardSmall, modifier = Modifier.fillMaxWidth()) {
        Text(tr("本周趋势"), style = MaterialTheme.typography.titleMedium)
        Spacer(Modifier.height(FlashTokens.Spacing.SM))
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
            days.forEachIndexed { index, day ->
                val latest = byDay[day.toString()]?.firstOrNull()
                Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(4.dp)) {
                    Box(Modifier.size(32.dp), contentAlignment = Alignment.Center) {
                        if (latest != null) {
                            Text(latest.level.emoji, fontSize = 22.sp)
                        } else {
                            Box(
                                Modifier
                                    .size(22.dp)
                                    .border(1.dp, MaterialTheme.colorScheme.outlineVariant, CircleShape),
                            )
                        }
                    }
                    Text(
                        tr(labels[index]),
                        style = MaterialTheme.typography.labelSmall,
                        color = if (day == today) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
            }
        }
        Spacer(Modifier.height(FlashTokens.Spacing.SM))
        FlashDivider("emotion-week-divider")
        Spacer(Modifier.height(FlashTokens.Spacing.XS))
        Text(
            when {
                mean == null -> tr("本周暂无记录")
                mean >= 1.0 -> tr("本周整体偏积极")
                mean <= -1.0 -> tr("本周情绪偏低落")
                else -> tr("本周情绪平稳")
            },
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
    }
}

@OptIn(ExperimentalFoundationApi::class)
@Composable
private fun EmotionRow(
    record: EmotionRecord,
    modifier: Modifier = Modifier,
    onToggleFavorite: () -> Unit,
    onDelete: () -> Unit,
) {
    var menu by remember { mutableStateOf(false) }
    Box(modifier) {
        PaperCard(seed = record.id, cornerRadius = FlashTokens.Radius.Row, contentPadding = 0.dp, modifier = Modifier.fillMaxWidth()) {
            Row(
                Modifier
                    .fillMaxWidth()
                    .combinedClickable(onClick = {}, onLongClick = { menu = true })
                    .padding(horizontal = FlashTokens.Spacing.MD, vertical = FlashTokens.Spacing.XS),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(FlashTokens.Spacing.SM),
            ) {
                Text(record.level.emoji, fontSize = 24.sp)
                Column(Modifier.weight(1f)) {
                    val detail = listOfNotNull(
                        record.level.displayName,
                        record.intensity?.let { tr("强度 {0}", it) },
                        record.subEmotion?.displayName,
                    ).joinToString(" · ")
                    Text(detail, style = MaterialTheme.typography.bodyMedium)
                    record.note?.takeIf { it.isNotBlank() }?.let {
                        Text(it, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    }
                    Text(record.recordDate, style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.outline)
                }
                IconButton(onClick = onToggleFavorite) {
                    Icon(
                        if (record.isFavorite == true) Icons.Filled.Star else Icons.Outlined.StarOutline,
                        contentDescription = if (record.isFavorite == true) tr("取消收藏") else tr("收藏"),
                        tint = if (record.isFavorite == true) ModuleColors.IdeaText else MaterialTheme.colorScheme.outline,
                    )
                }
            }
        }
        DropdownMenu(expanded = menu, onDismissRequest = { menu = false }) {
            DropdownMenuItem(
                text = { Text(if (record.isFavorite == true) tr("取消收藏") else tr("收藏")) },
                onClick = { menu = false; onToggleFavorite() },
            )
            DropdownMenuItem(
                text = { Text(tr("删除"), color = MaterialTheme.colorScheme.error) },
                onClick = { menu = false; onDelete() },
            )
        }
    }
}
