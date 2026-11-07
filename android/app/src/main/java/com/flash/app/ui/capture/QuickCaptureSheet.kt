// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package com.flash.app.ui.capture

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowUpward
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilledIconButton
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButtonDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Text
import androidx.compose.material3.TextField
import androidx.compose.material3.TextFieldDefaults
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.unit.dp
import com.flash.app.data.TextLimits
import com.flash.app.data.model.Category
import com.flash.app.i18n.tr
import com.flash.app.ui.components.FlashSegmentedControl
import com.flash.app.ui.components.rememberFlashHaptics
import com.flash.app.ui.theme.FlashTokens
import com.flash.app.ui.theme.LocalIsDarkTheme
import com.flash.app.ui.theme.PaperColors

/** 判断这次输入是否「末尾单独键入回车」：是则提交；粘贴多行保留换行（口径同 iOS）。 */
internal fun isTypedTrailingReturn(previous: String, next: String): Boolean =
    next.length == previous.length + 1 && next.endsWith("\n") && next.startsWith(previous)

/**
 * 快速记录面板（对齐 iOS QuickCapture）：默认灵感，可切日志；输入框随内容增高；
 * 回车即存；保存成功关闭并有触感，失败保留输入；未提交的内容留作草稿。
 *
 * `initialText` 来自系统分享时，由用户确认后才保存，且不覆盖既有草稿。
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun QuickCaptureSheet(
    initialCategory: Category,
    initialText: String?,
    draft: String,
    onDraftChange: (String) -> Unit,
    onDismiss: () -> Unit,
    onSave: suspend (String, Category) -> Unit,
) {
    val shared = initialText != null
    var text by rememberSaveable { mutableStateOf(initialText ?: draft) }
    var category by rememberSaveable { mutableStateOf(initialCategory) }
    var saving by remember { mutableStateOf(false) }
    var pendingSave by remember { mutableStateOf(false) }
    var error by remember { mutableStateOf<String?>(null) }
    val haptics = rememberFlashHaptics()
    val focus = remember { FocusRequester() }
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    val dark = LocalIsDarkTheme.current
    val limit = TextLimits.MAX_CONTENT_LENGTH
    val remaining = limit - text.length
    val overLimit = remaining < 0
    val canSave = text.isNotBlank() && !overLimit && !saving

    LaunchedEffect(Unit) { focus.requestFocus() }
    LaunchedEffect(pendingSave) {
        if (!pendingSave) return@LaunchedEffect
        pendingSave = false
        if (!canSave) return@LaunchedEffect
        saving = true
        error = null
        runCatching { onSave(text, category) }
            .onSuccess {
                haptics.success()
                if (!shared) onDraftChange("")
                onDismiss()
            }
            .onFailure { error = it.message ?: tr("保存失败，请重试") }
        saving = false
    }

    ModalBottomSheet(
        onDismissRequest = {
            if (!shared) onDraftChange(text)
            onDismiss()
        },
        sheetState = sheetState,
        // 硫酸纸面板：半透明纸，文字仍达 AA
        containerColor = PaperColors.CardSurface.resolve(dark).copy(alpha = FlashTokens.VellumOpacity),
        scrimColor = PaperColors.Scrim.resolve(dark).copy(alpha = 0.32f),
    ) {
        Column(
            Modifier
                .fillMaxWidth()
                .imePadding()
                .navigationBarsPadding()
                .padding(horizontal = FlashTokens.Spacing.PageHorizontal)
                .padding(bottom = FlashTokens.Spacing.MD),
            verticalArrangement = Arrangement.spacedBy(FlashTokens.Spacing.SM),
        ) {
            FlashSegmentedControl(
                options = listOf(Category.IDEA to tr("灵感"), Category.LOG to tr("日志")),
                selected = category,
                onSelect = {
                    category = it
                    haptics.selection()
                },
            )
            Row(verticalAlignment = Alignment.Bottom, horizontalArrangement = Arrangement.spacedBy(FlashTokens.Spacing.SM)) {
                TextField(
                    value = text,
                    onValueChange = { next ->
                        if (isTypedTrailingReturn(text, next)) {
                            pendingSave = true
                        } else {
                            text = next
                        }
                    },
                    placeholder = { Text(tr("现在想记录什么？")) },
                    minLines = 1,
                    maxLines = 5,
                    isError = overLimit,
                    shape = RoundedCornerShape(FlashTokens.Radius.Field),
                    colors = TextFieldDefaults.colors(
                        focusedContainerColor = MaterialTheme.colorScheme.surfaceVariant,
                        unfocusedContainerColor = MaterialTheme.colorScheme.surfaceVariant,
                        errorContainerColor = MaterialTheme.colorScheme.surfaceVariant,
                        focusedIndicatorColor = Color.Transparent,
                        unfocusedIndicatorColor = Color.Transparent,
                        errorIndicatorColor = Color.Transparent,
                    ),
                    keyboardOptions = KeyboardOptions(capitalization = KeyboardCapitalization.Sentences),
                    modifier = Modifier
                        .weight(1f)
                        .heightIn(min = FlashTokens.Touch.FabMain)
                        .focusRequester(focus),
                )
                FilledIconButton(
                    onClick = { pendingSave = true },
                    enabled = canSave,
                    colors = IconButtonDefaults.filledIconButtonColors(
                        containerColor = MaterialTheme.colorScheme.primary,
                        contentColor = MaterialTheme.colorScheme.onPrimary,
                    ),
                    modifier = Modifier.size(FlashTokens.Touch.FabMain),
                ) {
                    Icon(Icons.Filled.ArrowUpward, contentDescription = tr("保存"))
                }
            }
            val hint = when {
                overLimit -> tr("超出 {0} 字", -remaining)
                remaining <= limit / 10 -> tr("还可输入 {0} 字", remaining)
                else -> null
            }
            hint?.let {
                Text(
                    it,
                    style = MaterialTheme.typography.labelMedium,
                    color = if (overLimit) MaterialTheme.colorScheme.error else MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
            error?.let {
                Text(it, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.error)
            }
            Spacer(Modifier.size(FlashTokens.Spacing.XS))
        }
    }
}
