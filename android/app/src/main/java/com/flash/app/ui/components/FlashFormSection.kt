// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package com.flash.app.ui.components

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.foundation.layout.padding
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import com.flash.app.ui.theme.FlashTokens

/**
 * 表单分区：小节标题 + 内容组，组内间距 12、标题与内容间距 8。
 * 用于设置项、编辑表单等成组排布的表单内容。
 * 标题缩进 [titleInset]：内容直接贴左缘排布（筛选 Chip 等）时取 0，标题与内容左缘对齐；
 * 内容包在卡片里时传 FlashTokens.Spacing.CardInset，标题与卡内文字左缘对齐（与设置页分组一致）。
 */
@Composable
fun FlashFormSection(
    title: String,
    modifier: Modifier = Modifier,
    titleInset: Dp = 0.dp,
    content: @Composable ColumnScope.() -> Unit,
) {
    Column(
        modifier = modifier,
        verticalArrangement = Arrangement.spacedBy(FlashTokens.Spacing.XS),
    ) {
        Text(
            title,
            style = MaterialTheme.typography.titleSmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            modifier = Modifier.padding(horizontal = titleInset),
        )
        Column(
            verticalArrangement = Arrangement.spacedBy(FlashTokens.Spacing.SM),
            content = content,
        )
    }
}
