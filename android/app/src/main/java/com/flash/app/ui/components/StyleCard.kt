// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package com.flash.app.ui.components

import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.Dp
import com.flash.app.ui.paper.PaperCard
import com.flash.app.ui.theme.FlashTokens

/** 通用纸卡：统计卡 / 日历详情等共用，等价于带行内边距的 PaperCard。 */
@Composable
fun StyleCard(
    modifier: Modifier = Modifier,
    seed: String = "card",
    onClick: (() -> Unit)? = null,
    contentPadding: Dp = FlashTokens.Spacing.MD,
    content: @Composable ColumnScope.() -> Unit,
) {
    PaperCard(
        modifier = modifier,
        seed = seed,
        cornerRadius = FlashTokens.Radius.CardSmall,
        onClick = onClick,
        contentPadding = contentPadding,
        content = content,
    )
}
