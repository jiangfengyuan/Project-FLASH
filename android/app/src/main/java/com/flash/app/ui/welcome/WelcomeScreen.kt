// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package com.flash.app.ui.welcome

import androidx.activity.compose.BackHandler
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.selection.toggleable
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.MenuBook
import androidx.compose.material.icons.automirrored.filled.ShowChart
import androidx.compose.material.icons.filled.Accessibility
import androidx.compose.material.icons.filled.AutoAwesome
import androidx.compose.material.icons.filled.Bolt
import androidx.compose.material.icons.filled.CalendarMonth
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material.icons.filled.Mood
import androidx.compose.material.icons.filled.PhoneAndroid
import androidx.compose.material.icons.filled.Share
import androidx.compose.material.icons.outlined.Shield
import androidx.compose.material3.Button
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.liveRegion
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.flash.app.FlashApplication
import com.flash.app.data.TextScale
import com.flash.app.data.ThemeMode
import com.flash.app.ui.components.FlashSegmentedControl
import com.flash.app.ui.components.StyleCard
import com.flash.app.ui.theme.FlashTokens
import com.flash.app.ui.theme.LocalReduceMotion
import com.flash.app.ui.theme.ModuleColors
import kotlinx.coroutines.launch

/** 新手引导四步（四端同一内容与顺序：欢迎 → 能做什么 → 隐私 → 偏好） */
private enum class OnboardingStep(
    val icon: ImageVector,
    val tint: Color,
    val title: String,
    val subtitle: String,
) {
    WELCOME(
        Icons.Filled.Bolt, ModuleColors.Log, "欢迎来到 Flash",
        "闪过即留，一目了然。\n把一闪而过的念头、情绪与待办，安心留在这台设备上。",
    ),
    FEATURES(
        Icons.Filled.AutoAwesome, ModuleColors.Log, "Flash 能帮你做什么",
        "四个模块，覆盖从记下到回看的全过程。",
    ),
    PRIVACY(
        Icons.Filled.Lock, ModuleColors.Calendar, "你的记录只属于你",
        "本地优先：没有账号，也没有后端。",
    ),
    PREFERENCES(
        Icons.Filled.Accessibility, ModuleColors.Log, "让 Flash 更适合你",
        "以下选项随时可在「设置 › 辅助功能」中修改。",
    ),
}

/** 引导内容最大宽度：平板 / 折叠屏展开时不把文字拉成长行 */
private val ContentMaxWidth = 520.dp

/**
 * 首次安装的欢迎与新手引导（也可从 设置 › 辅助功能 重新打开）。
 *
 * 交互约定：
 * - 每一步都可「跳过」；左右轻扫或用「上一步 / 下一步」翻页，系统返回键回到上一步；
 * - 最后一步就地设置外观、减少动态效果与文字大小，改动立即生效；
 * - 读屏：每步标题为标题语义，步骤指示以礼貌播报「第 n 步，共 4 步」，装饰图标不朗读；
 * - 减少动态效果时翻页直接跳转、不做滑动动画；内容可纵向滚动，大字号下不截断。
 */
@Composable
fun WelcomeScreen(onStart: () -> Unit) {
    val reduceMotion = LocalReduceMotion.current
    val steps = OnboardingStep.entries
    val pagerState = rememberPagerState(pageCount = { steps.size })
    val scope = rememberCoroutineScope()
    val page = pagerState.currentPage
    val isLast = page == steps.lastIndex

    fun goTo(target: Int) {
        scope.launch {
            if (reduceMotion) pagerState.scrollToPage(target) else pagerState.animateScrollToPage(target)
        }
    }

    // 系统返回：引导中途先回上一步，第一步时交给系统（退出应用）
    BackHandler(enabled = page > 0) { goTo(page - 1) }

    Column(Modifier.fillMaxSize()) {
        // 顶部：跳过（末尾按钮外移内建留白，文字落在页边距线上）
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .heightIn(min = 56.dp)
                .padding(horizontal = FlashTokens.Spacing.PageHorizontal),
            horizontalArrangement = Arrangement.End,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            if (!isLast) {
                TextButton(
                    onClick = onStart,
                    modifier = Modifier.offset(x = FlashTokens.Touch.TextButtonInset),
                ) { Text("跳过") }
            }
        }

        HorizontalPager(
            state = pagerState,
            modifier = Modifier
                .weight(1f)
                .fillMaxWidth(),
        ) { index ->
            OnboardingPage(steps[index])
        }

        // 底部：步骤指示居中，上一步 / 下一步贴左右页边距
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .padding(
                    horizontal = FlashTokens.Spacing.PageHorizontal,
                    vertical = FlashTokens.Spacing.LG,
                ),
        ) {
            StepIndicator(
                current = page,
                count = steps.size,
                modifier = Modifier.align(Alignment.Center),
            )
            if (page > 0) {
                OutlinedButton(
                    onClick = { goTo(page - 1) },
                    modifier = Modifier.align(Alignment.CenterStart),
                ) { Text("上一步") }
            }
            Button(
                onClick = { if (isLast) onStart() else goTo(page + 1) },
                modifier = Modifier.align(Alignment.CenterEnd),
            ) { Text(if (isLast) "开始使用" else "下一步") }
        }
    }
}

