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
 * 全屏渐变天空 + 有机色块（插画感）+ 微光星星。
 * 作为 Haze 模糊源，所有玻璃面模糊的内容就是它。
 */
@Composable
fun GlassBackground(
    darkTheme: Boolean,
    hazeState: HazeState?,
    modifier: Modifier = Modifier,
) {
    val top = if (darkTheme) GlassPalette.SkyDarkTop else GlassPalette.SkyLightTop
    val mid = if (darkTheme) GlassPalette.SkyDarkMid else GlassPalette.SkyLightMid
    val bottom = if (darkTheme) GlassPalette.SkyDarkBottom else GlassPalette.SkyLightBottom

    Box(
        modifier = modifier
            .fillMaxSize()
            .background(Brush.verticalGradient(listOf(top, mid, bottom)))
            .then(if (hazeState != null) Modifier.hazeSource(hazeState) else Modifier),
    ) {
        Canvas(Modifier.fillMaxSize()) {
            val w = size.width
            val h = size.height
            val blobAlpha = if (darkTheme) 0.30f else 0.38f

            // 有机色块：紫 / 橙 / 薄荷三团，位置错开营造层次
            drawCircle(
                GlassPalette.Purple.copy(alpha = blobAlpha),
                radius = w * 0.55f,
                center = Offset(w * 0.9f, h * 0.08f),
            )
            drawCircle(
                GlassPalette.Orange.copy(alpha = blobAlpha * 0.85f),
                radius = w * 0.42f,
                center = Offset(w * 0.02f, h * 0.42f),
            )
            drawCircle(
                GlassPalette.Mint.copy(alpha = blobAlpha * 0.9f),
                radius = w * 0.5f,
                center = Offset(w * 0.8f, h * 0.85f),
            )

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
