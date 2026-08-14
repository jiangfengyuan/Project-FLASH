package com.flash.app.ui.theme.glass

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.drawscope.DrawScope
import dev.chrisbanes.haze.HazeState
import dev.chrisbanes.haze.hazeSource

/**
 * 全屏渐变天空 + 有机色块（径向渐变软边）+ 微光星星。
 * 作为 Haze 模糊源，所有玻璃面模糊的内容就是它。
 * 注意：天空使用多段色阶避免线性渐变的色彩断层；
 * 色块使用径向渐变消隐边缘，避免生硬边界。
 */
@Composable
fun GlassBackground(
    darkTheme: Boolean,
    hazeState: HazeState?,
    modifier: Modifier = Modifier,
) {
    val skyStops = if (darkTheme) {
        listOf(
            GlassPalette.SkyDarkTop,
            GlassPalette.SkyDarkTop.blendToward(GlassPalette.SkyDarkMid, 0.55f),
            GlassPalette.SkyDarkMid,
            GlassPalette.SkyDarkMid.blendToward(GlassPalette.SkyDarkBottom, 0.55f),
            GlassPalette.SkyDarkBottom,
        )
    } else {
        listOf(
            GlassPalette.SkyLightTop,
            GlassPalette.SkyLightTop.blendToward(GlassPalette.SkyLightMid, 0.55f),
            GlassPalette.SkyLightMid,
            GlassPalette.SkyLightMid.blendToward(GlassPalette.SkyLightBottom, 0.55f),
            GlassPalette.SkyLightBottom,
        )
    }

    Box(
        modifier = modifier
            .fillMaxSize()
            .background(Brush.verticalGradient(skyStops))
            .then(if (hazeState != null) Modifier.hazeSource(hazeState) else Modifier),
    ) {
        Canvas(Modifier.fillMaxSize()) {
            val w = size.width
            val h = size.height
            // 深色下降低色块不透明度，避免深蓝底上的彩斑显脏
            val blobAlpha = if (darkTheme) 0.24f else 0.42f

            // 有机色块：径向渐变软边，中心实、边缘消隐
            fun softBlob(color: Color, radius: Float, center: Offset) {
                drawCircle(
                    brush = Brush.radialGradient(
                        colors = listOf(color.copy(alpha = blobAlpha), color.copy(alpha = 0f)),
                        center = center,
                        radius = radius,
                    ),
                    radius = radius,
                    center = center,
                )
            }

            softBlob(GlassPalette.Purple, w * 0.75f, Offset(w * 0.9f, h * 0.08f))
            softBlob(GlassPalette.Orange, w * 0.62f, Offset(w * 0.02f, h * 0.42f))
            softBlob(GlassPalette.Mint, w * 0.70f, Offset(w * 0.8f, h * 0.85f))

            // 微光星星（插画指南里的点缀元素）
            val sparkleColor = Color.White.copy(alpha = if (darkTheme) 0.5f else 0.85f)
            val sparkles = listOf(
                Offset(0.18f, 0.10f) to 6f,
                Offset(0.55f, 0.06f) to 4f,
                Offset(0.80f, 0.28f) to 5f,
                Offset(0.30f, 0.55f) to 4f,
                Offset(0.65f, 0.62f) to 6f,
                Offset(0.15f, 0.82f) to 5f,
                Offset(0.45f, 0.92f) to 4f,
            )
            sparkles.forEach { (pos, size) ->
                drawSparkle(Offset(pos.x * w, pos.y * h), size, sparkleColor)
            }
        }
    }
}

/** 两色线性插值，用于生成天空渐变中间色阶 */
private fun Color.blendToward(other: Color, fraction: Float): Color {
    val f = fraction.coerceIn(0f, 1f)
    return Color(
        red = red + (other.red - red) * f,
        green = green + (other.green - green) * f,
        blue = blue + (other.blue - blue) * f,
        alpha = alpha + (other.alpha - alpha) * f,
    )
}

/** 四角星（✦）路径 */
private fun DrawScope.drawSparkle(center: Offset, size: Float, color: Color) {
    val path = Path().apply {
        moveTo(center.x, center.y - size)
        quadraticTo(center.x, center.y, center.x + size, center.y)
        quadraticTo(center.x, center.y, center.x, center.y + size)
        quadraticTo(center.x, center.y, center.x - size, center.y)
        quadraticTo(center.x, center.y, center.x, center.y - size)
        close()
    }
    drawPath(path, color)
}
