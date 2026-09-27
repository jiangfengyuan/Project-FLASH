// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package com.flash.app.ui.settings

import android.Manifest
import android.content.ClipData
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
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
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material.icons.outlined.Build
import androidx.compose.material.icons.outlined.DarkMode
import androidx.compose.material.icons.outlined.DeleteForever
import androidx.compose.material.icons.outlined.Download
import androidx.compose.material.icons.outlined.FileDownload
import androidx.compose.material.icons.outlined.FileUpload
import androidx.compose.material.icons.outlined.Info
import androidx.compose.material.icons.outlined.Palette
import androidx.compose.material.icons.outlined.Share
import androidx.compose.material.icons.outlined.Shield
import androidx.compose.material.icons.outlined.Wifi
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
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
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.unit.dp
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.foundation.text.KeyboardOptions
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.core.content.ContextCompat
import com.flash.app.BuildConfig
import com.flash.app.FlashApplication
import com.flash.app.data.ThemeMode
import com.flash.app.data.UiStyle
import com.flash.app.data.LocalBackupTransfer
import com.flash.app.ui.components.FlashCard
import com.flash.app.ui.components.FlashSegmentedControl
import com.flash.app.ui.theme.FlashTokens
import java.time.LocalDateTime
import java.time.format.DateTimeFormatter

