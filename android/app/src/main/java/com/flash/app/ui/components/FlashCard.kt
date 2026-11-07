// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package com.flash.app.ui.components

import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.Dp
import com.flash.app.ui.paper.PaperCard
import com.flash.app.ui.theme.FlashTokens

/** 主卡片：圆角 24 的纸卡，用于表单与高密度信息。 */
@Composable
fun FlashCard(
    modifier: Modifier = Modifier,
    seed: String = "flash-card",
    onClick: (() -> Unit)? = null,
    contentPadding: Dp = FlashTokens.Spacing.CardPadding,
    content: @Composable ColumnScope.() -> Unit,
) {
    PaperCard(modifier = modifier, seed = seed, onClick = onClick, contentPadding = contentPadding, content = content)
}
