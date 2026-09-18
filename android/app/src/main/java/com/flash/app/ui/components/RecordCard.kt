// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package com.flash.app.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.MenuBook
import androidx.compose.material.icons.filled.Lightbulb
import androidx.compose.material.icons.filled.MoreVert
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.flash.app.data.model.Category
import com.flash.app.data.model.LogItem
import com.flash.app.ui.theme.ModuleColors
import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter

private val TIME_FORMAT: DateTimeFormatter = DateTimeFormatter.ofPattern("HH:mm")

/** 卡片内展示时间：recordDate + 本地 HH:mm（createdAt 解析失败时只退化为日期） */
private fun displayTime(log: LogItem): String {
    val time = runCatching {
        Instant.parse(log.createdAt).atZone(ZoneId.systemDefault()).toLocalTime().format(TIME_FORMAT)
    }.getOrNull()
    return if (time != null) "${log.recordDate} $time" else log.recordDate
}

/**
 * 共享记录卡（方案 §4.1/§4.2）：此刻页「最近闪念」与记录页列表复用。
 * 类型色标 + 图标，正文最多两行，底部时间 / 标签 / 重要度；
 * 点击进详情，更多菜单提供编辑 / 删除入口。
 */
@Composable
fun RecordCard(
    log: LogItem,
    modifier: Modifier = Modifier,
    onClick: (() -> Unit)? = null,
    onEdit: (() -> Unit)? = null,
    onDelete: (() -> Unit)? = null,
    showIdeaReminder: Boolean = false,
    actions: (@Composable () -> Unit)? = null,
) {
    val tagColor = log.colorTag.colorHex.hexToColor()
    val typeColor = if (log.category == Category.IDEA) ModuleColors.Idea else ModuleColors.Log
    val typeIcon = if (log.category == Category.IDEA) {
        Icons.Filled.Lightbulb
    } else {
        Icons.AutoMirrored.Filled.MenuBook
    }
    StyleCard(
        modifier = modifier.fillMaxWidth(),
        onClick = onClick,
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Box(
                Modifier
                    .size(10.dp)
                    .clip(CircleShape)
                    .background(tagColor),
            )
            Spacer(Modifier.width(8.dp))
            Icon(
                typeIcon,
                contentDescription = if (log.category == Category.IDEA) "灵感" else "日志",
                tint = typeColor,
                modifier = Modifier.size(18.dp),
            )
            Spacer(Modifier.width(6.dp))
            Text(
                displayTime(log),
                style = MaterialTheme.typography.labelMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            Spacer(Modifier.weight(1f))
            if (onEdit != null || onDelete != null) {
                Box {
                    var menuOpen by remember { mutableStateOf(false) }
                    IconButton(onClick = { menuOpen = true }) {
                        Icon(
                            Icons.Filled.MoreVert,
                            contentDescription = "更多",
                            tint = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                    }
                    DropdownMenu(expanded = menuOpen, onDismissRequest = { menuOpen = false }) {
                        if (onEdit != null) {
                            DropdownMenuItem(
                                text = { Text("编辑") },
                                onClick = {
                                    menuOpen = false
                                    onEdit()
                                },
                            )
                        }
                        if (onDelete != null) {
                            DropdownMenuItem(
                                text = { Text("删除", color = MaterialTheme.colorScheme.error) },
                                onClick = {
                                    menuOpen = false
                                    onDelete()
                                },
                            )
                        }
                    }
                }
            }
            actions?.invoke()
        }
        Spacer(Modifier.height(6.dp))
        Text(
            log.content,
            style = MaterialTheme.typography.bodyLarge,
            color = MaterialTheme.colorScheme.onSurface,
            maxLines = 2,
            overflow = TextOverflow.Ellipsis,
        )
        Spacer(Modifier.height(6.dp))
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(
                log.colorTag.displayName,
                style = MaterialTheme.typography.bodySmall,
                color = tagColor,
                fontWeight = FontWeight.Medium,
            )
            if (log.category == Category.IDEA) {
                Text(
                    " · 灵感",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.tertiary,
                )
                if (showIdeaReminder) {
                    Text(
                        " · 待整理",
                        style = MaterialTheme.typography.labelSmall,
                        color = MaterialTheme.colorScheme.primary,
                        fontWeight = FontWeight.SemiBold,
                    )
                }
            }
            if (log.importance > 0) {
                Text(
                    " · " + "!".repeat(log.importance),
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.error,
                )
            }
        }
    }
}
