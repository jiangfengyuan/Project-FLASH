// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package com.flash.app.ui.settings

import android.app.Application
import android.net.Uri
import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import androidx.lifecycle.viewmodel.initializer
import androidx.lifecycle.viewmodel.viewModelFactory
import com.flash.app.FlashApplication
import com.flash.app.data.Backup
import com.flash.app.data.SettingsStore
import com.flash.app.data.ThemeMode
import com.flash.app.data.UiStyle
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

data class ImportPreview(
    val logCount: Int,
    val emotionCount: Int,
    val skippedLogs: Int,
    val skippedEmotions: Int,
    val logs: List<com.flash.app.data.model.LogItem>,
    val emotions: List<com.flash.app.data.model.EmotionRecord>,
)

class SettingsViewModel(
    private val app: Application,
    private val settings: SettingsStore,
) : ViewModel() {

    private val repository get() = (app as FlashApplication).repository

    val themeMode = settings.themeMode
    val uiStyle = settings.uiStyle
    val dynamicColor = settings.dynamicColor

    private val _message = MutableStateFlow<String?>(null)
    val message: StateFlow<String?> = _message.asStateFlow()

    private val _importPreview = MutableStateFlow<ImportPreview?>(null)
    val importPreview: StateFlow<ImportPreview?> = _importPreview.asStateFlow()

    fun setThemeMode(mode: ThemeMode) = settings.setThemeMode(mode)
    fun setUiStyle(style: UiStyle) = settings.setUiStyle(style)
    fun setDynamicColor(enabled: Boolean) = settings.setDynamicColor(enabled)

    fun clearMessage() {
        _message.value = null
    }

    fun exportBackup(target: Uri) {
        viewModelScope.launch {
            runCatching {
                val (logs, emotions) = repository.exportSnapshot()
                val json = Backup.exportJson(logs, emotions)
                app.contentResolver.openOutputStream(target, "wt")?.use { out ->
                    out.write(json.toByteArray(Charsets.UTF_8))
                } ?: error("无法写入文件")
            }.onSuccess {
                _message.value = "备份已导出"
            }.onFailure {
                _message.value = "导出失败：${it.message}"
            }
        }
    }

    /** 第一步：读取并解析，弹出预览让用户选择合并或覆盖 */
    fun loadImport(source: Uri) {
        viewModelScope.launch {
            runCatching {
                val text = app.contentResolver.openInputStream(source)?.use { input ->
                    input.readBytes().toString(Charsets.UTF_8)
                } ?: error("无法读取文件")
                val result = Backup.parse(text)
                ImportPreview(
                    logCount = result.logs.size,
                    emotionCount = result.emotions.size,
                    skippedLogs = result.skippedLogs,
                    skippedEmotions = result.skippedEmotions,
                    logs = result.logs,
                    emotions = result.emotions,
                )
            }.onSuccess {
                _importPreview.value = it
            }.onFailure { e ->
                _message.value = when (e) {
                    is Backup.BackupFormatException -> e.message
                    else -> "导入失败：${e.message}"
                }
            }
        }
    }

    fun confirmImport(overwrite: Boolean) {
        val preview = _importPreview.value ?: return
        viewModelScope.launch {
            runCatching {
                if (overwrite) {
                    repository.replaceAll(preview.logs, preview.emotions)
                } else {
                    repository.mergeAll(preview.logs, preview.emotions)
                }
            }.onSuccess {
                _message.value = "已导入 ${preview.logCount} 条日志、${preview.emotionCount} 条情绪" +
                    if (preview.skippedLogs + preview.skippedEmotions > 0) {
                        "（跳过异常数据 ${preview.skippedLogs + preview.skippedEmotions} 条）"
                    } else {
                        ""
                    }
            }.onFailure {
                _message.value = "导入失败：${it.message}"
            }
            _importPreview.value = null
        }
    }

    fun cancelImport() {
        _importPreview.value = null
    }

    fun clearAll() {
        viewModelScope.launch {
            runCatching { repository.clearAll() }
                .onSuccess { _message.value = "已清空全部数据" }
                .onFailure { _message.value = "清空失败：${it.message}" }
        }
    }

    companion object {
        fun factory(app: FlashApplication): ViewModelProvider.Factory = viewModelFactory {
            initializer { SettingsViewModel(app, app.settings) }
        }
    }
}
