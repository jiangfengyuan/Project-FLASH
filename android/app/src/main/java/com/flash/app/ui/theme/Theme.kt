// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package com.flash.app.ui.theme

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.graphics.Color
import com.flash.app.data.UiStyle

/** 当前界面风格，供组件库感知（玻璃面 vs MD3 实体面） */
val LocalUiStyle = staticCompositionLocalOf { UiStyle.GLASS }

/**
 * 当前生效的深色标记（由设置里的主题模式决定，经 FlashTheme 下发）。
 * 玻璃系统、系统栏样式等必须统一读它，禁止再用 isSystemInDarkTheme()，
 * 否则"系统浅色 + App 选深色"时两套 token 会撕裂。
 */
val LocalIsDarkTheme = staticCompositionLocalOf { false }

// ==================== 玻璃拟态（插画 × Glassmorphism） ====================
// 色板取自插画风指南（IMG_5661）与玻璃拟态指南（IMG_5662），玻璃面参数见 ui/theme/glass/

private val GlassLightScheme = lightColorScheme(
    primary = Color(0xFF6C5CE7),
    onPrimary = Color(0xFFFFFFFF),
    primaryContainer = Color(0xFFE5E0FC),
    onPrimaryContainer = Color(0xFF241563),
    secondary = Color(0xFFFF8A56),
    onSecondary = Color(0xFFFFFFFF),
    secondaryContainer = Color(0xFFFFE3D3),
    onSecondaryContainer = Color(0xFF5C2A0E),
    tertiary = Color(0xFF4ECDC4),
    onTertiary = Color(0xFF063F3C),
    tertiaryContainer = Color(0xFFD3F4F1),
    onTertiaryContainer = Color(0xFF063F3C),
    error = Color(0xFFBA1A1A),
    onError = Color(0xFFFFFFFF),
    errorContainer = Color(0xFFFFDAD6),
    onErrorContainer = Color(0xFF410002),
    background = Color(0xFFF7F9FA),
    onBackground = Color(0xFF2D3436),
    surface = Color(0xFFF7F9FA),
    onSurface = Color(0xFF2D3436),
    surfaceVariant = Color(0xFFEDF0F5),
    onSurfaceVariant = Color(0xFF636E72),
    outline = Color(0xFFB2BEC3),
    outlineVariant = Color(0xFFDFE6E9),
)

private val GlassDarkScheme = darkColorScheme(
    primary = Color(0xFFA78BFA),
    onPrimary = Color(0xFF2A1663),
    primaryContainer = Color(0xFF5B4BC4),
    onPrimaryContainer = Color(0xFFE5E0FC),
    secondary = Color(0xFFFFAB7A),
    onSecondary = Color(0xFF4A2410),
    secondaryContainer = Color(0xFF7A4A2E),
    onSecondaryContainer = Color(0xFFFFE3D3),
    tertiary = Color(0xFF6FE3DB),
    onTertiary = Color(0xFF063F3C),
    tertiaryContainer = Color(0xFF1F6B66),
    onTertiaryContainer = Color(0xFFD3F4F1),
    error = Color(0xFFFFB4AB),
    onError = Color(0xFF690005),
    errorContainer = Color(0xFF93000A),
    onErrorContainer = Color(0xFFFFDAD6),
    background = Color(0xFF191A38),
    onBackground = Color(0xFFF5F6FA),
    surface = Color(0xFF191A38),
    onSurface = Color(0xFFF5F6FA),
    surfaceVariant = Color(0xFF3A3D5C),
    onSurfaceVariant = Color(0xFFB2BEC3),
    outline = Color(0xFF64748B),
    outlineVariant = Color(0xFF3A3D5C),
)

// ==================== Material Design 3 ====================
// 由品牌 Seed #4D96FF 经 material-color-utilities（Material Theme Builder
// 官方算法）离线生成的精确 Tonal Palette，含完整 Tonal Surface 层级。

