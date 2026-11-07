// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package com.flash.app.ui.paper

import android.graphics.BitmapFactory
import android.graphics.BlurMaskFilter
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Canvas
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.graphics.ImageShader
import androidx.compose.ui.graphics.Outline
import androidx.compose.ui.graphics.Paint
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.Shape
import androidx.compose.ui.graphics.ShaderBrush
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.StrokeJoin
import androidx.compose.ui.graphics.TileMode
import androidx.compose.ui.graphics.asAndroidPath
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.graphics.drawOutline
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.drawIntoCanvas
import androidx.compose.ui.graphics.drawscope.scale
import androidx.compose.ui.graphics.nativeCanvas
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.unit.Density
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.unit.dp
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.foundation.Canvas as ComposeCanvas
import com.flash.app.R
import com.flash.app.ui.theme.FlashTokens
import com.flash.app.ui.theme.LocalIsDarkTheme
import com.flash.app.ui.theme.PaperColors
import kotlin.math.PI
import kotlin.math.cos
import kotlin.math.hypot
import kotlin.math.max
import kotlin.math.min
import kotlin.math.sin

/** 手绘线：沿长边低频起伏（与 iOS HandDrawnLine 同算法） */
private fun handDrawnPath(seed: String, width: Float, height: Float, amplitude: Float): Path {
    val jitter = SeededJitter(seed)
    val segments = max(2, (width / 36f / LOGICAL).toInt())
    val midY = height / 2
    val startInset = kotlin.math.abs(jitter.next()) * 0.015f
    val endInset = kotlin.math.abs(jitter.next()) * 0.02f
    val path = Path()
    var px = startInset * width
    var py = midY + jitter.next() * amplitude
    path.moveTo(px, py)
    for (index in 1..segments) {
        val t = startInset + (1 - startInset - endInset) * index / segments
        val nx = t * width
        val ny = midY + jitter.next() * amplitude
        val cy = (py + ny) / 2 + jitter.next() * amplitude
        path.quadraticBezierTo((px + nx) / 2, cy, nx, ny)
        px = nx
        py = ny
    }
    return path
}

// 手绘线的分段按逻辑尺寸取，这里给一个足够接近的像素比例；形状只作装饰
private const val LOGICAL = 3f

/** 毛边线路径：比手绘线更碎、更短的起伏 */
private fun tornPath(seed: String, width: Float, height: Float, amplitude: Float, step: Float): Path {
    val jitter = SeededJitter(seed)
    val midY = height / 2
    val path = Path()
    var x = 0f
    path.moveTo(x, midY + jitter.next() * amplitude)
    while (x < width) {
        x = min(width, x + step * (0.7f + (jitter.next() + 1) * 0.3f))
        path.lineTo(x, midY + jitter.next() * amplitude)
    }
    return path
}

/** 纸卡外形：圆角矩形，边缘带极轻起伏；frayed 时底边是撕开的毛边。形状由种子决定、重绘一致。 */
class PaperCardShape(
    private val seed: String,
    private val cornerRadius: Dp,
    private val frayed: Boolean = false,
    private val wobble: Dp = 0.6.dp,
) : Shape {
    override fun createOutline(size: Size, layoutDirection: LayoutDirection, density: Density): Outline {
        val path = with(density) {
            paperPath(seed, size, min(cornerRadius.toPx(), min(size.width, size.height) / 2), frayed, wobble.toPx(), density)
        }
        return Outline.Generic(path)
    }

    override fun equals(other: Any?): Boolean = other is PaperCardShape && other.seed == seed &&
        other.cornerRadius == cornerRadius && other.frayed == frayed && other.wobble == wobble

    override fun hashCode(): Int = seed.hashCode() * 31 + cornerRadius.hashCode() + if (frayed) 1 else 0
}

