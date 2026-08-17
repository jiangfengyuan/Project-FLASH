// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package com.flash.app.ui.components

import androidx.compose.ui.graphics.Color
import androidx.core.graphics.toColorInt

/** "#RRGGBB" 字符串转 Compose Color，非法值回退灰色 */
fun String.hexToColor(): Color = try {
    Color(toColorInt())
} catch (e: Exception) {
    Color(0xFF9E9E9E)
}
