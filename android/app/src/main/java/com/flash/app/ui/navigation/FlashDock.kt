// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package com.flash.app.ui.navigation

import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.selection.selectable
import androidx.compose.foundation.selection.selectableGroup
import androidx.compose.ui.semantics.Role
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
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
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import com.flash.app.data.UiStyle
import com.flash.app.ui.theme.FlashTokens
import com.flash.app.ui.theme.LocalIsDarkTheme
import com.flash.app.ui.theme.LocalUiStyle
import com.flash.app.ui.theme.glass.glass

/**
 * 悬浮 Flash Dock：与 56dp FAB 等高的图标胶囊，悬浮于内容之上。
 * GLASS → 强玻璃面（模糊+半透+描边）；MD3 → 实体白卡 + 柔和投影。
 * 选中态：品牌 primaryContainer 圆形指示淡入，图标始终居中。
 */
@Composable
fun FlashDock(
    currentRoute: String?,
    onSelect: (TabDest) -> Unit,
    badgeCount: (String) -> Int,
    modifier: Modifier = Modifier,
) {
    val isGlass = LocalUiStyle.current == UiStyle.GLASS
    val dark = LocalIsDarkTheme.current
    val shape = RoundedCornerShape(FlashTokens.Radius.Focus)
    val container = if (isGlass) {
        modifier.glass(shape = shape, strong = true)
            .background(MaterialTheme.colorScheme.surfaceContainerHigh.copy(alpha = 0.92f))
    } else {
        modifier
            .shadow(12.dp, shape)
            .clip(shape)
            .background(
                if (dark) {
                    MaterialTheme.colorScheme.surfaceContainerHigh
                } else {
                    FlashTokens.Palette.CardSurface
                },
            )
    }
    Row(
        modifier = container
            .fillMaxWidth()
            .height(FlashTokens.Dock.Height)
            .selectableGroup()
            .padding(horizontal = FlashTokens.Spacing.XS),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        TABS.forEach { tab ->
            DockItem(
                tab = tab,
                selected = currentRoute == tab.route,
                badge = badgeCount(tab.route),
                onClick = { onSelect(tab) },
            )
        }
    }
}

@Composable
private fun RowScope.DockItem(
    tab: TabDest,
    selected: Boolean,
    badge: Int,
    onClick: () -> Unit,
) {
    val indicatorColor by animateColorAsState(
        targetValue = if (selected) MaterialTheme.colorScheme.primaryContainer else Color.Transparent,
        animationSpec = tween(FlashTokens.Motion.SelectionMs),
        label = "Dock indicator",
    )
    val iconColor by animateColorAsState(
        targetValue = if (selected) {
            MaterialTheme.colorScheme.onPrimaryContainer
        } else {
            MaterialTheme.colorScheme.onSurfaceVariant
        },
        animationSpec = tween(FlashTokens.Motion.SelectionMs),
        label = "Dock icon color",
    )

    Box(
        modifier = Modifier
            .weight(1f)
            .fillMaxHeight(),
        contentAlignment = Alignment.Center,
    ) {
        // The hit target, ripple clip and selected surface share one circle.
        // Applying selectable to the weighted slot creates a wider oval ripple.
        Box(
            modifier = Modifier
                .size(FlashTokens.Touch.IconButtonMin)
                .clip(CircleShape)
                .background(indicatorColor)
                .selectable(selected = selected, role = Role.Tab, onClick = onClick),
            contentAlignment = Alignment.Center,
        ) {
            BadgedBox(
                badge = {
                    if (badge > 0) {
                        Badge { Text(if (badge > 99) "99+" else badge.toString()) }
                    }
                },
            ) {
                Icon(tab.icon, contentDescription = tab.label, tint = iconColor)
            }
        }
    }
}
