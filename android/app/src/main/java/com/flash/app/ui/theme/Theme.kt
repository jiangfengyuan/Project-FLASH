// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package com.flash.app.ui.theme

import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.ColorScheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.remember
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.graphics.Color

private const val ThemeTransitionDurationMillis = 320

/**
 * 当前生效的深色标记（由设置里的主题模式决定，经 FlashTheme 下发）。
 * 手作元素、系统栏样式等必须统一读它，禁止再用 isSystemInDarkTheme()，
 * 否则"系统浅色 + App 选深色"时两套 token 会撕裂。
 */
val LocalIsDarkTheme = staticCompositionLocalOf { false }

private fun paperScheme(dark: Boolean): ColorScheme {
    fun PaperPair.c(): Color = resolve(dark)
    val page = PaperColors.PageBackground.c()
    val card = PaperColors.CardSurface.c()
    val weak = PaperColors.WeakSurface.c()
    val parchment = PaperColors.Parchment.c()
    val ink = PaperColors.TextPrimary.c()
    val secondary = PaperColors.TextSecondary.c()
    val brand = PaperColors.BrandPrimary.c()
    val onBrand = PaperColors.OnBrandPrimary.c()
    val green = PaperColors.AccessibleGreen.c()
    val mustard = PaperColors.IdeaYellowText.c()
    val error = PaperColors.Destructive.c()
    val base = if (dark) darkColorScheme() else lightColorScheme()
    return base.copy(
        primary = brand,
        onPrimary = onBrand,
        primaryContainer = parchment,
        onPrimaryContainer = brand,
        secondary = green,
        onSecondary = onBrand,
        secondaryContainer = weak,
        onSecondaryContainer = ink,
        tertiary = mustard,
        onTertiary = onBrand,
        tertiaryContainer = weak,
        onTertiaryContainer = mustard,
        error = error,
        onError = onBrand,
        errorContainer = weak,
        onErrorContainer = error,
        background = page,
        onBackground = ink,
        surface = page,
        onSurface = ink,
        surfaceVariant = weak,
        onSurfaceVariant = secondary,
        outline = PaperColors.TextTertiary.c(),
        outlineVariant = PaperColors.WeakBorder.c(),
        scrim = PaperColors.Scrim.c(),
        inverseSurface = ink,
        inverseOnSurface = page,
        inversePrimary = PaperColors.BrandFill.c(),
        surfaceTint = Color.Transparent,
        surfaceDim = weak,
        surfaceBright = card,
        surfaceContainerLowest = card,
        surfaceContainerLow = card,
        surfaceContainer = card,
        surfaceContainerHigh = card,
        surfaceContainerHighest = weak,
    )
}

/** Flash 主题：「纸上书写」是唯一风格，只区分明暗；不启用 Material You 动态取色。 */
@Composable
fun FlashTheme(
    darkTheme: Boolean = isSystemInDarkTheme(),
    content: @Composable () -> Unit,
) {
    val colorScheme = animateColorScheme(if (darkTheme) PaperDarkScheme else PaperLightScheme)
    val typography = remember { flashTypography() }
    CompositionLocalProvider(LocalIsDarkTheme provides darkTheme) {
        MaterialTheme(
            colorScheme = colorScheme,
            typography = typography,
            content = content,
        )
    }
}

private val PaperLightScheme = paperScheme(dark = false)
private val PaperDarkScheme = paperScheme(dark = true)

/**
 * 在同一棵 Compose UI 上插值颜色，避免 Crossfade 重建 NavHost、滚动位置或输入状态。
 * Compose 的动画时钟会自动遵守系统“移除动画/动画时长缩放”设置。
 */
@Composable
private fun animateColorScheme(target: ColorScheme): ColorScheme {
    @Composable
    fun color(value: Color): Color = animateColorAsState(
        targetValue = value,
        animationSpec = tween(ThemeTransitionDurationMillis),
        label = "Flash theme color",
    ).value

    return target.copy(
        primary = color(target.primary),
        onPrimary = color(target.onPrimary),
        primaryContainer = color(target.primaryContainer),
        onPrimaryContainer = color(target.onPrimaryContainer),
        secondary = color(target.secondary),
        secondaryContainer = color(target.secondaryContainer),
        onSecondaryContainer = color(target.onSecondaryContainer),
        tertiary = color(target.tertiary),
        error = color(target.error),
        background = color(target.background),
        onBackground = color(target.onBackground),
        surface = color(target.surface),
        onSurface = color(target.onSurface),
        surfaceVariant = color(target.surfaceVariant),
        onSurfaceVariant = color(target.onSurfaceVariant),
        outline = color(target.outline),
        outlineVariant = color(target.outlineVariant),
        surfaceContainerLowest = color(target.surfaceContainerLowest),
        surfaceContainerLow = color(target.surfaceContainerLow),
        surfaceContainer = color(target.surfaceContainer),
        surfaceContainerHigh = color(target.surfaceContainerHigh),
        surfaceContainerHighest = color(target.surfaceContainerHighest),
    )
}