private fun paperPath(seed: String, size: Size, r: Float, frayed: Boolean, wobble: Float, density: Density): Path {
    val jitter = SeededJitter(seed)
    val path = Path()
    if (size.width <= 0f || size.height <= 0f) return path
    val w = size.width
    val h = size.height
    val step48 = with(density) { 48.dp.toPx() }
    val tear = with(density) { 7.dp.toPx() }
    val tearAmp = with(density) { 2.4.dp.toPx() }

    fun wavy(sx: Float, sy: Float, ex: Float, ey: Float) {
        val length = hypot(ex - sx, ey - sy)
        val segments = max(1, (length / step48).toInt())
        val nx = if (length > 0) -(ey - sy) / length else 0f
        val ny = if (length > 0) (ex - sx) / length else 0f
        for (index in 1..segments) {
            val t = index.toFloat() / segments
            val mid = (index - 0.5f) / segments
            val offset = jitter.next() * wobble
            path.quadraticBezierTo(
                sx + (ex - sx) * mid + nx * offset,
                sy + (ey - sy) * mid + ny * offset,
                sx + (ex - sx) * t,
                sy + (ey - sy) * t,
            )
        }
    }

    path.moveTo(r, 0f)
    wavy(r, 0f, w - r, 0f)
    path.quadraticBezierTo(w, 0f, w, r)
    if (frayed) {
        val bottom = h - tearAmp
        wavy(w, r, w, bottom)
        var x = w
        while (x > 0f) {
            x = max(0f, x - tear * (0.7f + (jitter.next() + 1) * 0.3f))
            path.lineTo(x, bottom + jitter.next() * tearAmp)
        }
        wavy(0f, bottom, 0f, r)
    } else {
        wavy(w, r, w, h - r)
        path.quadraticBezierTo(w, h, w - r, h)
        wavy(w - r, h, r, h)
        path.quadraticBezierTo(0f, h, 0f, h - r)
        wavy(0f, h - r, 0f, r)
    }
    path.quadraticBezierTo(0f, 0f, r, 0f)
    path.close()
    return path
}

/** 长而弥散的暖影：按形状轮廓绘制，任何外观都不用纯黑 */
fun Modifier.paperShadow(
    shape: Shape,
    radius: Dp = FlashTokens.Shadow.CardRadius,
    y: Dp = FlashTokens.Shadow.CardY,
    isDark: Boolean,
    opacityLight: Float = FlashTokens.Shadow.CardOpacityLight,
    opacityDark: Float = FlashTokens.Shadow.CardOpacityDark,
): Modifier = drawBehind {
    val outline = shape.createOutline(size, layoutDirection, this)
    val tint = PaperColors.ShadowTint.resolve(isDark).copy(alpha = if (isDark) opacityDark else opacityLight)
    drawIntoCanvas { canvas ->
        val paint = Paint().asFrameworkPaint().apply {
            isAntiAlias = true
            color = tint.toArgb()
            maskFilter = BlurMaskFilter(radius.toPx() * 0.62f, BlurMaskFilter.Blur.NORMAL)
        }
        canvas.save()
        canvas.translate(0f, y.toPx())
        val native = canvas.nativeCanvas
        when (outline) {
            is Outline.Generic -> native.drawPath(outline.path.asAndroidPath(), paint)
            is Outline.Rounded -> native.drawRoundRect(
                0f, 0f, size.width, size.height,
                outline.roundRect.topLeftCornerRadius.x, outline.roundRect.topLeftCornerRadius.y, paint,
            )
            is Outline.Rectangle -> native.drawRect(0f, 0f, size.width, size.height, paint)
        }
        canvas.restore()
    }
}

/** 硫酸纸：浮动表面的半透明纸（文字仍达 AA），外加细边与悬浮暖影 */
@Composable
fun Modifier.vellum(shape: Shape): Modifier {
    val dark = LocalIsDarkTheme.current
    return this
        .paperShadow(
            shape,
            FlashTokens.Shadow.ElevatedRadius,
            FlashTokens.Shadow.ElevatedY,
            dark,
            FlashTokens.Shadow.ElevatedOpacityLight,
            FlashTokens.Shadow.ElevatedOpacityDark,
        )
        .clip(shape)
        .background(PaperColors.CardSurface.resolve(dark).copy(alpha = FlashTokens.VellumOpacity))
        .border(0.75.dp, PaperColors.WeakBorder.resolve(dark), shape)
}

/** 纸卡容器：起伏外形 + 细边 + 弥散暖影，可选毛边 */
@Composable
fun PaperCard(
    modifier: Modifier = Modifier,
    seed: String = "card",
    cornerRadius: Dp = FlashTokens.Radius.Card,
    frayed: Boolean = false,
    onClick: (() -> Unit)? = null,
    contentPadding: Dp = FlashTokens.Spacing.CardPadding,
    content: @Composable ColumnScope.() -> Unit,
) {
    val dark = LocalIsDarkTheme.current
    val shape = remember(seed, cornerRadius, frayed) { PaperCardShape(seed, cornerRadius, frayed) }
    val surface = PaperColors.CardSurface.resolve(dark)
    val border = PaperColors.WeakBorder.resolve(dark)
    Column(
        modifier = modifier
            .paperShadow(shape, isDark = dark)
            .clip(shape)
            .background(surface)
            .border(0.75.dp, border, shape)
            .then(if (onClick != null) Modifier.clickable(onClick = onClick) else Modifier)
            .padding(contentPadding),
        content = content,
    )
}

