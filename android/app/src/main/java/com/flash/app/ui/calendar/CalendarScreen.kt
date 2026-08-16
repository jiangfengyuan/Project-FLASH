package com.flash.app.ui.calendar

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowLeft
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material.icons.filled.Settings
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
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import com.flash.app.FlashApplication
import com.flash.app.ui.components.LogCard
import com.flash.app.ui.components.StyleCard
import com.flash.app.ui.components.hexToColor
import java.time.LocalDate
import java.time.YearMonth

private val WEEKDAYS = listOf("一", "二", "三", "四", "五", "六", "日")

/** Calendar Tab：真实月视图 + 选中日详情 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun CalendarScreen(onOpenSettings: () -> Unit) {
    val app = LocalContext.current.applicationContext as FlashApplication
    val viewModel: CalendarViewModel = viewModel(factory = CalendarViewModel.factory(app.repository))
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()

    Scaffold(
        containerColor = Color.Transparent,
        topBar = {
            TopAppBar(
                title = { Text("日历") },
                colors = TopAppBarDefaults.topAppBarColors(containerColor = Color.Transparent),
                actions = {
                    IconButton(onClick = onOpenSettings) {
                        Icon(Icons.Filled.Settings, contentDescription = "设置")
                    }
                },
            )
        },
    ) { innerPadding ->
        LazyColumn(
            modifier = Modifier
                .padding(innerPadding)
                .fillMaxSize(),
            contentPadding = PaddingValues(horizontal = 16.dp, vertical = 8.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            item(key = "month-header") {
                MonthHeader(
                    month = uiState.month,
                    onPrev = viewModel::prevMonth,
                    onNext = viewModel::nextMonth,
                    onToday = viewModel::backToToday,
                )
            }
            item(key = "weekdays") {
                Row {
                    WEEKDAYS.forEach { day ->
                        Text(
                            day,
                            modifier = Modifier.weight(1f),
                            textAlign = TextAlign.Center,
                            style = MaterialTheme.typography.labelMedium,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                    }
                }
            }
            item(key = "grid") {
                MonthGrid(
                    uiState = uiState,
                    onSelect = viewModel::selectDate,
                )
            }
            item(key = "detail-header") {
                Spacer(Modifier.height(8.dp))
                Text(
                    "${uiState.selectedDate} 详情",
                    style = MaterialTheme.typography.titleSmall,
                )
            }
            item(key = "detail") {
                DayDetail(uiState.selectedAggregate)
            }
        }
    }
}

@Composable
private fun MonthHeader(
    month: YearMonth,
    onPrev: () -> Unit,
    onNext: () -> Unit,
    onToday: () -> Unit,
) {
    Row(verticalAlignment = Alignment.CenterVertically) {
        IconButton(onClick = onPrev) {
            Icon(Icons.AutoMirrored.Filled.KeyboardArrowLeft, contentDescription = "上一月")
        }
        Text(
            "${month.year} 年 ${month.monthValue} 月",
            style = MaterialTheme.typography.titleMedium,
            fontWeight = FontWeight.Medium,
            modifier = Modifier.weight(1f),
            textAlign = TextAlign.Center,
        )
        TextButton(onClick = onToday) { Text("今天") }
        IconButton(onClick = onNext) {
            Icon(Icons.AutoMirrored.Filled.KeyboardArrowRight, contentDescription = "下一月")
        }
    }
}

@Composable
private fun MonthGrid(uiState: CalendarUiState, onSelect: (LocalDate) -> Unit) {
    Column {
        uiState.weeks.forEach { week ->
            Row {
                week.forEach { date ->
                    DayCell(
                        date = date,
                        inMonth = YearMonth.from(date) == uiState.month,
                        isToday = date == LocalDate.now(),
                        isSelected = date == uiState.selectedDate,
                        aggregate = uiState.aggregates[date.toString()],
                        onClick = { onSelect(date) },
                        modifier = Modifier.weight(1f),
                    )
                }
            }
        }
    }
}

@Composable
private fun DayCell(
    date: LocalDate,
    inMonth: Boolean,
    isToday: Boolean,
    isSelected: Boolean,
    aggregate: DayAggregate?,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val borderColor = when {
        isSelected -> MaterialTheme.colorScheme.primary
        isToday -> MaterialTheme.colorScheme.outline
        else -> MaterialTheme.colorScheme.surface
    }
    Column(
        modifier = modifier
            .aspectRatio(1f)
            .padding(2.dp)
            .border(1.dp, borderColor, MaterialTheme.shapes.small)
            .clickable(onClick = onClick)
            .padding(2.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Text(
            "${date.dayOfMonth}",
            style = MaterialTheme.typography.labelMedium,
            fontWeight = if (isToday) FontWeight.Bold else FontWeight.Normal,
            color = when {
                // 非当月日期：比当月弱但在浅渐变背景上仍可辨
                !inMonth -> MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.6f)
                isToday -> MaterialTheme.colorScheme.primary
                else -> MaterialTheme.colorScheme.onSurface
            },
        )
        if (aggregate != null) {
            // 情绪圆点（最多 3 个）+ 日志数
            Row(
                horizontalArrangement = Arrangement.Center,
                modifier = Modifier.padding(top = 2.dp),
            ) {
                aggregate.emotions.take(3).forEach { emotion ->
                    Box(
                        Modifier
                            .size(5.dp)
                            .clip(CircleShape)
                            .background(emotion.level.colorHex.hexToColor())
                    )
                    Spacer(Modifier.width(1.dp))
                }
            }
            if (aggregate.logs.isNotEmpty()) {
                Text(
                    "${aggregate.logs.size}",
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
        }
    }
}

@Composable
private fun DayDetail(aggregate: DayAggregate?) {
    if (aggregate == null || (aggregate.logs.isEmpty() && aggregate.emotions.isEmpty())) {
        Text(
            "这一天没有记录",
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            modifier = Modifier.padding(vertical = 16.dp),
        )
        return
    }
    StyleCard(modifier = Modifier.fillMaxWidth()) {
        if (aggregate.emotions.isNotEmpty()) {
            val avg = aggregate.emotions.map { it.level.value }.average()
            Text(
                "平均情绪 %.1f · 共 %d 条".format(avg, aggregate.emotions.size),
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            aggregate.emotions.forEach { emotion ->
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    modifier = Modifier.padding(top = 4.dp),
                ) {
                    Box(
                        Modifier
                            .size(10.dp)
                            .clip(CircleShape)
                            .background(emotion.level.colorHex.hexToColor())
                    )
                    Spacer(Modifier.width(8.dp))
                    Text(
                        emotion.level.displayName +
                            (emotion.subEmotion?.let { " · ${it.displayName}" } ?: ""),
                        style = MaterialTheme.typography.bodyMedium,
                    )
                }
            }
        }
        aggregate.logs.forEach { log ->
            LogCard(log = log, modifier = Modifier.padding(top = 8.dp))
        }
    }
}
