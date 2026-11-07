// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package com.flash.app.ui.settings

import android.content.ClipData
import android.content.Intent
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material.icons.outlined.Build
import androidx.compose.material.icons.outlined.DarkMode
import androidx.compose.material.icons.outlined.DeleteForever
import androidx.compose.material.icons.outlined.FileDownload
import androidx.compose.material.icons.outlined.FileUpload
import androidx.compose.material.icons.outlined.Info
import androidx.compose.material.icons.outlined.Lightbulb
import androidx.compose.material.icons.outlined.Save
import androidx.compose.material.icons.outlined.Share
import androidx.compose.material.icons.outlined.Shield
import androidx.compose.material.icons.outlined.Wifi
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import com.flash.app.BuildConfig
import com.flash.app.FlashApplication
import com.flash.app.data.IdeaReminderFrequency
import com.flash.app.data.ThemeMode
import com.flash.app.data.reminder.IdeaReminderWork
import com.flash.app.i18n.tr
import com.flash.app.ui.components.FlashCard
import com.flash.app.ui.components.FlashSegmentedControl
import com.flash.app.ui.navigation.LocalPageBottomPadding
import com.flash.app.ui.paper.pageGutter
import com.flash.app.ui.theme.FlashTokens
import java.time.LocalDateTime
import java.time.format.DateTimeFormatter
import java.util.Locale

/** 设置页（对齐 iOS）：外观 / 灵感提醒 / 数据 / 关于，细节在子页。 */
@Composable
fun SettingsScreen(
    onOpenIdeaReminder: () -> Unit,
    onOpenBackup: () -> Unit,
    onOpenTransfer: () -> Unit,
) {
    val context = LocalContext.current
    val app = context.applicationContext as FlashApplication
    val viewModel: SettingsViewModel = viewModel(factory = SettingsViewModel.factory(app))
    val themeMode by viewModel.themeMode.collectAsStateWithLifecycle()
    val ideaEnabled by app.settings.ideaReminderEnabled.collectAsStateWithLifecycle()
    val frequency by app.settings.ideaReminderFrequency.collectAsStateWithLifecycle()

    Column(
        modifier = Modifier
            .fillMaxSize()
            .statusBarsPadding()
            .verticalScroll(rememberScrollState())
            .padding(horizontal = pageGutter())
            .padding(top = FlashTokens.Spacing.SM, bottom = FlashTokens.Spacing.LG + LocalPageBottomPadding.current),
        verticalArrangement = Arrangement.spacedBy(FlashTokens.Spacing.LG),
    ) {
        Text(tr("设置"), style = MaterialTheme.typography.headlineLarge)

        FlashCard(modifier = Modifier.fillMaxWidth(), seed = "settings-local", contentPadding = FlashTokens.Spacing.MD) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Icon(
                    Icons.Outlined.Shield,
                    contentDescription = null,
                    tint = MaterialTheme.colorScheme.primary,
                    modifier = Modifier.size(22.dp),
                )
                Spacer(Modifier.width(FlashTokens.Spacing.SM))
                Column {
                    Text(tr("数据默认保存在此设备"), style = MaterialTheme.typography.titleSmall)
                    Text(
                        tr("可导出备份或通过系统分享传输"),
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
            }
        }

        SettingsGroup(title = tr("外观与使用")) {
            SettingsRow(
                icon = Icons.Outlined.DarkMode,
                iconTint = MaterialTheme.colorScheme.primary,
                title = tr("主题模式"),
                value = themeMode.displayName(),
                showChevron = false,
            )
            FlashSegmentedControl(
                options = ThemeMode.entries.map { it to it.displayName() },
                selected = themeMode,
                onSelect = viewModel::setThemeMode,
            )
            RowDivider()
            SettingsRow(
                icon = Icons.Outlined.Lightbulb,
                iconTint = MaterialTheme.colorScheme.primary,
                title = tr("灵感提醒"),
                value = if (ideaEnabled) frequency.displayName else tr("已关闭"),
                onClick = onOpenIdeaReminder,
            )
        }

        SettingsGroup(title = tr("数据与安全")) {
            SettingsRow(
                icon = Icons.Outlined.Save,
                iconTint = MaterialTheme.colorScheme.primary,
                title = tr("备份与恢复"),
                subtitle = tr("导出、导入与清空"),
                onClick = onOpenBackup,
            )
            RowDivider()
            SettingsRow(
                icon = Icons.Outlined.Wifi,
                iconTint = MaterialTheme.colorScheme.secondary,
                title = tr("设备间传输"),
                subtitle = tr("暂时停用，点击查看替代方式"),
                onClick = onOpenTransfer,
            )
        }

        SettingsGroup(title = tr("关于 Flash")) {
            SettingsRow(
                icon = Icons.Outlined.Info,
                iconTint = MaterialTheme.colorScheme.primary,
                title = "Flash Aero",
                subtitle = tr("让每一次闪念都有落点 · 无云端账号"),
                value = "v${BuildConfig.VERSION_NAME}",
                showChevron = false,
            )
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun SettingsPageScaffold(
    title: String,
    onBack: () -> Unit,
    snackbar: SnackbarHostState? = null,
    content: @Composable ColumnScope.() -> Unit,
) {
    Scaffold(
        containerColor = Color.Transparent,
        snackbarHost = { snackbar?.let { SnackbarHost(it) } },
        topBar = {
            TopAppBar(
                title = { Text(title) },
                colors = TopAppBarDefaults.topAppBarColors(containerColor = Color.Transparent),
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = tr("返回"))
                    }
                },
            )
        },
    ) { padding ->
        Column(
            Modifier
                .padding(padding)
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .padding(horizontal = pageGutter())
                .padding(bottom = FlashTokens.Spacing.XL),
            verticalArrangement = Arrangement.spacedBy(FlashTokens.Spacing.LG),
            content = content,
        )
    }
}