/** 分隔线：毛边（横）；手绘线（竖） */
@Composable
fun FlashDivider(seed: String = "divider", modifier: Modifier = Modifier) {
    val color = PaperColors.WeakBorder.resolve(LocalIsDarkTheme.current)
    ComposeCanvas(modifier.fillMaxWidth().height(4.dp).clearAndSetSemantics { }) {
        drawPath(
            tornPath(seed, size.width, size.height, 1.6.dp.toPx(), 7.dp.toPx()),
            color,
            style = Stroke(width = 1.1.dp.toPx(), cap = StrokeCap.Round, join = StrokeJoin.Round),
        )
    }
}

/** 纵向手绘分隔线（今日卡片内的列） */
@Composable
fun VerticalHandDivider(seed: String, modifier: Modifier = Modifier) {
    val color = PaperColors.WeakBorder.resolve(LocalIsDarkTheme.current)
    ComposeCanvas(modifier.width(3.dp).clearAndSetSemantics { }) {
        val path = handDrawnPath(seed, size.height, size.width, 0.8.dp.toPx())
        // 横向路径旋转成竖线
        val matrix = androidx.compose.ui.graphics.Matrix().apply { rotateZ(90f); translate(0f, -size.width) }
        path.transform(matrix)
        drawPath(path, color, style = Stroke(width = 1.2.dp.toPx(), cap = StrokeCap.Round))
    }
}

/** 撕开的区块断口：一条窄窄的羊皮纸带 */
@Composable
fun TornSectionBreak(seed: String, modifier: Modifier = Modifier) {
    val dark = LocalIsDarkTheme.current
    val parchment = PaperColors.Parchment.resolve(dark).copy(alpha = 0.55f)
    val border = PaperColors.WeakBorder.resolve(dark)
    ComposeCanvas(modifier.fillMaxWidth().height(8.dp).clearAndSetSemantics { }) {
        drawPath(paperPath(seed, size, 1.dp.toPx(), true, 1.dp.toPx(), this), parchment)
        drawPath(
            tornPath("$seed·top", size.width, size.height, 1.2.dp.toPx(), 7.dp.toPx()),
            border,
            style = Stroke(width = 0.8.dp.toPx(), cap = StrokeCap.Round),
        )
    }
}

/** 标题下的手绘下划线（从右到左时靠右） */
fun Modifier.handUnderline(seed: String, color: Color, fraction: Float = 0.6f): Modifier = drawBehind {
    val width = size.width * fraction
    val path = handDrawnPath(seed, width, 6.dp.toPx(), 1.4.dp.toPx())
    val startX = if (layoutDirection == LayoutDirection.Rtl) size.width - width else 0f
    translateBy(startX, size.height - 3.dp.toPx()) {
        drawPath(path, color.copy(alpha = 0.75f), style = Stroke(width = 2.2.dp.toPx(), cap = StrokeCap.Round))
    }
}

private inline fun DrawScope.translateBy(x: Float, y: Float, block: DrawScope.() -> Unit) {
    drawContext.canvas.save()
    drawContext.canvas.translate(x, y)
    block()
    drawContext.canvas.restore()
}

/** 手绘圈：一笔略不圆、收笔搭头的椭圆，叠一笔更淡的错位描边 */
@Composable
fun HandDrawnRing(seed: String, tint: Color, modifier: Modifier = Modifier) {
    ComposeCanvas(modifier.clearAndSetSemantics { }) {
        drawCircle(tint.copy(alpha = 0.12f), radius = size.minDimension / 2 - 4.dp.toPx())
        drawPath(circlePath(seed, size, 0.035f), tint.copy(alpha = 0.85f), style = Stroke(1.6.dp.toPx(), cap = StrokeCap.Round, join = StrokeJoin.Round))
        drawPath(circlePath("$seed·2", size, 0.05f), tint.copy(alpha = 0.35f), style = Stroke(1.dp.toPx(), cap = StrokeCap.Round, join = StrokeJoin.Round))
    }
}

private fun circlePath(seed: String, size: Size, wobble: Float): Path {
    val jitter = SeededJitter(seed)
    val cx = size.width / 2
    val cy = size.height / 2
    val start = jitter.next() * PI.toFloat()
    val sweep = 2 * PI.toFloat() + PI.toFloat() / 10
    val phase = jitter.next() * PI.toFloat()
    val path = Path()
    val steps = 48
    for (step in 0..steps) {
        val progress = step.toFloat() / steps
        val angle = start + sweep * progress
        val k = 1 + wobble * sin(angle * 2 + phase) + wobble * 0.5f * progress
        val x = cx + cos(angle) * cx * k
        val y = cy + sin(angle) * cy * k
        if (step == 0) path.moveTo(x, y) else path.lineTo(x, y)
    }
    return path
}

