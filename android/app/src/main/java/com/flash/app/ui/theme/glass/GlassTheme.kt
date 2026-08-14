package com.flash.app.ui.theme.glass

import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.graphics.Color
import dev.chrisbanes.haze.HazeState

/** 全局共享的 Haze 状态，玻璃面组件通过它做背景模糊 */
val LocalHazeState = staticCompositionLocalOf<HazeState?> { null }

/**
 * 插画 × 玻璃拟态 色板。
 * 强调色取自插画风指南（IMG_5661），玻璃参数取自玻璃拟态指南（IMG_5662）：
 * 低填充白 + 1px 半透白边 + 顶部高光 + 大圆角 + 柔和投影。
 */
object GlassPalette {
    // ---- 插画风强调色 ----
    val Purple = Color(0xFF6C5CE7)
    val Orange = Color(0xFFFF8A56)
    val Mint = Color(0xFF7ED6A5)
    val Teal = Color(0xFF4ECDC4)
    val Yellow = Color(0xFFFFD166)

    // ---- 文本 ----
    val InkLight = Color(0xFF2D3436)
    val InkSecondaryLight = Color(0xFF636E72)
    val InkDark = Color(0xFFF5F6FA)
    val InkSecondaryDark = Color(0xFFB2BEC3)

    // ---- 玻璃面 ----
    // 浅色：粉彩渐变底，提高不透明度呈现"毛玻璃"磨砂感
    val SurfaceLight = Color(0xA6FFFFFF)       // 65% 白
    val SurfaceStrongLight = Color(0xD9FFFFFF) // 85% 白（输入区/底栏）
    val BorderLight = Color(0x80FFFFFF)        // 50%
    val HighlightLight = Color(0x99FFFFFF)     // 顶部高光
    // 深色：低填充白，还原玻璃拟态指南 rgba(255,255,255,0.15)
    val SurfaceDark = Color(0x33FFFFFF)        // 20%
    val SurfaceStrongDark = Color(0x4DFFFFFF)  // 30%
    val BorderDark = Color(0x40FFFFFF)         // 25%
    val HighlightDark = Color(0x59FFFFFF)      // 35%

    // ---- 渐变天空背景 ----
    val SkyLightTop = Color(0xFFE9E2FF)
    val SkyLightMid = Color(0xFFFFEADB)
    val SkyLightBottom = Color(0xFFDFF5E9)
    val SkyDarkTop = Color(0xFF191A38)
    val SkyDarkMid = Color(0xFF261C46)
    val SkyDarkBottom = Color(0xFF14232B)

    // 投影色（玻璃指南：rgba(31,38,135,0.37) 的蓝紫投影）
    val ShadowTint = Color(0xFF1F2687)

    fun surface(dark: Boolean, strong: Boolean = false) = when {
        dark && strong -> SurfaceStrongDark
        dark -> SurfaceDark
        strong -> SurfaceStrongLight
        else -> SurfaceLight
    }

    fun border(dark: Boolean) = if (dark) BorderDark else BorderLight
    fun highlight(dark: Boolean) = if (dark) HighlightDark else HighlightLight
    fun ink(dark: Boolean) = if (dark) InkDark else InkLight
    fun inkSecondary(dark: Boolean) = if (dark) InkSecondaryDark else InkSecondaryLight
}