/** 灵感提醒（对齐 iOS）：开关 + 频率；通知权限只在确需提醒时申请。 */
@Composable
fun IdeaReminderSettingsScreen(onBack: () -> Unit) {
    val context = LocalContext.current
    val app = context.applicationContext as FlashApplication
    val enabled by app.settings.ideaReminderEnabled.collectAsStateWithLifecycle()
    val frequency by app.settings.ideaReminderFrequency.collectAsStateWithLifecycle()
    val permission = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { }

    SettingsPageScaffold(tr("灵感提醒"), onBack) {
        SettingsGroup(
            title = tr("提醒"),
            footnote = tr("累计 {0} 个以上时，晚上 8 点提醒你梳理；打开查看过的想法不再计入。", com.flash.app.domain.IDEA_REMINDER_THRESHOLD),
        ) {
            Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.fillMaxWidth()) {
                Text(tr("想法等待梳理时提醒"), style = MaterialTheme.typography.bodyLarge, modifier = Modifier.weight(1f))
                Switch(
                    checked = enabled,
                    onCheckedChange = { on ->
                        app.settings.setIdeaReminderEnabled(on)
                        IdeaReminderWork.sync(context, on)
                        if (on) requestNotificationPermissionIfNeeded(context) { permission.launch(it) }
                    },
                )
            }
            if (enabled) {
                RowDivider()
                FlashSegmentedControl(
                    options = IdeaReminderFrequency.entries.map { it to it.displayName },
                    selected = frequency,
                    onSelect = {
                        app.settings.setIdeaReminderFrequency(it)
                        IdeaReminderWork.sync(context, true)
                    },
                )
            }
        }
    }
}

private fun requestNotificationPermissionIfNeeded(context: android.content.Context, request: (String) -> Unit) {
    if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.TIRAMISU &&
        androidx.core.content.ContextCompat.checkSelfPermission(context, android.Manifest.permission.POST_NOTIFICATIONS) !=
        android.content.pm.PackageManager.PERMISSION_GRANTED
    ) {
        request(android.Manifest.permission.POST_NOTIFICATIONS)
    }
}