/** 折叠信纸：内容之下的折痕 + 右上角折角（从右到左时翻到左上） */
fun Modifier.foldedLetter(isDark: Boolean): Modifier = drawBehind {
    val crease = size.height * 0.5f
    drawRect(PaperColors.ShadowTint.resolve(isDark).copy(alpha = 0.07f), Offset(0f, crease), Size(size.width, 0.75.dp.toPx()))
    drawRect(PaperColors.CardSurface.resolve(isDark).copy(alpha = 0.8f), Offset(0f, crease + 0.75.dp.toPx()), Size(size.width, 0.75.dp.toPx()))
    val ear = 22.dp.toPx()
    val rtl = layoutDirection == LayoutDirection.Rtl
    val edge = if (rtl) 0f else size.width
    val inner = if (rtl) ear else size.width - ear
    val path = Path().apply {
        moveTo(inner, 0f)
        lineTo(edge, ear)
        lineTo(inner, ear)
        close()
    }
    drawPath(path, PaperColors.Parchment.resolve(isDark))
}

/** 叠放便签：身后错开一张羊皮纸底页。种子决定错位与角度 */
@Composable
fun StickyStack(
    seed: String,
    modifier: Modifier = Modifier,
    cornerRadius: Dp = FlashTokens.Radius.Row,
    enabled: Boolean = true,
    content: @Composable BoxScope.() -> Unit,
) {
    if (!enabled) {
        Box(modifier, content = content)
        return
    }
    val dark = LocalIsDarkTheme.current
    val (angle, dx) = remember(seed) {
        val jitter = SeededJitter(seed)
        jitter.next() * 1.4f to jitter.next() * 3f
    }
    val under = remember(seed) { PaperCardShape("$seed·under", cornerRadius, wobble = 1.dp) }
    val tint = PaperColors.Parchment.resolve(dark).copy(alpha = FlashTokens.UnderSheetOpacity)
    Box(
        modifier.drawBehind {
            val outline = under.createOutline(size, layoutDirection, this)
            drawContext.canvas.save()
            drawContext.canvas.translate(dx.dp.toPx(), 4.dp.toPx())
            drawContext.transform.rotate(if (angle == 0f) 1f else angle, center)
            drawOutline(outline, tint)
            drawContext.canvas.restore()
        },
        content = content,
    )
}

/** 印章徽章：小方框 + 标签色细描边 + 极淡底，替代胶囊色块 */
fun Modifier.stampBadge(color: Color): Modifier = composedStamp(color)

private fun Modifier.composedStamp(color: Color): Modifier {
    val shape = RoundedCornerShape(FlashTokens.Radius.Control)
    return this
        .clip(shape)
        .background(color.copy(alpha = 0.08f))
        .border(1.dp, color, shape)
        .padding(horizontal = 8.dp, vertical = 3.dp)
}

/** 纸张底：底色 + 平铺的纤维颗粒贴图（tools/design/generate_paper_assets.py 生成，三端同一张） */
@Composable
fun Modifier.paperBackground(): Modifier {
    val dark = LocalIsDarkTheme.current
    val context = LocalContext.current
    val density = LocalDensity.current.density
    val bitmap: ImageBitmap? = remember(dark) {
        val id = if (dark) R.drawable.paper_grain_dark else R.drawable.paper_grain_light
        runCatching { BitmapFactory.decodeResource(context.resources, id)?.asImageBitmap() }.getOrNull()
    }
    val page = PaperColors.PageBackground.resolve(dark)
    val brush = remember(bitmap) {
        bitmap?.let { ShaderBrush(ImageShader(it, TileMode.Repeated, TileMode.Repeated)) }
    }
    return this
        .background(page)
        .then(if (brush != null) Modifier.drawBehind {
            // 贴图 256px 对应 128dp
            val k = density / 2f
            scale(k, k, Offset.Zero) { drawRect(brush, size = Size(size.width / k, size.height / k)) }
        } else Modifier)
}

/** 页面左右边距 20；字号放大 ≥ 1.5 倍时退回 16，避免裁切 */
@Composable
fun pageGutter(): Dp =
    if (LocalDensity.current.fontScale >= 1.5f) FlashTokens.Spacing.PageHorizontalCompact else FlashTokens.Spacing.PageHorizontal
