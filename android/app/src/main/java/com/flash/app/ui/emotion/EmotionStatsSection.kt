// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package com.flash.app.ui.emotion

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.contentDescription
import java.time.LocalDate
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.SegmentedButton
import androidx.compose.material3.SegmentedButtonDefaults
import androidx.compose.material3.SingleChoiceSegmentedButtonRow
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.unit.dp
import com.flash.app.data.model.EmotionRecord
import com.flash.app.domain.EmotionStats
import com.flash.app.ui.components.StyleCard

/**
 * 情绪统计卡片：日均走势 + 负面子情绪分布，对应 Web 版 StatsPanel。
 * 短档口径由 [weekAligned] 决定：
 * - true：「本周」，周一对齐自然周（对应 macOS 情绪页「本周趋势」）；
 * - false：「7天」，滚动近 7 天。
 * 回顾页传入 window 时由页面范围统一控制，隐藏卡片内的独立选择器。
 * 长档两端均为滚动近 30 天。
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun EmotionStatsSection(
    emotions: List<EmotionRecord>,
    weekAligned: Boolean,
    window: Pair<LocalDate, LocalDate>? = null,
) {
    var selection by remember { mutableIntStateOf(0) }
    val (start, end) = remember(emotions, selection, weekAligned, window) {
        window ?: when {
            selection == 1 -> EmotionStats.rollingWindow(30)
            weekAligned -> EmotionStats.currentWeek()
            else -> EmotionStats.rollingWindow(7)
        }
    }
    val averages = remember(emotions, start, end) { EmotionStats.getDailyAverages(emotions, start, end) }
    val distribution = remember(emotions, start, end) { EmotionStats.getSubEmotionDistribution(emotions, start, end) }
    val hasData = remember(emotions, start, end) { EmotionStats.hasEmotionData(emotions, start, end) }

    StyleCard(modifier = Modifier.fillMaxWidth()) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(
                "情绪走势",
                style = MaterialTheme.typography.titleSmall,
                modifier = Modifier.weight(1f),
            )
            if (window == null) SingleChoiceSegmentedButtonRow {
                listOf(if (weekAligned) "本周" else "7天", "30天").forEachIndexed { index, label ->
                    SegmentedButton(
                        selected = selection == index,
                        onClick = { selection = index },
                        shape = SegmentedButtonDefaults.itemShape(index = index, count = 2),
                    ) {
                        Text(label)
                    }
                }
            }
        }
        Spacer(Modifier.height(12.dp))
        if (!hasData) {
            Text(
                "时间窗内暂无记录",
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        } else {
            Text("日均情绪 · -3 至 +3（0 为中性）", style = MaterialTheme.typography.bodySmall)
            TrendChart(averages, modifier = Modifier.fillMaxWidth().height(120.dp))
            Text("$start — $end · 无记录日期不计入均值", style = MaterialTheme.typography.bodySmall)
        }
        if (distribution.isNotEmpty()) {
            Spacer(Modifier.height(12.dp))
            Text("负面子情绪分布", style = MaterialTheme.typography.labelLarge)
            Spacer(Modifier.height(8.dp))
            val max = distribution.maxOf { it.second }.coerceAtLeast(1)
            distribution.forEach { (name, count) ->
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    modifier = Modifier.padding(vertical = 2.dp),
                ) {
                    Text(
                        name,
                        style = MaterialTheme.typography.bodySmall,
                        modifier = Modifier.width(40.dp),
                    )
                    Box(Modifier.weight(1f)) {
                    Box(
                        Modifier
                            .height(8.dp)
                            .fillMaxWidth(count / max.toFloat())
                            .background(
                                MaterialTheme.colorScheme.primary,
                                RoundedCornerShape(4.dp),
                            )
                    )
                    }
                    Spacer(Modifier.width(8.dp))
                    Text("$count", style = MaterialTheme.typography.bodySmall)
                }
            }
        }
    }
}

/** 日均值折线图：y 轴 -3..+3，零线参考；无动画，保持克制 */
@Composable
private fun TrendChart(
    averages: List<Pair<java.time.LocalDate, Double?>>,
    modifier: Modifier = Modifier,
) {
    val lineColor = MaterialTheme.colorScheme.primary
    val gridColor = MaterialTheme.colorScheme.outlineVariant
    val pointColor = MaterialTheme.colorScheme.tertiary

    val description = averages.filter { it.second != null }
        .joinToString("；") { "${it.first}：${it.second}" }
    Canvas(modifier = modifier.semantics { contentDescription = "每日情绪均值：$description" }) {
        if (averages.isEmpty()) return@Canvas
        val width = size.width
        val height = size.height
        val xStep = if (averages.size > 1) width / (averages.size - 1) else 0f

        fun yFor(value: Double): Float {
            val clamped = value.coerceIn(-3.0, 3.0)
            return ((3.0 - clamped) / 6.0 * height).toFloat()
        }

        // 零线
        drawLine(
            color = gridColor,
            start = Offset(0f, yFor(0.0)),
            end = Offset(width, yFor(0.0)),
            strokeWidth = 1.dp.toPx(),
        )

        val points = averages.mapIndexedNotNull { index, (_, avg) ->
            avg?.let { Offset(index * xStep, yFor(it)) }
        }
        if (points.size >= 2) {
            val path = Path().apply {
                moveTo(points.first().x, points.first().y)
                points.drop(1).forEach { lineTo(it.x, it.y) }
            }
            drawPath(path, color = lineColor, style = Stroke(width = 2.dp.toPx()))
        }
        points.forEach { p ->
            drawCircle(color = pointColor, radius = 3.dp.toPx(), center = p)
        }
    }
}