@Composable
private fun OnboardingPage(step: OnboardingStep) {
    Box(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState()),
        contentAlignment = Alignment.TopCenter,
    ) {
        Column(
            modifier = Modifier
                .widthIn(max = ContentMaxWidth)
                .fillMaxWidth()
                .padding(horizontal = FlashTokens.Spacing.PageHorizontal)
                .padding(top = if (step == OnboardingStep.WELCOME) FlashTokens.Spacing.XXL else FlashTokens.Spacing.SM),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            // 图标仅作装饰，信息由标题承载
            Box(
                modifier = Modifier
                    .size(if (step == OnboardingStep.WELCOME) 112.dp else 88.dp)
                    .clip(CircleShape)
                    .background(step.tint.copy(alpha = 0.14f)),
                contentAlignment = Alignment.Center,
            ) {
                Icon(
                    step.icon,
                    contentDescription = null,
                    tint = step.tint,
                    modifier = Modifier.size(if (step == OnboardingStep.WELCOME) 60.dp else 44.dp),
                )
            }
            Spacer(Modifier.height(FlashTokens.Spacing.LG))
            Text(
                step.title,
                style = MaterialTheme.typography.headlineMedium,
                color = MaterialTheme.colorScheme.onSurface,
                textAlign = TextAlign.Center,
                modifier = Modifier.semantics { heading() },
            )
            Spacer(Modifier.height(FlashTokens.Spacing.XS))
            Text(
                step.subtitle,
                style = MaterialTheme.typography.bodyLarge,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                textAlign = TextAlign.Center,
            )
            Spacer(Modifier.height(FlashTokens.Spacing.LG))
            when (step) {
                OnboardingStep.WELCOME -> Unit
                OnboardingStep.FEATURES -> StyleCard(Modifier.fillMaxWidth()) {
                    InfoRow(Icons.AutoMirrored.Filled.MenuBook, ModuleColors.Log,
                        "随手记录", "日志与灵感一键记下，用 !! 标记重要程度。")
                    InfoRow(Icons.Filled.Mood, ModuleColors.Emotion,
                        "情绪觉察", "七级情绪加上具体感受，看见自己的变化。")
                    InfoRow(Icons.Filled.CalendarMonth, ModuleColors.Calendar,
                        "任务与日历", "按日期回看记录；任务可设系统提醒。")
                    InfoRow(Icons.AutoMirrored.Filled.ShowChart, ModuleColors.Log,
                        "回顾", "周、月趋势与情绪分布，发现记录的节奏。", last = true)
                }
                OnboardingStep.PRIVACY -> StyleCard(Modifier.fillMaxWidth()) {
                    InfoRow(Icons.Filled.PhoneAndroid, ModuleColors.Calendar,
                        "数据保存在这台设备", "无需注册，不上传到任何服务器。")
                    InfoRow(Icons.Filled.Share, ModuleColors.Calendar,
                        "备份与传输由你发起", "随时导出 JSON 备份，或在可信局域网内直传到另一台设备。")
                    InfoRow(Icons.Outlined.Shield, ModuleColors.Calendar,
                        "妥善保管备份文件", "备份是明文 JSON，请只保存或分享到可信的位置。", last = true)
                }
                OnboardingStep.PREFERENCES -> PreferencesCard()
            }
            Spacer(Modifier.height(FlashTokens.Spacing.LG))
        }
    }
}

