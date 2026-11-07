// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package com.flash.app.ui.detail

import android.content.Intent
import androidx.activity.compose.BackHandler
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.MoreVert
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.CenterAlignedTopAppBar
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import com.flash.app.FlashApplication
import com.flash.app.data.TextLimits
import com.flash.app.data.model.Category
import com.flash.app.data.model.ColorTag
import com.flash.app.data.model.LogItem
import com.flash.app.i18n.tr
import com.flash.app.ui.components.FlashFilterChipItem
import com.flash.app.ui.components.FlashFilterChipRow
import com.flash.app.ui.components.FlashFormSection
import com.flash.app.ui.components.FlashSegmentedControl
import com.flash.app.ui.components.RecordDateField
import com.flash.app.ui.components.StyleCard
import com.flash.app.ui.components.rememberFlashHaptics
import com.flash.app.ui.navigation.LocalAppActions
import com.flash.app.ui.paper.pageGutter
import com.flash.app.ui.theme.FlashTokens
import kotlinx.coroutines.launch

/** 重要度 0–4，与备份契约一致 */
private val IMPORTANCE_LABELS = listOf(0, 1, 2, 3, 4)

/**
 * 记录编辑页（对齐 iOS LogEditSheet）：点按记录直接进入编辑。
 * 类型、正文、标签、重要度、记录日期、收藏；灵感可转为任务；
 * 系统分享是 Android 保留的能力，放在溢出菜单。未保存退出需确认。
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun RecordDetailScreen(recordId: String, onBack: () -> Unit) {
    val context = LocalContext.current
    val app = context.applicationContext as FlashApplication
    val viewModel: RecordDetailViewModel = viewModel(
        key = recordId,
        factory = RecordDetailViewModel.factory(app.repository, recordId),
    )
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()
    val record = uiState.record
    val actions = LocalAppActions.current
    val haptics = rememberFlashHaptics()
    val scope = rememberCoroutineScope()
    var menuOpen by remember { mutableStateOf(false) }
    var discard by remember { mutableStateOf(false) }

    // 只用记录首次到达时的值作为草稿，之后的外部更新（如收藏同步）不覆盖正在编辑的内容
    var content by remember(record?.id) { mutableStateOf(record?.content.orEmpty()) }
    var tag by remember(record?.id) { mutableStateOf(record?.colorTag ?: ColorTag.DAILY) }
    var category by remember(record?.id) { mutableStateOf(record?.category ?: Category.LOG) }
    var importance by remember(record?.id) { mutableIntStateOf(record?.importance ?: 0) }
    var date by remember(record?.id) { mutableStateOf(record?.recordDate.orEmpty()) }
    var favorite by remember(record?.id) { mutableStateOf(record?.isFavorite == true) }

    val dirty = record != null && (
        content != record.content || tag != record.colorTag || category != record.category ||
            importance != record.importance || date != record.recordDate ||
            favorite != (record.isFavorite == true)
        )
    val close: () -> Unit = {
        if (!uiState.busy) {
            if (dirty) discard = true else onBack()
        }
    }
    BackHandler(enabled = dirty) { close() }
    val overLimit = !TextLimits.fits(content)
    val blank = content.isBlank()

    LaunchedEffect(viewModel) {
        viewModel.events.collect { event ->
            when (event) {
                RecordDetailEvent.Saved -> {
                    haptics.success()
                    actions.toast(tr("已保存"), null, null)
                    onBack()
                }
                is RecordDetailEvent.Failed -> actions.toast(event.message, null, null)
            }
        }
    }

    Scaffold(
        containerColor = Color.Transparent,
        topBar = {
            CenterAlignedTopAppBar(
                title = { Text(if (record?.category == Category.IDEA) tr("编辑灵感") else tr("编辑记录")) },
                colors = TopAppBarDefaults.topAppBarColors(containerColor = Color.Transparent),
                navigationIcon = {
                    IconButton(onClick = close, enabled = !uiState.busy) {
                        Icon(Icons.Filled.Close, contentDescription = tr("关闭"))
                    }
                },
                actions = {
                    if (record != null) {
                        IconButton(
                            onClick = { viewModel.save(content, tag, category, importance, date, favorite) },
                            enabled = !blank && !overLimit && !uiState.busy && dirty,
                        ) {
                            Icon(
                                Icons.Filled.Check,
                                contentDescription = tr("保存"),
                                tint = if (!blank && !overLimit && dirty) {
                                    MaterialTheme.colorScheme.primary
                                } else {
                                    MaterialTheme.colorScheme.outline
                                },
                            )
                        }
                        IconButton(onClick = { menuOpen = true }) {
                            Icon(Icons.Filled.MoreVert, contentDescription = tr("更多"))
                        }
                        DropdownMenu(expanded = menuOpen, onDismissRequest = { menuOpen = false }) {
                            DropdownMenuItem(
                                text = { Text(tr("分享")) },
                                onClick = {
                                    menuOpen = false
                                    share(context, record, onFail = { actions.toast(tr("没有可用的分享应用"), null, null) })
                                },
                            )
                            if (record.category == Category.IDEA) {
                                DropdownMenuItem(
                                    text = { Text(tr("转为任务")) },
                                    onClick = {
                                        menuOpen = false
                                        actions.newTaskFromIdea(record.id, record.content)
                                    },
                                )
                            }
                            DropdownMenuItem(
                                text = { Text(tr("删除"), color = MaterialTheme.colorScheme.error) },
                                onClick = {
                                    menuOpen = false
                                    scope.launch {
                                        val undo = viewModel.deleteWithUndo() ?: return@launch
                                        haptics.light()
                                        actions.toast(tr("已删除"), tr("撤销"), undo)
                                        onBack()
                                    }
                                },
                            )
                        }
                    }
                },
            )
        },
    ) { innerPadding ->
        when {
            !uiState.loaded -> Column(
                Modifier.padding(innerPadding).fillMaxSize(),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.Center,
            ) { CircularProgressIndicator() }
            record == null -> Column(
                Modifier.padding(innerPadding).fillMaxSize().padding(FlashTokens.Spacing.LG),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.Center,
            ) {
                Text(tr("这条记录已不存在"), style = MaterialTheme.typography.titleMedium)
                Spacer(Modifier.height(FlashTokens.Spacing.SM))
                TextButton(onClick = onBack) { Text(tr("返回")) }
            }
            else -> LazyColumn(
                modifier = Modifier.padding(innerPadding).fillMaxSize().imePadding(),
                contentPadding = PaddingValues(horizontal = pageGutter(), vertical = FlashTokens.Spacing.SM),
                verticalArrangement = Arrangement.spacedBy(FlashTokens.Spacing.MD),
            ) {
                item(key = "body") {
                    StyleCard(modifier = Modifier.fillMaxWidth(), seed = "editor-body") {
                        FlashSegmentedControl(
                            options = listOf(Category.LOG to tr("日志"), Category.IDEA to tr("灵感")),
                            selected = category,
                            onSelect = { if (!uiState.busy) category = it },
                        )
                        Spacer(Modifier.height(FlashTokens.Spacing.SM))
                        OutlinedTextField(
                            value = content,
                            enabled = !uiState.busy,
                            onValueChange = { content = it },
                            placeholder = { Text(tr("记录此刻……")) },
                            isError = overLimit || blank,
                            supportingText = {
                                when {
                                    blank -> Text(tr("请输入内容"), color = MaterialTheme.colorScheme.error)
                                    overLimit -> Text(
                                        tr("超出 {0} 字", content.length - TextLimits.MAX_CONTENT_LENGTH),
                                        color = MaterialTheme.colorScheme.error,
                                    )
                                }
                            },
                            minLines = 6,
                            shape = androidx.compose.foundation.shape.RoundedCornerShape(FlashTokens.Radius.Field),
                            colors = OutlinedTextFieldDefaults.colors(
                                focusedContainerColor = MaterialTheme.colorScheme.surfaceVariant,
                                unfocusedContainerColor = MaterialTheme.colorScheme.surfaceVariant,
                                unfocusedBorderColor = Color.Transparent,
                            ),
                            modifier = Modifier.fillMaxWidth(),
                        )
                    }
                }
                item(key = "attributes") {
                    FlashFormSection(title = tr("属性")) {
                        StyleCard(modifier = Modifier.fillMaxWidth(), seed = "editor-attributes") {
                            Text(tr("标签"), style = MaterialTheme.typography.labelLarge)
                            Spacer(Modifier.height(FlashTokens.Spacing.XS))
                            FlashFilterChipRow(
                                items = ColorTag.entries.map { FlashFilterChipItem(it.name, it.displayName) },
                                selectedKey = tag.name,
                                onSelect = { if (!uiState.busy) tag = ColorTag.valueOf(it) },
                            )
                            Spacer(Modifier.height(FlashTokens.Spacing.SM))
                            Text(tr("重要度"), style = MaterialTheme.typography.labelLarge)
                            Spacer(Modifier.height(FlashTokens.Spacing.XS))
                            FlashFilterChipRow(
                                items = IMPORTANCE_LABELS.map {
                                    FlashFilterChipItem(it.toString(), if (it == 0) tr("无") else "!".repeat(it))
                                },
                                selectedKey = importance.toString(),
                                onSelect = { if (!uiState.busy) importance = it.toInt() },
                            )
                            Spacer(Modifier.height(FlashTokens.Spacing.SM))
                            Text(tr("日期"), style = MaterialTheme.typography.labelLarge)
                            RecordDateField(date, { date = it }, !uiState.busy)
                            Text(
                                tr("更改日期会同步调整日历归属与回顾统计。"),
                                style = MaterialTheme.typography.bodySmall,
                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                            )
                            Spacer(Modifier.height(FlashTokens.Spacing.SM))
                            Row(verticalAlignment = Alignment.CenterVertically) {
                                Text(tr("收藏"), style = MaterialTheme.typography.labelLarge, modifier = Modifier.weight(1f))
                                Switch(checked = favorite, onCheckedChange = { favorite = it }, enabled = !uiState.busy)
                            }
                        }
                    }
                }
            }
        }
    }

    if (discard) {
        AlertDialog(
            onDismissRequest = { discard = false },
            title = { Text(tr("放弃未保存的修改？")) },
            confirmButton = {
                TextButton(onClick = {
                    discard = false
                    onBack()
                }) { Text(tr("放弃修改")) }
            },
            dismissButton = { TextButton(onClick = { discard = false }) { Text(tr("继续编辑")) } },
        )
    }
}

private fun share(context: android.content.Context, record: LogItem, onFail: () -> Unit) {
    val intent = Intent(Intent.ACTION_SEND).apply {
        type = "text/plain"
        putExtra(Intent.EXTRA_SUBJECT, if (record.category == Category.IDEA) tr("Flash 灵感") else tr("Flash 记录"))
        putExtra(Intent.EXTRA_TEXT, record.content)
    }
    runCatching { context.startActivity(Intent.createChooser(intent, tr("分享记录"))) }.onFailure { onFail() }
}
