// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package com.flash.app.ui.home

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.EditNote
import androidx.compose.material.icons.filled.Lightbulb
import androidx.compose.material.icons.filled.Mood
import androidx.compose.material.icons.filled.Search
import androidx.compose.material.icons.outlined.AutoAwesome
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import com.flash.app.FlashApplication
import com.flash.app.data.model.Category
import com.flash.app.data.model.LogItem
import com.flash.app.data.model.emoji
import com.flash.app.domain.shouldShowIdeaReminder
import com.flash.app.i18n.tr
import com.flash.app.ui.components.FlashEmptyState
import com.flash.app.ui.components.RecordCard
import com.flash.app.ui.components.RecordMenu
import com.flash.app.ui.components.rememberFlashHaptics
import com.flash.app.ui.navigation.LocalAppActions
import com.flash.app.ui.navigation.LocalPageBottomPadding
import com.flash.app.ui.navigation.Routes
import com.flash.app.ui.paper.PaperCard
import com.flash.app.ui.paper.PaperCardShape
import com.flash.app.ui.paper.StickyStack
import com.flash.app.ui.paper.TornSectionBreak
import com.flash.app.ui.paper.VerticalHandDivider
import com.flash.app.ui.paper.foldedLetter
import com.flash.app.ui.paper.handUnderline
import com.flash.app.ui.paper.pageGutter
import com.flash.app.ui.theme.FlashTokens
import com.flash.app.ui.theme.LocalIsDarkTheme
import com.flash.app.ui.theme.ModuleColors
import com.flash.app.ui.theme.StatNumberStyle
import java.time.LocalTime
import kotlinx.coroutines.launch

/** 按小时问候（对齐 iOS GreetingHeaderView） */
internal fun greetingSource(hour: Int): String = when (hour) {
    in 5 until 11 -> "早上好 ☀️"
    in 11 until 18 -> com.flash.app.i18n.tr("下午好 🌤")
    else -> "晚上好 🌙"
}

/** 此刻页（对齐 iOS）：问候 + 新建 → 灵感提示 → 今日一览 → 断口 → 最近闪念；≥ 700dp 双栏 */
@Composable
fun HomeScreen() {
    val app = LocalContext.current.applicationContext as FlashApplication
    val viewModel: HomeViewModel = viewModel(factory = HomeViewModel.factory(app.repository))
    val ui by viewModel.uiState.collectAsStateWithLifecycle()
    val actions = LocalAppActions.current
    val haptics = rememberFlashHaptics()
    val scope = rememberCoroutineScope()
    val gutter = pageGutter()

    LaunchedEffect(viewModel) {
        viewModel.events.collect { event ->
            when (event) {
                is HomeEvent.Failed -> actions.toast(event.message, null, null)
            }
        }
    }

    fun delete(log: LogItem) {
        scope.launch {
            val undo = viewModel.deleteWithUndo(log) ?: return@launch
            haptics.light()
            actions.toast(tr("已删除"), tr("撤销"), undo)
        }
    }

    BoxWithConstraints(Modifier.fillMaxSize().statusBarsPadding()) {
        val twoColumn = maxWidth >= 700.dp
        Column(
            Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .padding(horizontal = gutter)
                .padding(top = FlashTokens.Spacing.XS, bottom = FlashTokens.Spacing.LG + LocalPageBottomPadding.current),
            verticalArrangement = Arrangement.spacedBy(FlashTokens.Spacing.LG),
        ) {
            Greeting(onSearch = actions.openSearch)
            if (shouldShowIdeaReminder(ui.unviewedIdeaCount)) {
                IdeaReminderRow(ui.unviewedIdeaCount) { ui.oldestUnviewedIdeaId?.let(actions.openRecord) }
            }
            if (twoColumn) {
                Row(horizontalArrangement = Arrangement.spacedBy(FlashTokens.Spacing.LG)) {
                    TodayOverviewCard(ui, Modifier.weight(1f))
                    Column(Modifier.weight(1f)) { RecentSection(ui, ::delete, viewModel::toggleFavorite) }
                }
            } else {
                TodayOverviewCard(ui, Modifier.fillMaxWidth())
                TornSectionBreak("home-break")
                RecentSection(ui, ::delete, viewModel::toggleFavorite)
            }
        }
    }
}