/** 设置/我的 页：本地存储提示 + 外观 / 数据与安全 / 危险操作 / 关于。作为「我的」Tab 时 onBack 传 null */
@Composable
fun SettingsScreen(onBack: (() -> Unit)? = null) {
    val context = LocalContext.current
    val app = context.applicationContext as FlashApplication
    val viewModel: SettingsViewModel = viewModel(factory = SettingsViewModel.factory(app))
    val themeMode by viewModel.themeMode.collectAsStateWithLifecycle()
    val uiStyle by viewModel.uiStyle.collectAsStateWithLifecycle()
    val message by viewModel.message.collectAsStateWithLifecycle()
    val importPreview by viewModel.importPreview.collectAsStateWithLifecycle()
    val shareUri by viewModel.shareUri.collectAsStateWithLifecycle()
    val transferInProgress by viewModel.transferInProgress.collectAsStateWithLifecycle()
    val lanTransfer by viewModel.lanTransfer.collectAsStateWithLifecycle()

    var showClearConfirm by remember { mutableStateOf(false) }
    var selectedLanDevice by remember { mutableStateOf<LocalBackupTransfer.Device?>(null) }
    var lanPin by remember { mutableStateOf("") }
    var pendingLanAction by remember { mutableStateOf<(() -> Unit)?>(null) }
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

    val nearbyPermissionLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestPermission(),
    ) { granted ->
        val action = pendingLanAction
        pendingLanAction = null
        if (granted) action?.invoke() else viewModel.reportLanPermissionDenied()
    }

    val runWithLanPermission: (() -> Unit) -> Unit = { action ->
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
            ContextCompat.checkSelfPermission(context, Manifest.permission.NEARBY_WIFI_DEVICES) ==
            PackageManager.PERMISSION_GRANTED
        ) {
            action()
        } else {
            pendingLanAction = action
            nearbyPermissionLauncher.launch(Manifest.permission.NEARBY_WIFI_DEVICES)
        }
    }

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
                clipData = ClipData.newRawUri("Flash Aero 备份", uri)
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }
            context.startActivity(Intent.createChooser(sendIntent, "传输 Flash Aero 备份"))
        }.onFailure {
            viewModel.reportShareFailure()
        }
    }

    Scaffold(
        containerColor = Color.Transparent,
        snackbarHost = { SnackbarHost(snackbarHostState) },
    ) { innerPadding ->
        Column(
            modifier = Modifier
                .padding(innerPadding)
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .padding(
                    start = FlashTokens.Spacing.PageHorizontal,
                    end = FlashTokens.Spacing.PageHorizontal,
                    top = FlashTokens.Spacing.XS,
                    bottom = FlashTokens.Spacing.XS + com.flash.app.ui.navigation.LocalPageBottomPadding.current,
                ),
            verticalArrangement = Arrangement.spacedBy(FlashTokens.Spacing.LG),
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                if (onBack != null) {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "返回")
                    }
                    Spacer(Modifier.width(FlashTokens.Spacing.XS))
                }
                Text("设置", style = MaterialTheme.typography.headlineMedium)
            }

            FlashCard(modifier = Modifier.fillMaxWidth()) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Icon(
                        Icons.Outlined.Shield,
                        contentDescription = null,
                        tint = MaterialTheme.colorScheme.primary,
                        modifier = Modifier.size(22.dp),
                    )
                    Spacer(Modifier.width(FlashTokens.Spacing.SM))
                    Column {
                        Text("数据默认保存在此设备", style = MaterialTheme.typography.titleSmall)
                        Text(
                            "可导出备份或在可信局域网内传输",
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                    }
                }
            }

            SettingsGroup(title = "外观与使用") {
                SettingsRow(
                    icon = Icons.Outlined.DarkMode,
                    iconTint = MaterialTheme.colorScheme.primary,
                    title = "主题模式",
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
                    icon = Icons.Outlined.Palette,
                    iconTint = MaterialTheme.colorScheme.primary,
                    title = "界面风格",
                    value = uiStyle.displayName,
                    showChevron = false,
                )
                FlashSegmentedControl(
                    options = UiStyle.entries.map { it to it.displayName },
                    selected = uiStyle,
                    onSelect = viewModel::setUiStyle,
                )
                Text(
                    if (uiStyle == UiStyle.GLASS) {
                        "柔和渐变与轻盈玻璃质感"
                    } else {
                        "清晰实色与系统原生控件"
                    },
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.padding(bottom = FlashTokens.Spacing.XS),
                )
            }

            SettingsGroup(
                title = "数据与安全",
                note = "备份为明文 JSON，包含日志、情绪和任务内容；请只保存或分享至可信位置",
                footnote = "局域网传输内容为明文，请在可信的 Wi-Fi 网络下使用",
            ) {
                SettingsRow(
                    icon = Icons.Outlined.FileUpload,
                    iconTint = MaterialTheme.colorScheme.primary,
                    title = "导出备份",
                    subtitle = "保存为 JSON 文件",
                    onClick = {
                        val timestamp = LocalDateTime.now()
                            .format(DateTimeFormatter.ofPattern("yyyy-MM-dd-HHmmss"))
                        exportLauncher.launch("flash-backup-$timestamp.json")
                    },
                )
                RowDivider()
                SettingsRow(
                    icon = Icons.Outlined.FileDownload,
                    iconTint = MaterialTheme.colorScheme.primary,
                    title = "标准导入",
                    subtitle = "导入前预览与本地数据的差异",
                    onClick = { importLauncher.launch(arrayOf("application/json", "text/*")) },
                )
                RowDivider()
                SettingsRow(
                    icon = Icons.Outlined.Build,
                    iconTint = MaterialTheme.colorScheme.tertiary,
                    title = "恢复损坏或旧版备份",
                    subtitle = "跳过异常与重复数据，不修改原文件",
                    onClick = { recoveryLauncher.launch(arrayOf("application/json", "text/*")) },
                )
                RowDivider()
                SettingsRow(
                    icon = Icons.Outlined.Share,
                    iconTint = MaterialTheme.colorScheme.secondary,
                    title = "传输到其他设备",
                    subtitle = "通过系统分享发送备份",
                    value = if (transferInProgress) "准备中…" else null,
                    enabled = !transferInProgress,
                    onClick = viewModel::prepareBackupTransfer,
                )
                RowDivider()
                SettingsRow(
                    icon = Icons.Outlined.Wifi,
                    iconTint = MaterialTheme.colorScheme.secondary,
                    title = "局域网发送",
                    subtitle = "生成六位配对 PIN，等待对方接收",
                    onClick = { runWithLanPermission(viewModel::startLanSend) },
                )
                RowDivider()
                SettingsRow(
                    icon = Icons.Outlined.Download,
                    iconTint = MaterialTheme.colorScheme.secondary,
                    title = "局域网接收",
                    subtitle = "选择发送设备并输入配对 PIN",
                    onClick = {
                        runWithLanPermission {
                            selectedLanDevice = null
                            lanPin = ""
                            viewModel.startLanReceive()
                        }
                    },
                )
            }

            SettingsGroup(title = "危险操作") {
                SettingsRow(
                    icon = Icons.Outlined.DeleteForever,
                    iconTint = MaterialTheme.colorScheme.error,
                    title = "清空全部数据",
                    titleColor = MaterialTheme.colorScheme.error,
                    subtitle = "删除所有日志、情绪记录与任务，且无法恢复；建议先导出备份",
                    onClick = { showClearConfirm = true },
                )
            }

            SettingsGroup(title = "关于 Flash") {
                SettingsRow(
                    icon = Icons.Outlined.Info,
                    iconTint = MaterialTheme.colorScheme.primary,
                    title = "Flash Aero",
                    subtitle = "让每一次闪念都有落点 · Android 版",
                    value = "v${BuildConfig.VERSION_NAME}",
                    showChevron = false,
                )
            }

            Spacer(Modifier.width(1.dp))
        }
    }

    importPreview?.let { preview ->
        AlertDialog(
            onDismissRequest = viewModel::cancelImport,
            title = { Text(if (preview.recovery) "部分恢复预览" else "标准导入预览") },
            text = {
                Text(
                    buildString {
                        append("包含 ${preview.logCount} 条日志、${preview.emotionCount} 条情绪记录、${preview.taskCount} 个任务。")
                        if (preview.skippedLogs + preview.skippedEmotions + preview.skippedTasks > 0) {
                            append("\n${preview.skippedLogs + preview.skippedEmotions + preview.skippedTasks} 条数据格式异常，将被跳过。")
                        }
                        append("\n\n差异分析")
                        append("\n日志：新增 ${preview.difference.logs.added} · 修改 ${preview.difference.logs.changed}" +
                            " · 相同 ${preview.difference.logs.unchanged} · 仅本机 ${preview.difference.logs.localOnly}")
                        append("\n情绪：新增 ${preview.difference.emotions.added} · 修改 ${preview.difference.emotions.changed}" +
                            " · 相同 ${preview.difference.emotions.unchanged} · 仅本机 ${preview.difference.emotions.localOnly}")
                        append("\n任务：新增 ${preview.difference.tasks.added} · 修改 ${preview.difference.tasks.changed}" +
                            " · 相同 ${preview.difference.tasks.unchanged} · 仅本机 ${preview.difference.tasks.localOnly}")
                        append("\n\n差异合并会新增或更新接收数据，并保留仅本机数据；覆盖会先清空本机数据。")
                    }
                )
            },
            confirmButton = {
                TextButton(onClick = { viewModel.confirmImport(overwrite = false) }) {
                    Text("按差异合并")
                }
            },
            dismissButton = {
                Row {
                    TextButton(onClick = { viewModel.confirmImport(overwrite = true) }) {
                        Text("覆盖", color = MaterialTheme.colorScheme.error)
                    }
                    TextButton(onClick = viewModel::cancelImport) { Text("取消") }
                }
            },
        )
    }

    when (lanTransfer.mode) {
        LanTransferMode.SENDING -> AlertDialog(
            onDismissRequest = viewModel::cancelLanTransfer,
            title = { Text("等待接收设备") },
            text = {
                Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                    Text("在另一台设备选择“局域网接收”，然后输入配对 PIN：")
                    Text(
                        lanTransfer.pin,
                        style = MaterialTheme.typography.displayMedium,
                        color = MaterialTheme.colorScheme.primary,
                    )
                    Text("PIN 仅本次有效，60 秒后自动失效。")
                    Text(
                        "内容未做端到端加密，请仅在可信的家庭或办公局域网使用。",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
            },
            confirmButton = {
                TextButton(onClick = viewModel::cancelLanTransfer) { Text("取消发送") }
            },
        )

        LanTransferMode.RECEIVING -> AlertDialog(
            onDismissRequest = viewModel::cancelLanTransfer,
            title = { Text("从局域网接收") },
            text = {
                Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                    Text(if (lanTransfer.devices.isEmpty()) "正在查找附近的 Flash Aero…" else "选择发送设备：")
                    lanTransfer.devices.forEach { device ->
                        OutlinedButton(
                            onClick = { selectedLanDevice = device },
                            modifier = Modifier.fillMaxWidth(),
                        ) {
                            Text(if (selectedLanDevice?.id == device.id) "✓ ${device.name}" else device.name)
                        }
                    }
                    OutlinedTextField(
                        value = lanPin,
                        onValueChange = { lanPin = it.filter(Char::isDigit).take(6) },
                        label = { Text("六位配对 PIN") },
                        singleLine = true,
                        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.NumberPassword),
                        modifier = Modifier.fillMaxWidth(),
                    )
                    Text(
                        "内容未做端到端加密，请仅连接可信的家庭或办公局域网设备。",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
            },
            confirmButton = {
                TextButton(
                    onClick = { selectedLanDevice?.let { viewModel.receiveLanBackup(it, lanPin) } },
                    enabled = selectedLanDevice != null && lanPin.length == 6,
                ) { Text("配对并接收") }
            },
            dismissButton = {
                TextButton(onClick = viewModel::cancelLanTransfer) { Text("取消") }
            },
        )

        LanTransferMode.CONNECTING -> AlertDialog(
            onDismissRequest = {},
            title = { Text("正在配对") },
            text = {
                Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                    CircularProgressIndicator()
                    Text("正在验证 PIN 并接收备份…")
                }
            },
            confirmButton = {
                TextButton(onClick = viewModel::cancelLanTransfer) { Text("取消") }
            },
        )

        LanTransferMode.IDLE -> Unit
    }

    if (showClearConfirm) {
        AlertDialog(
            onDismissRequest = { showClearConfirm = false },
            title = { Text("清空全部数据？") },
            text = { Text("将删除所有日志、情绪记录与任务，且无法恢复。建议先导出备份。") },
            confirmButton = {
                TextButton(onClick = {
                    viewModel.clearAll()
                    showClearConfirm = false
                }) {
                    Text("确认清空", color = MaterialTheme.colorScheme.error)
                }
            },
            dismissButton = {
                TextButton(onClick = { showClearConfirm = false }) { Text("取消") }
            },
        )
    }
}

/** 分组：弱化标题 + 可选说明文字 + 大圆角分组卡片 + 可选脚注 */
@Composable
private fun SettingsGroup(
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
private fun SettingsRow(
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
private fun RowDivider() {
    HorizontalDivider(
        modifier = Modifier.padding(start = 22.dp + FlashTokens.Spacing.SM),
        color = MaterialTheme.colorScheme.outlineVariant,
    )
}

private fun ThemeMode.displayName(): String = when (this) {
    ThemeMode.SYSTEM -> "跟随系统"
    ThemeMode.LIGHT -> "浅色"
    ThemeMode.DARK -> "深色"
}
