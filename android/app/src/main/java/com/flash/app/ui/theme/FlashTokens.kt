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
 * Material 3 与玻璃拟态两套主题共用这一套令牌。
 */
object FlashTokens {

    /** 中性色与表面（浅色/深色配对见品牌标准 03 节） */
    object Palette {
        val PageBackground = Color(0xFFF7F9FA)
        val CardSurface = Color(0xFFFFFFFF)
        val InkPrimary = Color(0xFF2D3436)
        val InkSecondary = Color(0xFF636E72)
        val DarkSurface = Color(0xFF191A38)
        val DarkWeakSurface = Color(0xFF3A3D5C)
        val DarkInkPrimary = Color(0xFFF5F6FA)
        val DarkInkSecondary = Color(0xFFB2BEC3)

        /** 结构性选中态（筛选 Chip / 分段控件）的深墨色实心背景 */
        fun selectionFill(dark: Boolean): Color = if (dark) DarkInkPrimary else InkPrimary

        fun onSelectionFill(dark: Boolean): Color = if (dark) InkPrimary else Color.White

        /** 实体卡片底色：列表、表单、高密度信息不依赖玻璃模糊 */
        fun cardSurface(dark: Boolean): Color = if (dark) DarkWeakSurface else CardSurface
    }

    /** 间距体系 8/12/16/24/32/48，移动端横向边距 20 */
    object Spacing {
        val XS = 8.dp
        val SM = 12.dp
        val MD = 16.dp
        val LG = 24.dp
        val XL = 32.dp
        val XXL = 48.dp
        val PageHorizontal = 20.dp
    }

    object Radius {
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
        val BottomMargin = 16.dp
    }
}
