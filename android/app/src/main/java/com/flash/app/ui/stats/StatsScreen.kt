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
fun StatsScreen(onOpenSettings: () -> Unit, onOpenRecord: (String) -> Unit) {
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
                title = { Text("回顾") },
                colors = TopAppBarDefaults.topAppBarColors(containerColor = Color.Transparent),
            )
        },
    ) { innerPadding ->
        Column(Modifier.padding(innerPadding).fillMaxSize()) {
            FlashSegmentedControl(
                options = listOf(false to "趋势", true to "日历"),
                selected = calendar,
                onSelect = { calendar = it },
                modifier = Modifier.padding(horizontal = 16.dp, vertical = 8.dp),
            )
            if (calendar) {
                CalendarScreen(onOpenSettings, onOpenRecord, embedded = true, listState = calendarScroll)
            } else {
        LazyColumn(
            state = trendScroll,
            modifier = Modifier.fillMaxSize(),
            contentPadding = PaddingValues(start = 16.dp, end = 16.dp, top = 8.dp,
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
                        Text("${window.currentName} ${insight.currentCount} 条 · ${window.previousName} ${insight.previousCount} 条",
                            style = MaterialTheme.typography.bodyMedium)
                        insight.currentEmotionMean?.let { mean ->
                            Text("情绪均值 ${formatEmotionMean(mean)}（-3 至 +3）",
                                style = MaterialTheme.typography.bodyMedium)
                        }
                    } else {
                        Text("${logs.size} 条记录 · ${emotions.size} 次情绪",
                            style = MaterialTheme.typography.bodyMedium)
                    }
                }
            }
            item(key = "activity") { ActivityChart(activity) }
            item(key = "overview") {
                FlashCard(modifier = Modifier.fillMaxWidth()) {
                    Text("累计概览 · 全部时间", style = MaterialTheme.typography.titleSmall)
                    Spacer(Modifier.height(8.dp))
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceEvenly,
                    ) {
                        StatItem("${ui.totalLogs}", "日志")
                        StatItem("${ui.totalIdeas}", "灵感")
                        StatItem("${ui.totalEmotions}", "情绪")
                        StatItem("${ui.activeDays}", "活跃天数")
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
        Text(value, style = MaterialTheme.typography.titleLarge)
        Text(
            label,
            style = MaterialTheme.typography.labelSmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
    }
}

/** 洞察卡首行结论：数据不足时不强行给趋势判断。 */
private fun insightHeadline(insight: ReviewInsight, window: ReviewWindow): String {
    if (!insight.hasEnoughData) return "继续记录，回顾会慢慢清晰"
    val base = when (insight.trend) {
        ReviewInsight.Trend.MORE -> "${window.currentName}你记录得比${window.previousName}更频繁"
        ReviewInsight.Trend.LESS -> "${window.currentName}不如${window.previousName}活跃"
        ReviewInsight.Trend.SAME -> "${window.currentName}与${window.previousName}持平"
    }
    return when (insight.emotionShift) {
        ReviewInsight.Trend.MORE -> "$base，情绪整体更积极"
        ReviewInsight.Trend.LESS -> "$base，情绪略偏低落"
        else -> base
    }
}

private fun formatEmotionMean(mean: Double): String {
    val sign = if (mean > 0) "+" else ""
    val body = if (mean % 1.0 == 0.0) mean.toInt().toString() else mean.toString()
    return sign + body
}
