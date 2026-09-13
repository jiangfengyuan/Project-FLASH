// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package com.flash.app.ui.components

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Surface
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import com.flash.app.ui.theme.FlashTokens
import com.flash.app.ui.theme.LocalIsDarkTheme

/**
 * 实体卡片：浅色 `#FFFFFF`、深色用品牌弱表面，圆角 24。
 * 两种界面风格下都是实色面——列表、表单、高密度信息不依赖玻璃模糊。
 * 与 StyleCard（风格感知）并存：需要玻璃观感的小卡片继续用 StyleCard。
 */
@Composable
fun FlashCard(
    modifier: Modifier = Modifier,
    onClick: (() -> Unit)? = null,
    contentPadding: Dp = FlashTokens.Spacing.MD,
    content: @Composable ColumnScope.() -> Unit,
) {
    val shape = RoundedCornerShape(FlashTokens.Radius.Card)
    val color = FlashTokens.Palette.cardSurface(LocalIsDarkTheme.current)
    if (onClick != null) {
        Surface(
            onClick = onClick,
            modifier = modifier,
            shape = shape,
            color = color,
            shadowElevation = 2.dp,
        ) {
            Column(Modifier.padding(contentPadding), content = content)
        }
    } else {
        Surface(
            modifier = modifier,
            shape = shape,
            color = color,
            shadowElevation = 2.dp,
        ) {
            Column(Modifier.padding(contentPadding), content = content)
        }
    }
}
