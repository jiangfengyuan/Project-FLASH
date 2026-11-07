// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package com.flash.app.ui.stats

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
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.setValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.foundation.lazy.rememberLazyListState
import com.flash.app.ui.calendar.CalendarScreen
import com.flash.app.ui.components.FlashSegmentedControl
import com.flash.app.domain.dailyActivity
import androidx.compose.material3.TextButton
import com.flash.app.domain.ReviewInsight
import com.flash.app.domain.ReviewWindow
import com.flash.app.domain.reviewInsight
import com.flash.app.ui.components.FlashFilterChipRow
import com.flash.app.ui.components.FlashFilterChipItem
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import com.flash.app.FlashApplication
import com.flash.app.ui.components.FlashCard
import com.flash.app.ui.emotion.EmotionStatsSection

/** 统计 Tab：数据概览 + 情绪走势（对应 PRD Insights） */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun StatsScreen(onOpenMemory: () -> Unit, onOpenRecord: (String) -> Unit) {
    val app = LocalContext.current.applicationContext as FlashApplication
    val viewModel: StatsViewModel = viewModel(factory = StatsViewModel.factory(app.repository))
    val ui by viewModel.uiState.collectAsStateWithLifecycle()

    var window by rememberSaveable { mutableStateOf(ReviewWindow.WEEK) }
    var calendar by rememberSaveable { mutableStateOf(false) }
    val trendScroll = rememberLazyListState()
    val calendarScroll = rememberLazyListState()
    val activity = remember(ui.logs, ui.emotions, window, ui.today) {
        dailyActivity(ui.logs, ui.emotions, window.start(ui.today), ui.today)
    }
    val insight = remember(ui.logs, ui.emotions, window, ui.today) {
        reviewInsight(ui.logs, ui.emotions, window, ui.today)
    }
    val start = window.start(ui.today).toString()
    val end = ui.today.toString()
    val logs = ui.logs.filter { it.recordDate in start..end }
    val emotions = ui.emotions.filter { it.recordDate in start..end }

    Scaffold(
        containerColor = Color.Transparent,
        topBar = {
            TopAppBar(
                title = { Text(com.flash.app.i18n.tr("回顾")) },
                colors = TopAppBarDefaults.topAppBarColors(containerColor = Color.Transparent),
                actions = {
                    androidx.compose.material3.TextButton(onClick = onOpenMemory) { Text("Memory") }
                },
            )
        },
    ) { innerPadding ->
        Column(Modifier.padding(innerPadding).fillMaxSize()) {
            FlashSegmentedControl(
                options = listOf(false to com.flash.app.i18n.tr("趋势"), true to com.flash.app.i18n.tr("日历")),
                selected = calendar,
                onSelect = { calendar = it },
                modifier = Modifier.padding(horizontal = com.flash.app.ui.paper.pageGutter(), vertical = 8.dp),
            )
            if (calendar) {
                CalendarScreen(onOpenRecord, embedded = true, listState = calendarScroll)
            } else {
        LazyColumn(
            state = trendScroll,
            modifier = Modifier.fillMaxSize(),
            contentPadding = PaddingValues(start = com.flash.app.ui.paper.pageGutter(), end = com.flash.app.ui.paper.pageGutter(), top = 8.dp,
                bottom = 8.dp + com.flash.app.ui.navigation.LocalPageBottomPadding.current),
            verticalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            item(key = "range") {
                FlashFilterChipRow(
                    items = ReviewWindow.entries.map { FlashFilterChipItem(it.name, it.label) },
                    selectedKey = window.name,
                    onSelect = { window = ReviewWindow.valueOf(it) },
                )
            }
            item(key = "insight") {
                FlashCard(modifier = Modifier.fillMaxWidth()) {
                    Text(insightHeadline(insight, window),
                        style = MaterialTheme.typography.titleMedium)
                    Text("$start — $end", style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant)
                    if (insight.hasEnoughData) {
                        Text(com.flash.app.i18n.tr("{0} {1} 条 · {2} {3} 条", window.currentName, insight.currentCount, window.previousName, insight.previousCount),
                            style = MaterialTheme.typography.bodyMedium)
                        insight.currentEmotionMean?.let { mean ->
                            Text(com.flash.app.i18n.tr("情绪均值 {0}（-3 至 +3）", formatEmotionMean(mean)),
                                style = MaterialTheme.typography.bodyMedium)
                        }
                    } else {
                        Text(com.flash.app.i18n.tr("{0} 条记录 · {1} 次情绪", logs.size, emotions.size),
                            style = MaterialTheme.typography.bodyMedium)
                    }
                }
            }
            item(key = "activity") { ActivityChart(activity) }
            item(key = "overview") {
                FlashCard(modifier = Modifier.fillMaxWidth()) {
                    Text(com.flash.app.i18n.tr("累计概览 · 全部时间"), style = MaterialTheme.typography.titleSmall)
                    Spacer(Modifier.height(8.dp))
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceEvenly,
                    ) {
                        StatItem("${ui.totalLogs}", com.flash.app.i18n.tr("日志"))
                        StatItem("${ui.totalIdeas}", com.flash.app.i18n.tr("灵感"))
                        StatItem("${ui.totalEmotions}", com.flash.app.i18n.tr("情绪"))
                        StatItem("${ui.activeDays}", com.flash.app.i18n.tr("活跃天数"))
                    }
                }
            }
            item(key = "emotion-stats") {
                // 统计页对应 macOS StatsView「近 7 天/近 30 天」：滚动窗口
                EmotionStatsSection(emotions = ui.emotions, weekAligned = false,
                    window = window.start(ui.today) to ui.today)
            }
        }
            }
        }
    }
}

@Composable
private fun StatItem(value: String, label: String) {
    Column(horizontalAlignment = Alignment.CenterHorizontally) {
        Text(value, style = MaterialTheme.typography.titleLarge.merge(com.flash.app.ui.theme.StatNumberStyle))
        Text(
            label,
            style = MaterialTheme.typography.labelSmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
    }
}

/** 洞察卡首行结论：数据不足时不强行给趋势判断。 */
private fun insightHeadline(insight: ReviewInsight, window: ReviewWindow): String {
    if (!insight.hasEnoughData) return com.flash.app.i18n.tr("继续记录，回顾会慢慢清晰")
    val base = when (insight.trend) {
        ReviewInsight.Trend.MORE -> com.flash.app.i18n.tr("{0}你记录得比{1}更频繁", window.currentName, window.previousName)
        ReviewInsight.Trend.LESS -> com.flash.app.i18n.tr("{0}的记录不如{1}活跃", window.currentName, window.previousName)
        ReviewInsight.Trend.SAME -> com.flash.app.i18n.tr("{0}的记录与{1}持平", window.currentName, window.previousName)
    }
    return when (insight.emotionShift) {
        ReviewInsight.Trend.MORE -> base + com.flash.app.i18n.tr("，情绪整体更好一些")
        ReviewInsight.Trend.LESS -> base + com.flash.app.i18n.tr("，情绪整体更低落一些")
        else -> base
    }
}

private fun formatEmotionMean(mean: Double): String {
    val sign = if (mean > 0) "+" else ""
    val body = if (mean % 1.0 == 0.0) mean.toInt().toString() else mean.toString()
    return sign + body
}
