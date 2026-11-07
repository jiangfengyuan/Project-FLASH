// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package com.flash.app.ui.theme

import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp

/**
 * Flash 全端统一设计令牌（UI/UX 重构阶段一）。
 * 数值取自《Flash 品牌标准 v1.0》与三端重构计划，三端保持一致；
 * 色值见 PaperColors，来源 docs/design/paper-tokens.json。
 */
object FlashTokens {

    /** 中性色与表面（色值见 PaperColors） */
    object Palette {
        /** 结构性选中态（筛选 Chip / 分段控件）的炭墨实心背景 */
        fun selectionFill(dark: Boolean): Color = PaperColors.ChipSelectedBackground.resolve(dark)

        fun onSelectionFill(dark: Boolean): Color = PaperColors.ChipSelectedForeground.resolve(dark)

        /** 实体卡片底色 */
        fun cardSurface(dark: Boolean): Color = PaperColors.CardSurface.resolve(dark)
    }

    /** 间距体系 8/12/16/24/32/48，移动端横向边距 20 */
    object Spacing {
        val XS = 8.dp
        val SM = 12.dp
        val MD = 16.dp
        val LG = 24.dp
        val XL = 32.dp
        val XXL = 48.dp
        val XXS = 4.dp

        /** 页面边距较通行的 16 宽 25%（字号放大时由 pageGutter() 退回 16） */
        val PageHorizontal = 20.dp
        val PageHorizontalCompact = 16.dp

        /** 卡片内边距 */
        val CardPadding = 20.dp
    }

    object Radius {
        val Hairline = 4.dp
        val Control = 6.dp
        val Field = 12.dp
        val Panel = 14.dp
        val Row = 16.dp
        val CardSmall = 20.dp

        /** 常规卡片 */
        val Card = 24.dp

        /** 焦点卡片 / Dock / 底部面板 */
        val Focus = 32.dp
    }

    object Touch {
        val IconButtonMin = 44.dp
        val FabMain = 56.dp
    }

    /** 图形尺寸 */
    object IconSize {
        /** 空状态大图标（FlashEmptyState），与触控尺寸无关 */
        val EmptyState = 56.dp
    }

    /**
     * 动效时长（毫秒）：选中态 160–240；按压反馈沿用组件默认涟漪（100–160ms 观感区间）。
     * 一律使用 tween（缓入缓出），不用弹跳；
     * Compose 动画时钟自动遵守系统“移除动画/动画时长缩放”设置。
     */
    object Motion {
        const val SelectionMs = 200
        const val FabExpandMs = 200

        /** 选中态轻位移（6–12px 的 dp 近似） */
        val SelectionShift: Dp = 4.dp
    }

    /** 悬浮 Dock 布局尺寸 */
    object Dock {
        val Height = 64.dp
        val BottomMargin = 12.dp
        val CaptureBarHeight = 52.dp
    }

    /** 长而弥散的暖影（不透明度见 paper-tokens.json） */
    object Shadow {
        val CardRadius = 28.dp
        val CardY = 12.dp
        const val CardOpacityLight = 0.08f
        const val CardOpacityDark = 0.34f
        val ElevatedRadius = 36.dp
        val ElevatedY = 16.dp
        const val ElevatedOpacityLight = 0.12f
        const val ElevatedOpacityDark = 0.42f
    }

    /** 硫酸纸（浮动表面）与叠放底页的不透明度 */
    const val VellumOpacity = 0.92f
    const val UnderSheetOpacity = 0.7f
}