@Composable
private fun Greeting(onSearch: () -> Unit) {
    val actions = LocalAppActions.current
    val hour = remember { LocalTime.now().hour }
    val stack = LocalDensity.current.fontScale > 1.3f
    Column {
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.End) {
            IconButton(onClick = onSearch) {
                Icon(Icons.Filled.Search, contentDescription = tr("全局搜索"), tint = MaterialTheme.colorScheme.primary)
            }
        }
        if (stack) {
            GreetingText(hour)
            Spacer(Modifier.height(FlashTokens.Spacing.SM))
            NewMenu(actions)
        } else {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Box(Modifier.weight(1f)) { GreetingText(hour) }
                Spacer(Modifier.size(FlashTokens.Spacing.MD))
                NewMenu(actions)
            }
        }
    }
}

@Composable
private fun GreetingText(hour: Int) {
    val brand = MaterialTheme.colorScheme.primary
    Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
        Text(
            tr(greetingSource(hour)),
            style = MaterialTheme.typography.headlineLarge,
            color = MaterialTheme.colorScheme.onSurface,
            modifier = Modifier.handUnderline("greeting", brand, 0.45f).semantics { heading() },
        )
        Text(
            tr("今天也记录一点什么吧。"),
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
    }
}

@Composable
private fun NewMenu(actions: com.flash.app.ui.navigation.AppActions) {
    var open by remember { mutableStateOf(false) }
    Box {
        Button(
            onClick = { open = true },
            colors = ButtonDefaults.buttonColors(
                containerColor = MaterialTheme.colorScheme.primary,
                contentColor = MaterialTheme.colorScheme.onPrimary,
            ),
            modifier = Modifier.heightIn(min = FlashTokens.Touch.IconButtonMin),
        ) {
            Icon(Icons.Filled.Add, contentDescription = null, modifier = Modifier.size(18.dp))
            Spacer(Modifier.size(4.dp))
            Text(tr("新建"))
        }
        DropdownMenu(expanded = open, onDismissRequest = { open = false }) {
            DropdownMenuItem(
                text = { Text(tr("新建记录")) },
                leadingIcon = { Icon(Icons.Filled.EditNote, null) },
                onClick = { open = false; actions.quickCapture(Category.LOG) },
            )
            DropdownMenuItem(
                text = { Text(tr("新建灵感")) },
                leadingIcon = { Icon(Icons.Filled.Lightbulb, null) },
                onClick = { open = false; actions.quickCapture(Category.IDEA) },
            )
            HorizontalDivider()
            DropdownMenuItem(
                text = { Text(tr("记录情绪")) },
                leadingIcon = { Icon(Icons.Filled.Mood, null) },
                onClick = { open = false; actions.openTab(Routes.EMOTION) },
            )
            DropdownMenuItem(
                text = { Text(tr("新建任务")) },
                leadingIcon = { Icon(Icons.Filled.CheckCircle, null) },
                onClick = { open = false; actions.newTask() },
            )
        }
    }
}

@Composable
private fun IdeaReminderRow(count: Int, onClick: () -> Unit) {
    StickyStack(seed = "idea-reminder", cornerRadius = FlashTokens.Radius.CardSmall) {
        PaperCard(
            seed = "idea-reminder",
            cornerRadius = FlashTokens.Radius.CardSmall,
            onClick = onClick,
            contentPadding = FlashTokens.Spacing.MD,
            modifier = Modifier.fillMaxWidth(),
        ) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(FlashTokens.Spacing.SM)) {
                Icon(Icons.Filled.Lightbulb, null, tint = ModuleColors.IdeaText, modifier = Modifier.size(24.dp))
                Column(Modifier.weight(1f)) {
                    Text(tr("想法等待梳理"), style = MaterialTheme.typography.titleSmall)
                    Text(
                        tr("你还有 {0} 个想法，先看看最早的一条", count),
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
                Text("$count", style = MaterialTheme.typography.titleMedium, color = ModuleColors.IdeaText)
                Icon(Icons.AutoMirrored.Filled.KeyboardArrowRight, null, tint = MaterialTheme.colorScheme.outline)
            }
        }
    }
}