/** 旧 LAN 已停用：这里只说明替代方式，不提供任何发送或接收入口。 */
@Composable
fun TransferInfoScreen(onBack: () -> Unit) {
    SettingsPageScaffold(tr("设备间传输"), onBack) {
        FlashCard(modifier = Modifier.fillMaxWidth(), seed = "transfer-info") {
            Text(tr("局域网传输暂时停用"), style = MaterialTheme.typography.titleMedium)
            Spacer(Modifier.size(FlashTokens.Spacing.XS))
            Text(
                tr("旧协议存在安全风险。请使用「备份与恢复」里的导出备份或系统分享，通过你信任的方式传到另一台设备。"),
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
    }
}

/** 备份与恢复（对齐 iOS）：导出 / 系统分享 / 标准导入 / 恢复 / 清空 */
@Composable
fun BackupSettingsScreen(onBack: () -> Unit) {
    val context = LocalContext.current
    val app = context.applicationContext as FlashApplication
    val viewModel: SettingsViewModel = viewModel(factory = SettingsViewModel.factory(app))
    val message by viewModel.message.collectAsStateWithLifecycle()
    val importPreview by viewModel.importPreview.collectAsStateWithLifecycle()
    val shareUri by viewModel.shareUri.collectAsStateWithLifecycle()
    val transferInProgress by viewModel.transferInProgress.collectAsStateWithLifecycle()
    var showClearConfirm by remember { mutableStateOf(false) }
    val snackbarHostState = remember { SnackbarHostState() }

    val exportLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.CreateDocument("application/json"),
    ) { uri -> uri?.let(viewModel::exportBackup) }
    val recoveryLauncher = rememberLauncherForActivityResult(ActivityResultContracts.OpenDocument()) {
        uri -> uri?.let { viewModel.loadImport(it, recovery = true) }
    }
    val importLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.OpenDocument(),
    ) { uri -> uri?.let { viewModel.loadImport(it) } }

    LaunchedEffect(message) {
        message?.let {
            snackbarHostState.showSnackbar(it)
            viewModel.clearMessage()
        }
    }

    LaunchedEffect(shareUri) {
        val uri = shareUri ?: return@LaunchedEffect
        viewModel.consumeShareUri()
        runCatching {
            val sendIntent = Intent(Intent.ACTION_SEND).apply {
                type = "application/json"
                putExtra(Intent.EXTRA_STREAM, uri)
                clipData = ClipData.newRawUri(tr("Flash Aero 备份"), uri)
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }
            context.startActivity(Intent.createChooser(sendIntent, tr("传输 Flash Aero 备份")))
        }.onFailure {
            viewModel.reportShareFailure()
        }
    }

    SettingsPageScaffold(tr("备份与恢复"), onBack, snackbarHostState) {
        SettingsGroup(
            title = tr("数据与安全"),
            note = tr("备份为明文 JSON，包含日志、情绪和任务内容；请只保存或分享至可信位置"),
        ) {
            SettingsRow(
                icon = Icons.Outlined.FileUpload,
                iconTint = MaterialTheme.colorScheme.primary,
                title = tr("导出备份"),
                subtitle = tr("保存为 JSON 文件"),
                onClick = {
                    // 文件名固定用与语言无关的数字，便于跨端识别
                    val timestamp = LocalDateTime.now()
                        .format(DateTimeFormatter.ofPattern("yyyy-MM-dd-HHmmss", Locale.ROOT))
                    exportLauncher.launch("flash-backup-$timestamp.json")
                },
            )
            RowDivider()
            SettingsRow(
                icon = Icons.Outlined.Share,
                iconTint = MaterialTheme.colorScheme.secondary,
                title = tr("传输到其他设备"),
                subtitle = tr("通过系统分享发送备份"),
                value = if (transferInProgress) tr("准备中…") else null,
                enabled = !transferInProgress,
                onClick = viewModel::prepareBackupTransfer,
            )
            RowDivider()
            SettingsRow(
                icon = Icons.Outlined.FileDownload,
                iconTint = MaterialTheme.colorScheme.primary,
                title = tr("标准导入"),
                subtitle = tr("导入前预览与本地数据的差异"),
                onClick = { importLauncher.launch(arrayOf("application/json", "text/*")) },
            )
            RowDivider()
            SettingsRow(
                icon = Icons.Outlined.Build,
                iconTint = MaterialTheme.colorScheme.tertiary,
                title = tr("恢复损坏或旧版备份"),
                subtitle = tr("跳过异常与重复数据，不修改原文件"),
                onClick = { recoveryLauncher.launch(arrayOf("application/json", "text/*")) },
            )
        }

        SettingsGroup(title = tr("危险操作")) {
            SettingsRow(
                icon = Icons.Outlined.DeleteForever,
                iconTint = MaterialTheme.colorScheme.error,
                title = tr("清空全部数据"),
                titleColor = MaterialTheme.colorScheme.error,
                subtitle = tr("删除所有日志、情绪记录与任务，且无法恢复；建议先导出备份"),
                onClick = { showClearConfirm = true },
            )
        }
    }

    importPreview?.let { preview ->
        val skipped = preview.skippedLogs + preview.skippedEmotions + preview.skippedTasks
        fun line(label: String, d: com.flash.app.data.DifferenceSummary) = tr(
            com.flash.app.i18n.tr("{0}：新增 {1} · 修改 {2} · 相同 {3} · 仅本机 {4}"), label, d.added, d.changed, d.unchanged, d.localOnly,
        )
        AlertDialog(
            onDismissRequest = viewModel::cancelImport,
            title = { Text(if (preview.recovery) tr("部分恢复预览") else tr("标准导入预览")) },
            text = {
                Text(
                    buildString {
                        append(tr("包含 {0} 条日志、{1} 条情绪、{2} 个任务", preview.logCount, preview.emotionCount, preview.taskCount))
                        if (skipped > 0) append("\n" + tr("{0} 条数据格式异常，将被跳过。", skipped))
                        append("\n\n" + tr("差异分析"))
                        append("\n" + line(tr("日志"), preview.difference.logs))
                        append("\n" + line(tr("情绪"), preview.difference.emotions))
                        append("\n" + line(tr("任务"), preview.difference.tasks))
                        append("\n\n" + tr("差异合并会新增或更新接收数据，并保留仅本机数据；覆盖会先清空本机数据。"))
                    },
                )
            },
            confirmButton = {
                TextButton(onClick = { viewModel.confirmImport(overwrite = false) }) { Text(tr("按差异合并")) }
            },
            dismissButton = {
                Row {
                    TextButton(onClick = { viewModel.confirmImport(overwrite = true) }) {
                        Text(tr("覆盖"), color = MaterialTheme.colorScheme.error)
                    }
                    TextButton(onClick = viewModel::cancelImport) { Text(tr("取消")) }
                }
            },
        )
    }

    if (showClearConfirm) {
        AlertDialog(
            onDismissRequest = { showClearConfirm = false },
            title = { Text(tr("清空全部数据？")) },
            text = { Text(tr("将删除所有日志、情绪记录与任务，且无法恢复。建议先导出备份。")) },
            confirmButton = {
                TextButton(onClick = {
                    viewModel.clearAll()
                    showClearConfirm = false
                }) { Text(tr("确认清空"), color = MaterialTheme.colorScheme.error) }
            },
            dismissButton = { TextButton(onClick = { showClearConfirm = false }) { Text(tr("取消")) } },
        )
    }
}

