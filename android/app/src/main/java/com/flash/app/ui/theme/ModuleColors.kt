// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package com.flash.app.ui.theme

import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.luminance
import androidx.compose.runtime.Composable
import androidx.compose.runtime.ReadOnlyComposable

/** 四大模块色（图标与点缀，≥ 3:1；文字用 *Text 变体）。见 PaperColors。 */
object ModuleColors {
    val Log: Color @Composable @ReadOnlyComposable get() = PaperColors.LogPurple.resolve(LocalIsDarkTheme.current)
    val Idea: Color @Composable @ReadOnlyComposable get() = PaperColors.IdeaYellow.resolve(LocalIsDarkTheme.current)
    val IdeaText: Color @Composable @ReadOnlyComposable get() = PaperColors.IdeaYellowText.resolve(LocalIsDarkTheme.current)
    val Calendar: Color @Composable @ReadOnlyComposable get() = PaperColors.CalendarGreen.resolve(LocalIsDarkTheme.current)
    val CalendarText: Color @Composable @ReadOnlyComposable get() = PaperColors.AccessibleGreen.resolve(LocalIsDarkTheme.current)
    val Emotion: Color @Composable @ReadOnlyComposable get() = PaperColors.EmotionPink.resolve(LocalIsDarkTheme.current)
    val EmotionText: Color @Composable @ReadOnlyComposable get() = PaperColors.EmotionPinkText.resolve(LocalIsDarkTheme.current)

    /** 模块色底上的可读内容色：按 WCAG 对比度在炭墨与纸白之间取更高者。 */
    fun contentOn(background: Color): Color {
        val dark = PaperColors.TextPrimary.light
        val light = PaperColors.CardSurface.light
        fun contrast(a: Color, b: Color): Float {
            val hi = maxOf(a.luminance(), b.luminance()) + 0.05f
            val lo = minOf(a.luminance(), b.luminance()) + 0.05f
            return hi / lo
        }
        return if (contrast(dark, background) >= contrast(light, background)) dark else light
    }
}
