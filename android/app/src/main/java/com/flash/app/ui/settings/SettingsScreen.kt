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
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilledTonalButton
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SegmentedButton
import androidx.compose.material3.SegmentedButtonDefaults
import androidx.compose.material3.SingleChoiceSegmentedButtonRow
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
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
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
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
import java.time.LocalDateTime
import java.time.format.DateTimeFormatter

/** 设置/我的 页：外观 / 界面风格 / 数据备份 / 关于。作为「我的」Tab 时 onBack 传 null */
@OptIn(ExperimentalMaterial3Api::class)
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

    val importLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.OpenDocument(),
    ) { uri -> uri?.let(viewModel::loadImport) }

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
        topBar = {
            TopAppBar(
                title = { Text(if (onBack == null) "我的" else "设置") },
                colors = TopAppBarDefaults.topAppBarColors(containerColor = Color.Transparent),
                navigationIcon = {
                    if (onBack != null) {
                        IconButton(onClick = onBack) {
                            Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "返回")
                        }
                    }
                },
            )
        },
        snackbarHost = { SnackbarHost(snackbarHostState) },
    ) { innerPadding ->
        Column(
            modifier = Modifier
                .padding(innerPadding)
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 16.dp, vertical = 8.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            SectionTitle("外观")
            Text("界面风格", style = MaterialTheme.typography.bodyMedium)
            SingleChoiceSegmentedButtonRow(modifier = Modifier.fillMaxWidth()) {
                UiStyle.entries.forEachIndexed { index, style ->
                    SegmentedButton(
                        selected = uiStyle == style,
                        onClick = { viewModel.setUiStyle(style) },
                        shape = SegmentedButtonDefaults.itemShape(
                            index = index,
                            count = UiStyle.entries.size,
                        ),
                        colors = segmentedBrandColors(),
                    ) {
                        Text(style.displayName)
                    }
                }
            }
            Text(
                if (uiStyle == UiStyle.GLASS) {
                    "插画 × 玻璃拟态：渐变天空 + 磨砂玻璃面"
                } else {
                    "Material Design 3：品牌蓝精确 Tonal Palette"
                },
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            Text("主题模式", style = MaterialTheme.typography.bodyMedium)
            SingleChoiceSegmentedButtonRow(modifier = Modifier.fillMaxWidth()) {
                ThemeMode.entries.forEachIndexed { index, mode ->
                    SegmentedButton(
                        selected = themeMode == mode,
                        onClick = { viewModel.setThemeMode(mode) },
                        shape = SegmentedButtonDefaults.itemShape(
                            index = index,
                            count = ThemeMode.entries.size,
                        ),
                        colors = segmentedBrandColors(),
                    ) {
                        Text(
                            when (mode) {
                                ThemeMode.SYSTEM -> "跟随系统"
                                ThemeMode.LIGHT -> "浅色"
                                ThemeMode.DARK -> "深色"
                            }
                        )
                    }
                }
            }

            HorizontalDivider()
            SectionTitle("数据")
            Text(
                "备份为 JSON 文件，可通过系统分享传输到其他设备",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            FilledTonalButton(
                onClick = viewModel::prepareBackupTransfer,
                modifier = Modifier.fillMaxWidth(),
                enabled = !transferInProgress,
                colors = ButtonDefaults.filledTonalButtonColors(
                    containerColor = MaterialTheme.colorScheme.primaryContainer,
                    contentColor = MaterialTheme.colorScheme.onPrimaryContainer,
                ),
            ) { Text(if (transferInProgress) "正在准备…" else "传输到其他设备") }
            Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                FilledTonalButton(
                    onClick = { runWithLanPermission(viewModel::startLanSend) },
                    modifier = Modifier.weight(1f),
                ) { Text("局域网发送") }
                FilledTonalButton(
                    onClick = { runWithLanPermission {
                        selectedLanDevice = null
                        lanPin = ""
                        viewModel.startLanReceive()
                    } },
                    modifier = Modifier.weight(1f),
                ) { Text("局域网接收") }
            }
            Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                FilledTonalButton(
                    onClick = {
                        val timestamp = LocalDateTime.now()
                            .format(DateTimeFormatter.ofPattern("yyyy-MM-dd-HHmmss"))
                        exportLauncher.launch("flash-backup-$timestamp.json")
                    },
                    modifier = Modifier.weight(1f),
                    colors = ButtonDefaults.filledTonalButtonColors(
                        containerColor = MaterialTheme.colorScheme.primaryContainer,
                        contentColor = MaterialTheme.colorScheme.onPrimaryContainer,
                    ),
                ) { Text("导出备份") }
                FilledTonalButton(
                    onClick = { importLauncher.launch(arrayOf("application/json", "text/*")) },
                    modifier = Modifier.weight(1f),
                    colors = ButtonDefaults.filledTonalButtonColors(
                        containerColor = MaterialTheme.colorScheme.primaryContainer,
                        contentColor = MaterialTheme.colorScheme.onPrimaryContainer,
                    ),
                ) { Text("导入备份") }
            }
            OutlinedButton(
                onClick = { showClearConfirm = true },
                modifier = Modifier.fillMaxWidth(),
            ) {
                Text("清空全部数据", color = MaterialTheme.colorScheme.error)
            }

            HorizontalDivider()
            SectionTitle("关于")
            Text("Flash Aero v${BuildConfig.VERSION_NAME}", style = MaterialTheme.typography.bodyMedium)
            Text(
                "原生 Android 版（Kotlin + Compose + Room）",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
    }

    importPreview?.let { preview ->
        AlertDialog(
            onDismissRequest = viewModel::cancelImport,
            title = { Text("导入备份") },
            text = {
                Text(
                    buildString {
                        append("包含 ${preview.logCount} 条日志、${preview.emotionCount} 条情绪记录。")
                        if (preview.skippedLogs + preview.skippedEmotions > 0) {
                            append("\n${preview.skippedLogs + preview.skippedEmotions} 条数据格式异常，将被跳过。")
                        }
                        append("\n\n差异分析")
                        append("\n日志：新增 ${preview.difference.logs.added} · 修改 ${preview.difference.logs.changed}" +
                            " · 相同 ${preview.difference.logs.unchanged} · 仅本机 ${preview.difference.logs.localOnly}")
                        append("\n情绪：新增 ${preview.difference.emotions.added} · 修改 ${preview.difference.emotions.changed}" +
                            " · 相同 ${preview.difference.emotions.unchanged} · 仅本机 ${preview.difference.emotions.localOnly}")
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
                        onValueChange = { lanPin = it.filter(Char::isDigit).take(4) },
                        label = { Text("四位配对 PIN") },
                        singleLine = true,
                        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.NumberPassword),
                        modifier = Modifier.fillMaxWidth(),
                    )
                }
            },
            confirmButton = {
                TextButton(
                    onClick = { selectedLanDevice?.let { viewModel.receiveLanBackup(it, lanPin) } },
                    enabled = selectedLanDevice != null && lanPin.length == 4,
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
            text = { Text("将删除所有日志与情绪记录，且无法恢复。建议先导出备份。") },
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

@Composable
private fun SectionTitle(text: String) {
    Text(text, style = MaterialTheme.typography.titleSmall, color = MaterialTheme.colorScheme.primary)
}

/** 分段按钮选中态统一品牌紫（默认 secondaryContainer 橙系与整体色调不协调） */
@Composable
private fun segmentedBrandColors() = SegmentedButtonDefaults.colors(
    activeContainerColor = MaterialTheme.colorScheme.primaryContainer,
    activeContentColor = MaterialTheme.colorScheme.onPrimaryContainer,
    activeBorderColor = MaterialTheme.colorScheme.primary,
)