/** 分组：弱化标题 + 可选说明文字 + 大圆角分组卡片 + 可选脚注 */
@Composable
internal fun SettingsGroup(
    title: String,
    modifier: Modifier = Modifier,
    note: String? = null,
    footnote: String? = null,
    content: @Composable ColumnScope.() -> Unit,
) {
    Column(modifier = modifier, verticalArrangement = Arrangement.spacedBy(FlashTokens.Spacing.XS)) {
        Text(
            title,
            style = MaterialTheme.typography.titleSmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            modifier = Modifier.padding(horizontal = 4.dp),
        )
        if (note != null) {
            Text(
                note,
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.padding(horizontal = 4.dp),
            )
        }
        FlashCard(modifier = Modifier.fillMaxWidth(), content = content)
        if (footnote != null) {
            Text(
                footnote,
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.padding(horizontal = 4.dp),
            )
        }
    }
}

/**
 * 设置清单行：语义色图标 + 标题（可选副标题）+ 可选当前值 + 弱化箭头。
 * 色彩不是唯一信息通道：每行都有标题文字，危险行另有副标题说明后果。
 */
@Composable
internal fun SettingsRow(
    icon: ImageVector,
    iconTint: Color,
    title: String,
    modifier: Modifier = Modifier,
    subtitle: String? = null,
    value: String? = null,
    enabled: Boolean = true,
    titleColor: Color = Color.Unspecified,
    showChevron: Boolean = true,
    onClick: (() -> Unit)? = null,
) {
    val contentColor = if (enabled) {
        if (titleColor != Color.Unspecified) titleColor else MaterialTheme.colorScheme.onSurface
    } else {
        MaterialTheme.colorScheme.onSurfaceVariant
    }
    Row(
        modifier = modifier
            .fillMaxWidth()
            .heightIn(min = FlashTokens.Touch.IconButtonMin)
            .then(
                if (onClick != null) {
                    Modifier.clickable(enabled = enabled, role = Role.Button, onClick = onClick)
                } else {
                    Modifier
                },
            )
            .padding(vertical = FlashTokens.Spacing.XS),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Icon(
            icon,
            contentDescription = null,
            tint = if (enabled) iconTint else MaterialTheme.colorScheme.onSurfaceVariant,
            modifier = Modifier.size(22.dp),
        )
        Spacer(Modifier.width(FlashTokens.Spacing.SM))
        Column(Modifier.weight(1f)) {
            Text(title, style = MaterialTheme.typography.bodyLarge, color = contentColor)
            if (subtitle != null) {
                Text(
                    subtitle,
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
        }
        if (value != null) {
            Text(
                value,
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            if (showChevron) Spacer(Modifier.width(4.dp))
        }
        if (showChevron) {
            Icon(
                Icons.AutoMirrored.Filled.KeyboardArrowRight,
                contentDescription = null,
                tint = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.size(18.dp),
            )
        }
    }
}

/** 行间分隔线，起点对齐标题文字（图标 22 + 间距 12） */
@Composable
internal fun RowDivider() {
    com.flash.app.ui.paper.FlashDivider(
        seed = "settings-row",
        modifier = Modifier.padding(start = 22.dp + FlashTokens.Spacing.SM),
    )
}

internal fun ThemeMode.displayName(): String = when (this) {
    ThemeMode.SYSTEM -> com.flash.app.i18n.tr("跟随系统")
    ThemeMode.LIGHT -> com.flash.app.i18n.tr("浅色")
    ThemeMode.DARK -> com.flash.app.i18n.tr("深色")
}
