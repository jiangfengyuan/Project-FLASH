package com.flash.app.ui.components

import androidx.compose.ui.graphics.Color
import androidx.core.graphics.toColorInt

/** "#RRGGBB" 字符串转 Compose Color，非法值回退灰色 */
fun String.hexToColor(): Color = try {
    Color(toColorInt())
} catch (e: Exception) {
    Color(0xFF9E9E9E)
}
