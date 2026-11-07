// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package com.flash.app.ui.components

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Star
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.Icon
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
import androidx.compose.ui.graphics.Color
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.flash.app.data.model.Category
import com.flash.app.data.model.LogItem
import com.flash.app.i18n.tr
import com.flash.app.ui.paper.PaperCardShape
import com.flash.app.ui.paper.StickyStack
import com.flash.app.ui.paper.paperShadow
import com.flash.app.ui.paper.stampBadge
import com.flash.app.ui.theme.FlashTokens
import com.flash.app.ui.theme.LocalIsDarkTheme
import com.flash.app.ui.theme.ModuleColors
import com.flash.app.ui.theme.PaperColors
import com.flash.app.ui.theme.textColor
import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter

private val TIME_FORMAT: DateTimeFormatter = DateTimeFormatter.ofPattern("HH:mm", java.util.Locale.ROOT)

/** 卡片内展示时间：recordDate + 本地 HH:mm（createdAt 解析失败时只退化为日期） */
private fun displayTime(log: LogItem): String {
    val time = runCatching {
        Instant.parse(log.createdAt).atZone(ZoneId.systemDefault()).toLocalTime().format(TIME_FORMAT)
    }.getOrNull()
    return if (time != null) "${log.recordDate} $time" else log.recordDate
}

/** 长按菜单的操作；为 null 的项不显示 */
data class RecordMenu(
    val onEdit: (() -> Unit)? = null,
    val onToggleFavorite: (() -> Unit)? = null,
    val onConvertToTask: (() -> Unit)? = null,
    val onDelete: (() -> Unit)? = null,
)

/**
 * 记录卡（此刻「最近闪念」、记录页、日志流、日历共用）：
 * 印章标签 + 未读/重要度/收藏 + 时间，下方正文。点按编辑，长按打开菜单。
 * `sticky` 时身后错开一张便签底页（最近闪念里的灵感）。
 */
@OptIn(ExperimentalFoundationApi::class)
@Composable
fun RecordCard(
    log: LogItem,
    modifier: Modifier = Modifier,
    onClick: (() -> Unit)? = null,
    menu: RecordMenu = RecordMenu(),
    isUnread: Boolean = false,
    sticky: Boolean = false,
    selected: Boolean = false,
    maxLines: Int = Int.MAX_VALUE,
    onLongClick: (() -> Unit)? = null,
) {
    val dark = LocalIsDarkTheme.current
    val shape = remember(log.id) { PaperCardShape(log.id, FlashTokens.Radius.Row) }
    val surface = PaperColors.CardSurface.resolve(dark)
    val border = if (selected) PaperColors.BrandPrimary.resolve(dark) else PaperColors.WeakBorder.resolve(dark)
    var menuOpen by remember { mutableStateOf(false) }
    val hasMenu = menu.onEdit != null || menu.onToggleFavorite != null ||
        menu.onConvertToTask != null || menu.onDelete != null
    StickyStack(seed = log.id, enabled = sticky, modifier = modifier.fillMaxWidth()) {
        Box {
            Column(
                Modifier
                    .fillMaxWidth()
                    .paperShadow(shape, isDark = dark)
                    .clip(shape)
                    .background(surface)
                    .border(if (selected) 1.5.dp else 0.75.dp, border, shape)
                    .combinedClickable(
                        role = Role.Button,
                        enabled = onClick != null || hasMenu || onLongClick != null,
                        onClick = { onClick?.invoke() },
                        onLongClick = when {
                            onLongClick != null -> onLongClick
                            hasMenu -> ({ menuOpen = true })
                            else -> null
                        },
                    )
                    .padding(FlashTokens.Spacing.MD),
                verticalArrangement = Arrangement.spacedBy(10.dp),
            ) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Row(
                        modifier = Modifier.weight(1f),
                        horizontalArrangement = Arrangement.spacedBy(FlashTokens.Spacing.XS),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Text(
                            log.colorTag.displayName,
                            style = MaterialTheme.typography.labelMedium,
                            color = log.colorTag.textColor(dark),
                            modifier = Modifier.stampBadge(log.colorTag.textColor(dark)),
                        )
                        if (isUnread) {
                            Text(
                                tr("未读"),
                                style = MaterialTheme.typography.labelMedium,
                                fontWeight = FontWeight.Bold,
                                color = ModuleColors.IdeaText,
                            )
                        }
                        if (log.importance > 0) {
                            Text(
                                "!".repeat(log.importance),
                                style = MaterialTheme.typography.labelMedium,
                                fontWeight = FontWeight.Bold,
                                color = MaterialTheme.colorScheme.error,
                            )
                        }
                    }
                    if (log.isFavorite == true) {
                        Icon(
                            Icons.Filled.Star,
                            contentDescription = tr("已收藏"),
                            tint = ModuleColors.IdeaText,
                            modifier = Modifier.padding(end = FlashTokens.Spacing.XS).size(14.dp),
                        )
                    }
                    Text(
                        displayTime(log),
                        style = MaterialTheme.typography.labelSmall,
                        color = MaterialTheme.colorScheme.outline,
                    )
                }
                Text(
                    log.content,
                    style = MaterialTheme.typography.bodyLarge,
                    color = MaterialTheme.colorScheme.onSurface,
                    maxLines = maxLines,
                    overflow = TextOverflow.Ellipsis,
                )
            }
            DropdownMenu(expanded = menuOpen, onDismissRequest = { menuOpen = false }) {
                menu.onEdit?.let { action ->
                    DropdownMenuItem(text = { Text(tr("编辑")) }, onClick = { menuOpen = false; action() })
                }
                menu.onToggleFavorite?.let { action ->
                    DropdownMenuItem(
                        text = { Text(if (log.isFavorite == true) tr("取消收藏") else tr("收藏")) },
                        onClick = { menuOpen = false; action() },
                    )
                }
                if (log.category == Category.IDEA) {
                    menu.onConvertToTask?.let { action ->
                        DropdownMenuItem(text = { Text(tr("转为任务")) }, onClick = { menuOpen = false; action() })
                    }
                }
                menu.onDelete?.let { action ->
                    DropdownMenuItem(
                        text = { Text(tr("删除"), color = MaterialTheme.colorScheme.error) },
                        onClick = { menuOpen = false; action() },
                    )
                }
            }
        }
    }
}

/** 日志流 / 日历沿用的入口：与记录卡同一视觉，右上可挂自定义操作。 */
@Composable
fun LogCard(
    log: LogItem,
    modifier: Modifier = Modifier,
    onClick: (() -> Unit)? = null,
    actions: (@Composable () -> Unit)? = null,
    showIdeaReminder: Boolean = false,
    menu: RecordMenu = RecordMenu(),
) {
    Box(modifier) {
        RecordCard(log = log, onClick = onClick, isUnread = showIdeaReminder, menu = menu)
        if (actions != null) {
            Box(Modifier.align(Alignment.TopEnd).padding(top = 28.dp)) { actions() }
        }
    }
}
