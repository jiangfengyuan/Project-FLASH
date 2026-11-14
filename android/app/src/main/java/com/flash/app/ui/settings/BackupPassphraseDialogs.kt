// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package com.flash.app.ui.settings

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.unit.dp
import com.flash.app.data.BackupEncryption
import com.flash.app.i18n.tr

/**
 * 导出 / 分享前的加密选择（默认加密）。`onConfirm(null)` 表示用户选择不加密。
 * 口令只放在 `remember`（不进 saved state），Flash 不保存口令。
 */
@Composable
internal fun BackupExportOptionsDialog(onConfirm: (String?) -> Unit, onDismiss: () -> Unit) {
    var encrypt by remember { mutableStateOf(true) }
    var passphrase by remember { mutableStateOf("") }
    var confirmation by remember { mutableStateOf("") }
    var problem by remember { mutableStateOf<String?>(null) }
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(tr("导出备份")) },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text(tr("用口令加密备份（推荐）"), modifier = Modifier.weight(1f))
                    Switch(checked = encrypt, onCheckedChange = { encrypt = it; problem = null })
                }
                Text(
                    if (encrypt) tr("没有口令的人无法读取或改动备份内容。Flash 不保存口令，忘记后无法恢复。")
                    else tr("不加密的备份是明文 JSON，任何拿到文件的人都能读取全部日志、情绪和任务。仅保存或分享给可信设备或联系人。"),
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
                if (encrypt) {
                    PassphraseField(passphrase, tr("口令（至少 8 个字符）")) { passphrase = it; problem = null }
                    PassphraseField(confirmation, tr("再次输入口令")) { confirmation = it; problem = null }
                }
                problem?.let { Text(it, color = MaterialTheme.colorScheme.error, style = MaterialTheme.typography.bodySmall) }
            }
        },
        confirmButton = {
            TextButton(
                enabled = !encrypt || passphrase.isNotEmpty(),
                onClick = {
                    if (!encrypt) return@TextButton onConfirm(null)
                    val issue = BackupEncryption.exportPassphraseProblem(passphrase)
                        ?: if (passphrase != confirmation) tr("两次输入的口令不一致") else null
                    if (issue != null) problem = issue else onConfirm(passphrase)
                },
            ) { Text(tr("继续")) }
        },
        dismissButton = { TextButton(onClick = onDismiss) { Text(tr("取消")) } },
    )
}

/** 导入加密备份时输入口令；`error` 为上次尝试的错误文案 */
@Composable
internal fun BackupPassphrasePromptDialog(error: String?, onSubmit: (String) -> Unit, onDismiss: () -> Unit) {
    var passphrase by remember { mutableStateOf("") }
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(tr("加密备份")) },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                Text(tr("这是加密备份，请输入导出时设置的口令"))
                PassphraseField(passphrase, tr("口令")) { passphrase = it }
                error?.let { Text(it, color = MaterialTheme.colorScheme.error, style = MaterialTheme.typography.bodySmall) }
            }
        },
        confirmButton = {
            TextButton(enabled = passphrase.isNotEmpty(), onClick = { onSubmit(passphrase) }) { Text(tr("解密")) }
        },
        dismissButton = { TextButton(onClick = onDismiss) { Text(tr("取消")) } },
    )
}

@Composable
private fun PassphraseField(value: String, label: String, onChange: (String) -> Unit) {
    OutlinedTextField(
        value = value,
        onValueChange = onChange,
        label = { Text(label) },
        singleLine = true,
        visualTransformation = PasswordVisualTransformation(),
        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Password, autoCorrectEnabled = false),
        modifier = Modifier.fillMaxWidth(),
    )
}