/** 说明行：图标列 + 标题 + 说明；读屏合并为一句 */
@Composable
private fun InfoRow(
    icon: ImageVector,
    tint: Color,
    title: String,
    detail: String,
    last: Boolean = false,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .semantics(mergeDescendants = true) {}
            .padding(bottom = if (last) 0.dp else FlashTokens.Spacing.MD),
        verticalAlignment = Alignment.Top,
    ) {
        Icon(icon, contentDescription = null, tint = tint, modifier = Modifier.size(24.dp))
        Spacer(Modifier.width(FlashTokens.Spacing.SM))
        Column(Modifier.weight(1f)) {
            Text(title, style = MaterialTheme.typography.titleSmall)
            Text(
                detail,
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
    }
}

/** 偏好卡：外观 / 减少动态效果 / 文字大小，改动立即生效 */
@Composable
private fun PreferencesCard() {
    val settings = (LocalContext.current.applicationContext as FlashApplication).settings
    val themeMode by settings.themeMode.collectAsStateWithLifecycle()
    val reduceMotion by settings.reduceMotion.collectAsStateWithLifecycle()
    val textScale by settings.textScale.collectAsStateWithLifecycle()

    StyleCard(Modifier.fillMaxWidth()) {
        Text("外观", style = MaterialTheme.typography.titleSmall)
        Spacer(Modifier.height(FlashTokens.Spacing.XS))
        FlashSegmentedControl(
            options = listOf(
                ThemeMode.SYSTEM to "跟随系统",
                ThemeMode.LIGHT to "浅色",
                ThemeMode.DARK to "深色",
            ),
            selected = themeMode,
            onSelect = settings::setThemeMode,
        )

        HorizontalDivider(Modifier.padding(vertical = FlashTokens.Spacing.SM))

        // 整行可切换（Role.Switch）：读屏朗读标题 + 说明 + 开关状态
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .heightIn(min = FlashTokens.Touch.IconButtonMin)
                .toggleable(
                    value = reduceMotion,
                    role = Role.Switch,
                    onValueChange = settings::setReduceMotion,
                ),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Column(Modifier.weight(1f)) {
                Text("减少动态效果", style = MaterialTheme.typography.titleSmall)
                Text(
                    "关闭页面滑动、缩放与展开动画，只保留淡入淡出。",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
            Spacer(Modifier.width(FlashTokens.Spacing.SM))
            Switch(checked = reduceMotion, onCheckedChange = null)
        }

        HorizontalDivider(Modifier.padding(vertical = FlashTokens.Spacing.SM))

        Text("文字大小", style = MaterialTheme.typography.titleSmall)
        Spacer(Modifier.height(FlashTokens.Spacing.XS))
        FlashSegmentedControl(
            options = TextScale.entries.map { it to it.displayName },
            selected = textScale,
            onSelect = settings::setTextScale,
        )
        Spacer(Modifier.height(FlashTokens.Spacing.XS))
        Text(
            "在系统字体大小之上再放大；系统已设大字时两者叠加。",
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
    }
}

/** 步骤指示：当前步为长条，其余为圆点；读屏以礼貌播报读出「第 n 步，共 m 步」 */
@Composable
private fun StepIndicator(current: Int, count: Int, modifier: Modifier = Modifier) {
    Row(
        modifier = modifier.clearAndSetSemantics {
            contentDescription = "第 ${current + 1} 步，共 $count 步"
            liveRegion = LiveRegionMode.Polite
        },
        horizontalArrangement = Arrangement.spacedBy(FlashTokens.Spacing.XS),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        repeat(count) { index ->
            Box(
                Modifier
                    .height(8.dp)
                    .width(if (index == current) 20.dp else 8.dp)
                    .clip(RoundedCornerShape(4.dp))
                    .background(
                        if (index == current) {
                            MaterialTheme.colorScheme.primary
                        } else {
                            MaterialTheme.colorScheme.outlineVariant
                        },
                    ),
            )
        }
    }
}
