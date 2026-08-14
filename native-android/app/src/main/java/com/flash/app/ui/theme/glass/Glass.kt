package com.flash.app.ui.theme.glass

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Shape
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import com.flash.app.ui.theme.LocalIsDarkTheme
import dev.chrisbanes.haze.HazeStyle
import dev.chrisbanes.haze.HazeTint
import dev.chrisbanes.haze.hazeEffect

val GlassShape: Shape = RoundedCornerShape(24.dp)

/**
 * 玻璃面修饰符：阴影 → 裁剪 → 背景模糊(Haze) → 半透白填充 → 渐变描边（顶部高光）。
 * @param blur 是否启用真实背景模糊。实时模糊开销大，滚动列表中的卡片应传 false
 *        （退化为半透"轻玻璃"，观感接近但滚动流畅）；底栏/输入坞等大面积静态面传 true。
 */
@Composable
fun Modifier.glass(
    shape: Shape = GlassShape,
    strong: Boolean = false,
    blur: Boolean = true,
    blurRadius: Dp = 20.dp,
): Modifier {
    val dark = LocalIsDarkTheme.current
    val haze = if (blur) LocalHazeState.current else null
    val surface = GlassPalette.surface(dark, strong)
    val borderColor = GlassPalette.border(dark)
    val highlight = GlassPalette.highlight(dark)
    // 柔和投影：全不透明阴影色会在半透明玻璃下缘形成硬边暗带（反衬出"白块"），
    // 玻璃指南要求低透明柔和投影；深色背景下投影进一步减弱
    val shadowColor = GlassPalette.ShadowTint.copy(alpha = if (dark) 0.22f else 0.16f)

    return this
        .shadow(
            elevation = if (dark) 6.dp else 10.dp,
            shape = shape,
            ambientColor = shadowColor,
            spotColor = shadowColor,
        )
        .clip(shape)
        .then(
            if (haze != null) {
                Modifier.hazeEffect(
                    state = haze,
                    style = HazeStyle(
                        // 模糊层只负责模糊，着色统一交给下方 background，避免双重叠加；
                        // fallbackTint 用于 API < 31 无模糊能力时保持可读性
                        tints = emptyList(),
                        blurRadius = blurRadius,
                        noiseFactor = 0f,
                        fallbackTint = HazeTint(surface),
                    ),
                )
            } else {
                Modifier
            },
        )
        .background(surface)
        .border(
            width = 1.dp,
            brush = Brush.verticalGradient(listOf(highlight, borderColor)),
            shape = shape,
        )
}

/** 玻璃卡片，LogCard / 统计卡 / 日历详情等共用 */
@Composable
fun GlassCard(
    modifier: Modifier = Modifier,
    strong: Boolean = false,
    blur: Boolean = true,
    shape: Shape = GlassShape,
    contentPadding: Dp = 12.dp,
    onClick: (() -> Unit)? = null,
    content: @Composable ColumnScope.() -> Unit,
) {
    val base = modifier.glass(shape = shape, strong = strong, blur = blur)
    Column(
        modifier = if (onClick != null) {
            base.clickable(onClick = onClick)
        } else {
            base
        }.padding(contentPadding),
        content = content,
    )
}