private val Md3LightScheme = lightColorScheme(
    primary = Color(0xFF004891),
    onPrimary = Color(0xFFFFFFFF),
    primaryContainer = Color(0xFF4191FF),
    onPrimaryContainer = Color(0xFF001634),
    secondary = Color(0xFF424767),
    onSecondary = Color(0xFFFFFFFF),
    secondaryContainer = Color(0xFF8A90B4),
    onSecondaryContainer = Color(0xFF0E1431),
    tertiary = Color(0xFF4A4373),
    onTertiary = Color(0xFFFFFFFF),
    tertiaryContainer = Color(0xFF938BC1),
    onTertiaryContainer = Color(0xFF160E3C),
    error = Color(0xFF98000A),
    onError = Color(0xFFFFFFFF),
    errorContainer = Color(0xFFFF574B),
    onErrorContainer = Color(0xFF360001),
    background = Color(0xFFF9F9FF),
    onBackground = Color(0xFF171C25),
    surface = Color(0xFFF9F9FF),
    onSurface = Color(0xFF171C25),
    surfaceVariant = Color(0xFFDDE2F2),
    onSurfaceVariant = Color(0xFF414753),
    outline = Color(0xFF5F6572),
    outlineVariant = Color(0xFF8C92A0),
    surfaceContainerLowest = Color(0xFFFFFFFF),
    surfaceContainerLow = Color(0xFFF0F3FF),
    surfaceContainer = Color(0xFFE7EBF7),
    surfaceContainerHigh = Color(0xFFDFE2EF),
    surfaceContainerHighest = Color(0xFFD6DAE6),
    surfaceDim = Color(0xFFCCD0DC),
    surfaceBright = Color(0xFFF9F9FF),
)

private val Md3DarkScheme = darkColorScheme(
    primary = Color(0xFFA9C7FF),
    onPrimary = Color(0xFF00244E),
    primaryContainer = Color(0xFF006BD2),
    onPrimaryContainer = Color(0xFFFFFFFF),
    secondary = Color(0xFFBFC4EB),
    onSecondary = Color(0xFF1C2240),
    secondaryContainer = Color(0xFF656B8D),
    onSecondaryContainer = Color(0xFFFFFFFF),
    tertiary = Color(0xFFC9C0F8),
    onTertiary = Color(0xFF241D4B),
    tertiaryContainer = Color(0xFF6E6699),
    onTertiaryContainer = Color(0xFFFFFFFF),
    error = Color(0xFFFFB4AB),
    onError = Color(0xFF520003),
    errorContainer = Color(0xFFCF2C27),
    onErrorContainer = Color(0xFFFFFFFF),
    background = Color(0xFF0F131C),
    onBackground = Color(0xFFEAEDFA),
    surface = Color(0xFF0F131C),
    onSurface = Color(0xFFEAEDFA),
    surfaceVariant = Color(0xFF414753),
    onSurfaceVariant = Color(0xFFC1C6D6),
    outline = Color(0xFF959BA9),
    outlineVariant = Color(0xFF676D7A),
    surfaceContainerLowest = Color(0xFF070B13),
    surfaceContainerLow = Color(0xFF181D26),
    surfaceContainer = Color(0xFF1F242D),
    surfaceContainerHigh = Color(0xFF2A2E38),
    surfaceContainerHighest = Color(0xFF353943),
    surfaceDim = Color(0xFF0F131C),
    surfaceBright = Color(0xFF3A3F49),
)

/**
 * Flash 双风格主题。
 * @param uiStyle MD3：Material Design 3 规范配色；GLASS：插画 × 玻璃拟态。
 *                两种风格均不启用 Material You 动态取色，保持色板完整性。
 */
@Composable
fun FlashTheme(
    darkTheme: Boolean = isSystemInDarkTheme(),
    uiStyle: UiStyle = UiStyle.GLASS,
    content: @Composable () -> Unit,
) {
    val colorScheme = when (uiStyle) {
        UiStyle.MD3 -> if (darkTheme) Md3DarkScheme else Md3LightScheme
        UiStyle.GLASS -> if (darkTheme) GlassDarkScheme else GlassLightScheme
    }
    CompositionLocalProvider(LocalIsDarkTheme provides darkTheme) {
        MaterialTheme(
            colorScheme = colorScheme,
            typography = FlashTypography,
            content = content,
        )
    }
}
