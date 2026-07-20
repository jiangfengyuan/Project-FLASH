package com.flash.app.ui.emotion

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
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

/** 情绪统计卡片：近 7/30 天日均走势 + 负面子情绪分布，对应 Web 版 StatsPanel */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun EmotionStatsSection(emotions: List<EmotionRecord>) {
    var days by remember { mutableIntStateOf(7) }
    val averages = remember(emotions, days) { EmotionStats.getDailyAverages(emotions, days) }
    val distribution = remember(emotions, days) { EmotionStats.getSubEmotionDistribution(emotions, days) }
    val hasData = remember(emotions, days) { EmotionStats.hasEmotionData(emotions, days) }

    StyleCard(modifier = Modifier.fillMaxWidth()) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(
                "情绪走势",
                style = MaterialTheme.typography.titleSmall,
                modifier = Modifier.weight(1f),
            )
            SingleChoiceSegmentedButtonRow {
                listOf(7, 30).forEachIndexed { index, d ->
                    SegmentedButton(
                        selected = days == d,
                        onClick = { days = d },
                        shape = SegmentedButtonDefaults.itemShape(index = index, count = 2),
                    ) {
                        Text("${d}天")
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
            TrendChart(averages, modifier = Modifier.fillMaxWidth().height(120.dp))
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
                    Box(
                        Modifier
                            .height(8.dp)
                            .fillMaxWidth(count / max.toFloat())
                            .background(
                                MaterialTheme.colorScheme.primary,
                                RoundedCornerShape(4.dp),
                            )
                    )
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

    Canvas(modifier = modifier) {
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
