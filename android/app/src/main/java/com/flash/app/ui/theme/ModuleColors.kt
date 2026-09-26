// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package com.flash.app.ui.theme

import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.luminance

/**
 * 四大模块品牌色（PRD 14 色板：功能识别色）。
 * 用户看到黄色联想到 Idea，粉色联想到 Emotion。
 */
object ModuleColors {
    val Log = Color(0xFF8B5CF6)      // 紫
    val Idea = Color(0xFFF5B800)     // 黄
    val Calendar = Color(0xFF22B573) // 绿
    val Emotion = Color(0xFFFF6B9D)  // 粉

    /**
     * 模块色底上的可读内容色：按 WCAG 对比度在深墨与白之间取更高者。
     * 黄/绿/粉等浅亮色上白字对比不足 3:1，统一收敛到该判定，不用固定阈值拍亮度。
     */
    fun contentOn(background: Color): Color {
        val dark = FlashTokens.Palette.InkPrimary
        fun contrast(a: Color, b: Color): Float {
            val hi = maxOf(a.luminance(), b.luminance()) + 0.05f
            val lo = minOf(a.luminance(), b.luminance()) + 0.05f
            return hi / lo
        }
        return if (contrast(dark, background) >= contrast(Color.White, background)) {
            dark
        } else {
            Color.White
        }
    }
}
