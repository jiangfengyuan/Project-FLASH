// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package com.flash.app.ui.stats

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.*
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import com.flash.app.domain.DailyActivity
import com.flash.app.ui.components.FlashCard

@Composable
internal fun ActivityChart(days: List<DailyActivity>) {
    var expanded by rememberSaveable { mutableStateOf(false) }
    val maximum = days.maxOfOrNull { it.total }?.coerceAtLeast(1) ?: 1
    val active = days.count { it.total > 0 }
    val color = MaterialTheme.colorScheme.primary
    val grid = MaterialTheme.colorScheme.outlineVariant
    FlashCard(Modifier.fillMaxWidth()) {
        Text("记录活跃度", style = MaterialTheme.typography.titleMedium)
        Text("每天的日志、灵感与情绪次数 · 不含任务", style = MaterialTheme.typography.bodySmall)
        Text("$active 个活跃日 · 共 ${days.sumOf { it.total }} 次",
            style = MaterialTheme.typography.bodyMedium)
        Spacer(Modifier.height(12.dp))
        Text("$maximum 次", style = MaterialTheme.typography.labelSmall)
        Canvas(Modifier.fillMaxWidth().height(128.dp).semantics {
            contentDescription = "记录活跃度，${days.size} 天中 $active 天有记录，共 ${days.sumOf { it.total }} 次。可展开每日明细。"
        }) {
            if (days.isEmpty()) return@Canvas
            val slot = size.width / days.size
            drawLine(grid, Offset(0f, size.height), Offset(size.width, size.height))
            drawLine(grid, Offset.Zero, Offset(size.width, 0f))
            days.forEachIndexed { index, day ->
                val height = size.height * day.total / maximum
                if (height > 0) drawRect(color,
                    topLeft = Offset(index * slot + slot * 0.15f, size.height - height),
                    size = Size(slot * 0.7f, height))
            }
        }
        Text("0", style = MaterialTheme.typography.labelSmall)
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
            Text(days.firstOrNull()?.date?.toString().orEmpty(), style = MaterialTheme.typography.labelSmall)
            Text(days.lastOrNull()?.date?.toString().orEmpty(), style = MaterialTheme.typography.labelSmall)
        }
        if (active == 0) Text("这段时间还没有记录，空白日期按 0 次显示。",
            style = MaterialTheme.typography.bodySmall)
        TextButton(onClick = { expanded = !expanded }) {
            Text(if (expanded) "收起每日明细" else "查看每日明细")
        }
        if (expanded) days.forEach { day ->
            Text("${day.date}：${day.records} 条记录 · ${day.emotions} 次情绪",
                style = MaterialTheme.typography.bodySmall)
        }
    }
}
