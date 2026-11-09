// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package com.flash.app.ui.theme

import android.database.ContentObserver
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import androidx.compose.animation.EnterTransition
import androidx.compose.animation.ExitTransition
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.compositionLocalOf
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.unit.Density
import com.flash.app.data.TextScale

/**
 * 「减少动态效果」裁决：系统「移除动画」（动画时长缩放 = 0）或应用内开关任一开启即为 true。
 * 为 true 时去掉位移 / 缩放 / 展开类动画，只保留短淡入淡出与颜色过渡。
 */
val LocalReduceMotion = compositionLocalOf { false }

/** 减少动态效果时替代位移转场的淡入 / 淡出 */
fun reducedEnter(): EnterTransition = fadeIn(tween(FlashTokens.Motion.SelectionMs))
fun reducedExit(): ExitTransition = fadeOut(tween(150))

/**
 * 在根部提供辅助功能偏好：
 * - [LocalReduceMotion] = 系统「移除动画」或 [appReduceMotion]；系统设置变化时实时跟随；
 * - 文字大小：在系统字体缩放上乘 [textScale] 系数（只放大文字，不影响布局 dp）。
 */
@Composable
fun FlashAccessibility(
    appReduceMotion: Boolean,
    textScale: TextScale,
    content: @Composable () -> Unit,
) {
    val systemAnimationsOff = rememberSystemAnimationsDisabled()
    val density = LocalDensity.current
    val scaledDensity = remember(density, textScale) {
        Density(density = density.density, fontScale = density.fontScale * textScale.factor)
    }
    CompositionLocalProvider(
        LocalReduceMotion provides (systemAnimationsOff || appReduceMotion),
        LocalDensity provides scaledDensity,
        content = content,
    )
}

/** 系统「开发者选项 / 无障碍 › 移除动画」：动画时长缩放为 0 时返回 true，设置变化时重组 */
@Composable
private fun rememberSystemAnimationsDisabled(): Boolean {
    val resolver = LocalContext.current.contentResolver
    fun read(): Boolean =
        Settings.Global.getFloat(resolver, Settings.Global.ANIMATOR_DURATION_SCALE, 1f) == 0f

    var disabled by remember(resolver) { mutableStateOf(read()) }
    DisposableEffect(resolver) {
        val observer = object : ContentObserver(Handler(Looper.getMainLooper())) {
            override fun onChange(selfChange: Boolean) {
                disabled = read()
            }
        }
        resolver.registerContentObserver(
            Settings.Global.getUriFor(Settings.Global.ANIMATOR_DURATION_SCALE),
            false,
            observer,
        )
        onDispose { resolver.unregisterContentObserver(observer) }
    }
    return disabled
}
