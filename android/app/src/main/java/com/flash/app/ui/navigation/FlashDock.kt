// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package com.flash.app.ui.navigation

import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.selection.selectable
import androidx.compose.foundation.selection.selectableGroup
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.AutoAwesome
import androidx.compose.material3.Badge
import androidx.compose.material3.BadgedBox
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.flash.app.i18n.tr
import com.flash.app.ui.paper.vellum
import com.flash.app.ui.theme.FlashTokens

/**
 * 悬浮底栏：硫酸纸胶囊，五个 Tab（图标 + 文字），选中项落在羊皮纸底上。
 * 文字单行，长语言（德语、俄语）放不下时省略号而不换行；放大字号时只留图标。
 */
@Composable
fun FlashDock(
    currentRoute: String?,
    onSelect: (TabDest) -> Unit,
    badgeCount: (String) -> Int,
    modifier: Modifier = Modifier,
) {
    val shape = RoundedCornerShape(FlashTokens.Radius.Focus)
    Row(
        modifier = modifier
            .vellum(shape)
            .fillMaxWidth()
            .height(FlashTokens.Dock.Height)
            .selectableGroup()
            .padding(horizontal = FlashTokens.Spacing.XS),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        TABS.forEach { tab ->
            DockItem(tab, currentRoute == tab.route, badgeCount(tab.route)) { onSelect(tab) }
        }
    }
}

@Composable
private fun RowScope.DockItem(tab: TabDest, selected: Boolean, badge: Int, onClick: () -> Unit) {
    val indicator by animateColorAsState(
        if (selected) MaterialTheme.colorScheme.primaryContainer else Color.Transparent,
        tween(FlashTokens.Motion.SelectionMs),
        label = "Dock indicator",
    )
    val tint by animateColorAsState(
        if (selected) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurfaceVariant,
        tween(FlashTokens.Motion.SelectionMs),
        label = "Dock icon color",
    )
    val showLabel = LocalDensity.current.fontScale < 1.5f
    Box(Modifier.weight(1f).fillMaxHeight(), contentAlignment = Alignment.Center) {
        Column(
            modifier = Modifier
                .clip(RoundedCornerShape(FlashTokens.Radius.CardSmall))
                .background(indicator)
                .selectable(selected = selected, role = Role.Tab, onClick = onClick)
                .padding(horizontal = 4.dp, vertical = 4.dp)
                .fillMaxWidth(),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            BadgedBox(
                badge = {
                    if (badge > 0) {
                        Badge(
                            containerColor = MaterialTheme.colorScheme.primary,
                            contentColor = MaterialTheme.colorScheme.onPrimary,
                        ) { Text(if (badge > 99) "99+" else badge.toString()) }
                    }
                },
            ) {
                Icon(tab.icon, contentDescription = tab.label, tint = tint, modifier = Modifier.size(24.dp))
            }
            if (showLabel) {
                Text(
                    tab.label,
                    style = MaterialTheme.typography.labelSmall,
                    color = tint,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
            }
        }
    }
}

/** 常驻快速记录条（窄屏，底栏上方）：对齐 iOS 26 标签栏配件 */
@Composable
fun QuickCaptureBar(onClick: () -> Unit, modifier: Modifier = Modifier) {
    val shape = RoundedCornerShape(FlashTokens.Radius.Focus)
    Row(
        modifier = modifier
            .vellum(shape)
            .fillMaxWidth()
            .heightIn(min = FlashTokens.Dock.CaptureBarHeight)
            .clickable(role = Role.Button, onClickLabel = tr("快速记录"), onClick = onClick)
            .padding(horizontal = FlashTokens.Spacing.PageHorizontal),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(FlashTokens.Spacing.SM),
    ) {
        Icon(
            Icons.Filled.AutoAwesome,
            contentDescription = null,
            tint = MaterialTheme.colorScheme.primary,
            modifier = Modifier.size(20.dp),
        )
        Text(
            tr("现在想记录什么？"),
            style = MaterialTheme.typography.titleMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
        )
        Spacer(Modifier.weight(1f))
    }
}

/** 宽屏（≥ 600dp）右下角悬浮按钮 */
@Composable
fun QuickCaptureFab(onClick: () -> Unit, modifier: Modifier = Modifier) {
    Box(
        modifier = modifier
            .size(FlashTokens.Touch.FabMain)
            .vellum(CircleShape)
            .clip(CircleShape)
            .background(MaterialTheme.colorScheme.primary)
            .clickable(role = Role.Button, onClickLabel = tr("快速记录"), onClick = onClick),
        contentAlignment = Alignment.Center,
    ) {
        Icon(Icons.Filled.Add, contentDescription = tr("快速记录"), tint = MaterialTheme.colorScheme.onPrimary)
    }
}
