// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package com.flash.app.ui.theme

import androidx.compose.material3.Typography
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.Font
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.sp
import com.flash.app.R
import com.flash.app.i18n.Strings

/** 随包霞鹜文楷（OFL，GB2312 子集）：只用于中文的页面标题、问候语、区块短标题与单行关键摘录 */
private val WenKai = FontFamily(Font(R.font.lxgw_wenkai_medium, FontWeight.Medium))

/** 展示字体：中文用霞鹜文楷；其他语言该子集覆盖不足，用系统衬线 */
fun displayFontFamily(): FontFamily = if (Strings.usesBundledDisplayFont()) WenKai else FontFamily.Serif

/** 统计数字：系统衬线粗体 */
val StatNumberStyle = TextStyle(fontFamily = FontFamily.Serif, fontWeight = FontWeight.Bold)

/** 正文约 1.5 倍行高；标题走展示字体，其余沿用 Material 层级（sp，随系统字体缩放） */
fun flashTypography(): Typography {
    val base = Typography()
    val display = displayFontFamily()
    fun TextStyle.asDisplay() = copy(fontFamily = display, fontWeight = FontWeight.Medium)
    return base.copy(
        headlineLarge = base.headlineLarge.asDisplay(),
        headlineMedium = base.headlineMedium.asDisplay(),
        headlineSmall = base.headlineSmall.asDisplay(),
        titleLarge = base.titleLarge.asDisplay(),
        titleMedium = base.titleMedium.asDisplay(),
        bodyLarge = base.bodyLarge.copy(lineHeight = 24.sp),
        bodyMedium = base.bodyMedium.copy(lineHeight = 21.sp),
    )
}
