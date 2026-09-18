// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package com.flash.app.ui.components

import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import com.flash.app.ui.theme.FlashTokens
import com.flash.app.ui.theme.LocalIsDarkTheme

/**
 * 分段选择器：等宽分段，选中段为深墨色实心圆角块，
 * 颜色以 200ms 淡入过渡（选中态 160–240ms 令牌），不用弹跳。
 */
@Composable
fun <T> FlashSegmentedControl(
    options: List<Pair<T, String>>,
    selected: T,
    onSelect: (T) -> Unit,
    modifier: Modifier = Modifier,
) {
    val dark = LocalIsDarkTheme.current
    Row(
        modifier = modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(50))
            .background(MaterialTheme.colorScheme.surfaceVariant)
            .padding(4.dp),
    ) {
        options.forEach { (value, label) ->
            val isSelected = value == selected
            val segmentColor by animateColorAsState(
                targetValue = if (isSelected) {
                    FlashTokens.Palette.selectionFill(dark)
                } else {
                    Color.Transparent
                },
                animationSpec = tween(FlashTokens.Motion.SelectionMs),
                label = "Flash segment container",
            )
            val textColor by animateColorAsState(
                targetValue = if (isSelected) {
                    FlashTokens.Palette.onSelectionFill(dark)
                } else {
                    MaterialTheme.colorScheme.onSurfaceVariant
                },
                animationSpec = tween(FlashTokens.Motion.SelectionMs),
                label = "Flash segment content",
            )
            Box(
                modifier = Modifier
                    .weight(1f)
                    .heightIn(min = FlashTokens.Touch.IconButtonMin)
                    .clip(RoundedCornerShape(50))
                    .background(segmentColor)
                    .clickable { onSelect(value) },
                contentAlignment = Alignment.Center,
            ) {
                Text(label, style = MaterialTheme.typography.labelLarge, color = textColor)
            }
        }
    }
}
