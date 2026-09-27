// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package com.flash.app.ui.components

import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.flash.app.ui.theme.FlashTokens
import com.flash.app.ui.theme.LocalIsDarkTheme

data class FlashFilterChipItem(val key: String, val label: String)

/**
 * 筛选 Chip 行：横向可滚动，间距 8。
 * 结构性选中态使用深墨色实心背景 + 反色文字，未选中为描边样式；
 * 选中/未选中颜色以 200ms 淡入过渡（选中态 160–240ms 令牌）。
 */
@Composable
fun FlashFilterChipRow(
    items: List<FlashFilterChipItem>,
    selectedKey: String?,
    onSelect: (String) -> Unit,
    modifier: Modifier = Modifier,
) {
    Row(
        modifier = modifier.horizontalScroll(rememberScrollState()),
        horizontalArrangement = Arrangement.spacedBy(FlashTokens.Spacing.XS),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        items.forEach { item ->
            FlashFilterChip(
                label = item.label,
                selected = item.key == selectedKey,
                onClick = { onSelect(item.key) },
            )
        }
    }
}

@Composable
private fun FlashFilterChip(
    label: String,
    selected: Boolean,
    onClick: () -> Unit,
) {
    val dark = LocalIsDarkTheme.current
    val container by animateColorAsState(
        targetValue = if (selected) {
            FlashTokens.Palette.selectionFill(dark)
        } else {
            androidx.compose.ui.graphics.Color.Transparent
        },
        animationSpec = tween(FlashTokens.Motion.SelectionMs),
        label = "Flash chip container",
    )
    val contentColor by animateColorAsState(
        targetValue = if (selected) {
            FlashTokens.Palette.onSelectionFill(dark)
        } else {
            MaterialTheme.colorScheme.onSurfaceVariant
        },
        animationSpec = tween(FlashTokens.Motion.SelectionMs),
        label = "Flash chip content",
    )
    Surface(
        onClick = onClick,
        shape = RoundedCornerShape(50),
        color = container,
        border = if (selected) {
            null
        } else {
            androidx.compose.foundation.BorderStroke(
                1.dp,
                MaterialTheme.colorScheme.outlineVariant,
            )
        },
        modifier = Modifier.heightIn(min = FlashTokens.Touch.IconButtonMin),
    ) {
        Box(contentAlignment = Alignment.Center) {
            Text(
                text = label,
                style = MaterialTheme.typography.labelLarge,
                color = contentColor,
                modifier = Modifier.padding(
                    horizontal = FlashTokens.Spacing.MD,
                    vertical = FlashTokens.Spacing.XS,
                ),
            )
        }
    }
}
