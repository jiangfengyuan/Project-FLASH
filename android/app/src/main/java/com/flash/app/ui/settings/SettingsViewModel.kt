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
import com.flash.app.data.BackupTransfer
import com.flash.app.data.BackupDiff
import com.flash.app.data.BackupDifference
import com.flash.app.data.LocalBackupTransfer
import com.flash.app.data.SettingsStore
import com.flash.app.data.ThemeMode
import com.flash.app.data.UiStyle
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.Job

enum class LanTransferMode { IDLE, SENDING, RECEIVING, CONNECTING }

data class LanTransferState(
    val mode: LanTransferMode = LanTransferMode.IDLE,
    val pin: String = "",
    val devices: List<LocalBackupTransfer.Device> = emptyList(),
)

data class ImportPreview(
    val logCount: Int,
    val emotionCount: Int,
    val skippedLogs: Int,
    val skippedEmotions: Int,
    val taskCount: Int,
    val skippedTasks: Int,
    val logs: List<com.flash.app.data.model.LogItem>,
    val emotions: List<com.flash.app.data.model.EmotionRecord>,
    val tasks: List<com.flash.app.data.model.TaskItem>,
    val difference: BackupDifference,
    val recovery: Boolean = false,
)

class SettingsViewModel(
    private val app: Application,
    private val settings: SettingsStore,
) : ViewModel() {

    private val repository get() = (app as FlashApplication).repository
    private val taskReminders get() = (app as FlashApplication).taskReminders

    val themeMode = settings.themeMode
    val uiStyle = settings.uiStyle

    private val _message = MutableStateFlow<String?>(null)
    val message: StateFlow<String?> = _message.asStateFlow()

    private val _importPreview = MutableStateFlow<ImportPreview?>(null)
    val importPreview: StateFlow<ImportPreview?> = _importPreview.asStateFlow()

    private val _shareUri = MutableStateFlow<Uri?>(null)
    val shareUri: StateFlow<Uri?> = _shareUri.asStateFlow()

    private val _transferInProgress = MutableStateFlow(false)
    val transferInProgress: StateFlow<Boolean> = _transferInProgress.asStateFlow()

    private val _lanTransfer = MutableStateFlow(LanTransferState())
    val lanTransfer: StateFlow<LanTransferState> = _lanTransfer.asStateFlow()
    private var lanSender: LocalBackupTransfer.Sender? = null
    private var lanDiscovery: LocalBackupTransfer.Discovery? = null
    private var lanReceiver: LocalBackupTransfer.Receiver? = null
    private var lanJob: Job? = null
    private var lanGeneration: Long = 0

    fun setThemeMode(mode: ThemeMode) = settings.setThemeMode(mode)
    fun setUiStyle(style: UiStyle) = settings.setUiStyle(style)

    fun clearMessage() {
        _message.value = null
    }

    fun exportBackup(target: Uri) {
        viewModelScope.launch(Dispatchers.IO) {
            runCatching {
                val snapshot = repository.exportSnapshot()
                val json = Backup.exportJson(snapshot.logs, snapshot.emotions, snapshot.tasks)
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

    fun prepareBackupTransfer() {
        if (_transferInProgress.value) return
        _transferInProgress.value = true
        viewModelScope.launch(Dispatchers.IO) {
            runCatching {
                val snapshot = repository.exportSnapshot()
                val json = Backup.exportJson(snapshot.logs, snapshot.emotions, snapshot.tasks)
                BackupTransfer.createShareUri(app, json)
            }.onSuccess {
                _shareUri.value = it
            }.onFailure {
                _message.value = "生成传输文件失败：${it.message}"
            }
            _transferInProgress.value = false
        }
    }

    fun consumeShareUri() {
        _shareUri.value = null
    }

    fun reportShareFailure() {
        _message.value = "无法打开系统分享，请先安装可接收文件的应用"
    }

    fun reportLanPermissionDenied() {
        _message.value = "需要“附近的设备”权限才能发现并连接局域网设备"
    }

    fun startLanSend() {
        cancelLanTransfer()
        val generation = lanGeneration
        val job = viewModelScope.launch(Dispatchers.IO) {
            try {
                val snapshot = repository.exportSnapshot()
                val sender = LocalBackupTransfer.Sender(
                    app,
                    Backup.exportJson(snapshot.logs, snapshot.emotions, snapshot.tasks),
                )
                if (generation != lanGeneration) {
                    sender.stop()
                    return@launch
                }
                lanSender = sender
                _lanTransfer.value = LanTransferState(LanTransferMode.SENDING, pin = sender.pin)
                val sent = try {
                    sender.run()
                } catch (cancelled: CancellationException) {
                    throw cancelled
                } catch (_: Exception) {
                    false
                }
                if (lanSender !== sender) return@launch
                if (sent) _message.value = "局域网备份已发送"
                else if (_lanTransfer.value.mode == LanTransferMode.SENDING) {
                    _message.value = "配对已结束，请重新发起"
                }
                lanSender = null
                _lanTransfer.value = LanTransferState()
            } catch (cancelled: CancellationException) {
                throw cancelled
            } catch (error: Exception) {
                if (generation != lanGeneration) return@launch
                _message.value = "无法启动局域网发送：${error.message}"
                _lanTransfer.value = LanTransferState()
            }
        }
        lanJob = job
    }

    fun startLanReceive() {
        cancelLanTransfer()
        _lanTransfer.value = LanTransferState(LanTransferMode.RECEIVING)
        lanDiscovery = LocalBackupTransfer.Discovery(app) { devices ->
            if (_lanTransfer.value.mode == LanTransferMode.RECEIVING) {
                _lanTransfer.value = _lanTransfer.value.copy(devices = devices)
            }
        }.also { it.start() }
    }

    fun receiveLanBackup(device: LocalBackupTransfer.Device, pin: String) {
        if (!pin.matches(Regex("\\d{4}"))) {
            _message.value = "请输入四位数字 PIN"
            return
        }
        lanDiscovery?.stop()
        lanDiscovery = null
        _lanTransfer.value = LanTransferState(LanTransferMode.CONNECTING)
        val receiver = LocalBackupTransfer.Receiver(device, pin)
        lanReceiver = receiver
        lanJob = viewModelScope.launch(Dispatchers.IO) {
            runCatching {
                val json = receiver.run()
                val result = Backup.parseStrict(json)
                val local = repository.exportSnapshot()
                ImportPreview(
                    result.logs.size, result.emotions.size,
                    result.skippedLogs, result.skippedEmotions,
                    result.tasks.size, result.skippedTasks,
                    result.logs, result.emotions, result.tasks,
                    BackupDiff.analyze(
                        local.logs, local.emotions, result.logs, result.emotions,
                        local.tasks, result.tasks,
                    ),
                )
            }.onSuccess {
                if (lanReceiver !== receiver) return@onSuccess
                lanReceiver = null
                _importPreview.value = it
                _lanTransfer.value = LanTransferState()
            }.onFailure {
                if (lanReceiver !== receiver) return@onFailure
                lanReceiver = null
                _message.value = "局域网接收失败：${it.message}"
                startLanReceive()
            }
        }
    }

    fun cancelLanTransfer() {
        lanGeneration++
        lanSender?.stop()
        lanSender = null
        lanDiscovery?.stop()
        lanDiscovery = null
        lanReceiver?.stop()
        lanReceiver = null
        lanJob?.cancel()
        lanJob = null
        _lanTransfer.value = LanTransferState()
    }

    /** 第一步：读取并解析，弹出预览让用户选择合并或覆盖 */
    fun loadImport(source: Uri, recovery: Boolean = false) {
        viewModelScope.launch(Dispatchers.IO) {
            runCatching {
                val size = app.contentResolver.query(
                    source,
                    arrayOf(android.provider.OpenableColumns.SIZE),
                    null,
                    null,
                    null,
                )?.use { cursor ->
                    if (cursor.moveToFirst()) {
                        cursor.getLong(cursor.getColumnIndexOrThrow(android.provider.OpenableColumns.SIZE))
                    } else 0L
                } ?: 0L
                if (size > Backup.MAX_FILE_BYTES) {
                    throw Backup.BackupFormatException("备份文件超过 ${Backup.MAX_FILE_BYTES / 1024 / 1024} MB，无法导入")
                }

                val text = app.contentResolver.openInputStream(source)?.use(Backup::readJson)
                    ?: error("无法读取文件")
                val result = if (recovery) Backup.parseRecovery(text) else Backup.parseStrict(text)
                val local = repository.exportSnapshot()
                ImportPreview(
                    recovery = recovery,
                    logCount = result.logs.size,
                    emotionCount = result.emotions.size,
                    skippedLogs = result.skippedLogs,
                    skippedEmotions = result.skippedEmotions,
                    taskCount = result.tasks.size,
                    skippedTasks = result.skippedTasks,
                    logs = result.logs,
                    emotions = result.emotions,
                    tasks = result.tasks,
                    difference = BackupDiff.analyze(
                        local.logs, local.emotions, result.logs, result.emotions,
                        local.tasks, result.tasks,
                    ),
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
        viewModelScope.launch(Dispatchers.IO) {
            val databaseResult = runCatching {
                if (overwrite) {
                    repository.replaceAll(preview.logs, preview.emotions, preview.tasks)
                } else {
                    repository.mergeAll(preview.logs, preview.emotions, preview.tasks)
                }
            }
            if (databaseResult.isFailure) {
                _message.value = "导入失败：${databaseResult.exceptionOrNull()?.message}"
                _importPreview.value = null
                return@launch
            }

            val importedMessage = "已导入 ${preview.logCount} 条日志、${preview.emotionCount} 条情绪、" +
                "${preview.taskCount} 个任务" +
                if (preview.skippedLogs + preview.skippedEmotions + preview.skippedTasks > 0) {
                    "（跳过异常数据 ${preview.skippedLogs + preview.skippedEmotions + preview.skippedTasks} 条）"
                } else {
                    ""
                }
            val reminderFailure = runCatching {
                taskReminders.rebuild(repository.exportSnapshot().tasks)
            }.exceptionOrNull()
            _message.value = if (reminderFailure == null) {
                importedMessage
            } else {
                "$importedMessage，但系统提醒恢复失败，请稍后重试"
            }
            _importPreview.value = null
        }
    }

    fun cancelImport() {
        _importPreview.value = null
    }

    fun clearAll() {
        viewModelScope.launch {
            val databaseResult = runCatching { repository.clearAll() }
            if (databaseResult.isFailure) {
                _message.value = "清空失败：${databaseResult.exceptionOrNull()?.message}"
                return@launch
            }
            val reminderFailure = runCatching { taskReminders.rebuild(emptyList()) }.exceptionOrNull()
            _message.value = if (reminderFailure == null) {
                "已清空全部数据"
            } else {
                "已清空全部数据，但系统提醒清理失败，请重启应用后重试"
            }
        }
    }

    override fun onCleared() {
        cancelLanTransfer()
        super.onCleared()
    }

    companion object {
        fun factory(app: FlashApplication): ViewModelProvider.Factory = viewModelFactory {
            initializer { SettingsViewModel(app, app.settings) }
        }
    }
}