/** 今日一览：折叠信纸 + 撕开的底边。三项数字用衬线体，字号放大时纵向排列 */
@Composable
private fun TodayOverviewCard(ui: HomeUiState, modifier: Modifier = Modifier) {
    val dark = LocalIsDarkTheme.current
    val emotion = ui.latestEmotion
    val entries = listOf(
        Triple(Icons.Filled.EditNote to ModuleColors.Log, "${ui.todayRecordCount}", tr("今日记录")),
        Triple(Icons.Filled.CheckCircle to ModuleColors.Calendar, "${ui.openTaskCount}", tr("待办")),
        Triple(
            Icons.Filled.Mood to ModuleColors.Emotion,
            emotion?.level?.emoji ?: "🙂",
            emotion?.level?.displayName ?: tr("还没有记录"),
        ),
    )
    PaperCard(modifier = modifier, seed = "today", frayed = true, contentPadding = 0.dp) {
        val vertical = LocalDensity.current.fontScale >= 1.5f
        val content: @Composable () -> Unit = {
            entries.forEachIndexed { index, (icon, value, label) ->
                if (index > 0 && !vertical) VerticalHandDivider("overview-$index", Modifier.height(44.dp))
                Row(
                    modifier = if (vertical) Modifier.fillMaxWidth() else Modifier.padding(horizontal = 2.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(6.dp),
                ) {
                    Icon(icon.first, null, tint = icon.second, modifier = Modifier.size(18.dp))
                    Column {
                        Text(value, style = MaterialTheme.typography.titleLarge.merge(StatNumberStyle))
                        Text(
                            label,
                            style = MaterialTheme.typography.labelSmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                            maxLines = 2,
                        )
                    }
                }
            }
        }
        Box(Modifier.fillMaxWidth().foldedLetter(dark).padding(FlashTokens.Spacing.CardPadding)) {
            if (vertical) {
                Column(verticalArrangement = Arrangement.spacedBy(FlashTokens.Spacing.SM)) { content() }
            } else {
                Row(
                    Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically,
                ) { content() }
            }
        }
    }
}

@Composable
private fun RecentSection(ui: HomeUiState, onDelete: (LogItem) -> Unit, onToggleFavorite: (LogItem) -> Unit) {
    val actions = LocalAppActions.current
    if (ui.recentLogs.isEmpty()) {
        FlashEmptyState(
            title = tr("今天还没有记录。"),
            icon = Icons.Outlined.AutoAwesome,
            ringSeed = "home-empty",
            actionLabel = tr("记下第一个念头"),
            onAction = { actions.quickCapture(Category.IDEA) },
        )
        return
    }
    val mustard = ModuleColors.Idea
    Column(verticalArrangement = Arrangement.spacedBy(FlashTokens.Spacing.SM)) {
        Text(
            tr("最近闪念"),
            style = MaterialTheme.typography.titleLarge,
            color = MaterialTheme.colorScheme.onSurface,
            modifier = Modifier
                .padding(start = 4.dp, bottom = 4.dp)
                .handUnderline("recent", mustard, 0.9f)
                .semantics { heading() },
        )
        ui.recentLogs.forEach { log ->
            RecordCard(
                log = log,
                onClick = { actions.openRecord(log.id) },
                isUnread = log.id in ui.unviewedIdeaIds,
                sticky = log.category == Category.IDEA,
                menu = RecordMenu(
                    onEdit = { actions.openRecord(log.id) },
                    onToggleFavorite = { onToggleFavorite(log) },
                    onConvertToTask = { actions.newTaskFromIdea(log.id, log.content) },
                    onDelete = { onDelete(log) },
                ),
            )
        }
    }
}
