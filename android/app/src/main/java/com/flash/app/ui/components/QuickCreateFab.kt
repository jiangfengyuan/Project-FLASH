// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package com.flash.app.ui.components

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.animation.expandVertically
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.shrinkVertically
import androidx.compose.animation.slideInVertically
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.MenuBook
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.CalendarMonth
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.filled.Lightbulb
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.FloatingActionButton
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.SmallFloatingActionButton
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.unit.dp
import com.flash.app.data.model.Category
import com.flash.app.ui.theme.FlashTokens
import com.flash.app.ui.theme.ModuleColors

/**
 * 快速创建 FAB（PRD 09 / UIUX 阶段一）：Dock 右侧独立圆形 “+”（56×56），
 * 展开四项动作菜单，自上而下顺序：记录、灵感、情绪、任务。
 * 展开动效：图标旋转 45° 变为 × + 选项上浮 + 遮罩渐入（遮罩由调用方提供），
 * 全程缓入缓出 tween，不用弹跳；Compose 动画时钟自动遵守系统减少动态设置。
 */
@Composable
fun QuickCreateFab(
    expanded: Boolean,
    onExpandedChange: (Boolean) -> Unit,
    onCreateLog: () -> Unit,
    onCreateIdea: () -> Unit,
    onCreateEmotion: () -> Unit,
    onCreateTask: () -> Unit,
    modifier: Modifier = Modifier,
) {
    fun collapse(action: () -> Unit) {
        onExpandedChange(false)
        action()
    }

    Column(modifier = modifier, horizontalAlignment = Alignment.End) {
        AnimatedVisibility(
            visible = expanded,
            enter = fadeIn(tween(FlashTokens.Motion.SelectionMs)) +
                slideInVertically(tween(FlashTokens.Motion.FabExpandMs)) { it / 6 } +
                expandVertically(tween(FlashTokens.Motion.FabExpandMs)),
            exit = fadeOut(tween(150)) +
                shrinkVertically(tween(FlashTokens.Motion.FabExpandMs)),
        ) {
            Column(
                horizontalAlignment = Alignment.End,
                verticalArrangement = Arrangement.spacedBy(FlashTokens.Spacing.SM),
            ) {
                FabOption("记录", Icons.AutoMirrored.Filled.MenuBook, ModuleColors.Log) {
                    collapse(onCreateLog)
                }
                FabOption("灵感", Icons.Filled.Lightbulb, ModuleColors.Idea) {
                    collapse(onCreateIdea)
                }
                FabOption("情绪", Icons.Filled.Favorite, ModuleColors.Emotion) {
                    collapse(onCreateEmotion)
                }
                FabOption("任务", Icons.Filled.CalendarMonth, ModuleColors.Calendar) {
                    collapse(onCreateTask)
                }
                Spacer(Modifier.height(FlashTokens.Spacing.XS))
            }
        }
        val rotation by animateFloatAsState(
            targetValue = if (expanded) 45f else 0f,
            animationSpec = tween(FlashTokens.Motion.FabExpandMs),
            label = "fabRot",
        )
        FloatingActionButton(
            onClick = { onExpandedChange(!expanded) },
            shape = CircleShape,
            containerColor = MaterialTheme.colorScheme.primary,
            contentColor = MaterialTheme.colorScheme.onPrimary,
            modifier = Modifier.size(FlashTokens.Touch.FabMain),
        ) {
            Icon(
                Icons.Filled.Add,
                contentDescription = if (expanded) "收起" else "快速创建",
                modifier = Modifier.rotate(rotation),
            )
        }
    }
}

@Composable
private fun FabOption(
    label: String,
    icon: ImageVector,
    color: Color,
    onClick: () -> Unit,
) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier.clickable(onClick = onClick),
    ) {
        // 标签加 pill 背景，压在页面卡片上也可读
        Text(
            label,
            style = MaterialTheme.typography.labelLarge,
            color = MaterialTheme.colorScheme.onSurface,
            modifier = Modifier
                .background(MaterialTheme.colorScheme.surface, RoundedCornerShape(50))
                .padding(horizontal = 12.dp, vertical = 6.dp),
        )
        Spacer(Modifier.width(10.dp))
        SmallFloatingActionButton(
            onClick = onClick,
            containerColor = color,
            contentColor = Color.White,
        ) {
            Icon(icon, contentDescription = label)
        }
    }
}

/**
 * 快速输入对话框（记录 / 灵感共用）。
 * 超限不静默截断：允许继续输入，给出可见错误态并阻止保存（对齐 macOS TextLimits 行为）。
 */
@Composable
fun QuickInputDialog(
    category: Category,
    onDismiss: () -> Unit,
    onSave: (String) -> Unit,
) {
    var text by remember { mutableStateOf("") }
    val isIdea = category == Category.IDEA
    val overLimit = text.length > MAX_QUICK_INPUT_LENGTH
    val focusRequester = remember { FocusRequester() }
    LaunchedEffect(Unit) { focusRequester.requestFocus() }
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(if (isIdea) "记录灵感" else "记录此刻") },
        text = {
            OutlinedTextField(
                value = text,
                onValueChange = { text = it },
                placeholder = { Text(if (isIdea) "此刻的想法是..." else "闪过即留...") },
                isError = overLimit,
                supportingText = {
                    Text(
                        "${text.length}/$MAX_QUICK_INPUT_LENGTH",
                        color = if (overLimit) MaterialTheme.colorScheme.error else Color.Unspecified,
                    )
                },
                modifier = Modifier
                    .fillMaxWidth()
                    .focusRequester(focusRequester),
            )
        },
        confirmButton = {
            TextButton(
                onClick = { onSave(text) },
                enabled = text.isNotBlank() && !overLimit,
            ) { Text("保存") }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) { Text("取消") }
        },
    )
}

/** 快速记录上限，与探索页输入坞一致 */
const val MAX_QUICK_INPUT_LENGTH = 140
