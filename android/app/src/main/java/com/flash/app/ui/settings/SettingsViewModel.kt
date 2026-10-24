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
import com.flash.app.data.BackupImportSession
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
import kotlinx.coroutines.currentCoroutineContext
import kotlinx.coroutines.ensureActive
import kotlinx.coroutines.NonCancellable
import kotlinx.coroutines.withContext
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock

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
    /** 预览生成时的本地快照；覆盖导入前用它做 TOCTOU 重校验。 */
    val localSnapshot: com.flash.app.data.FlashSnapshot,
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
    private val importSession = BackupImportSession()
    private val importCommitMutex = Mutex()

    private val _shareUri = MutableStateFlow<Uri?>(null)
    val shareUri: StateFlow<Uri?> = _shareUri.asStateFlow()

    private val _transferInProgress = MutableStateFlow(false)
    val transferInProgress: StateFlow<Boolean> = _transferInProgress.asStateFlow()

    private val _lanTransfer = MutableStateFlow(LanTransferState())
    val lanTransfer: StateFlow<LanTransferState> = _lanTransfer.asStateFlow()

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

    private fun reportLanUnavailable() {
        cancelLanTransfer()
        _message.value = LocalBackupTransfer.UNAVAILABLE_MESSAGE
    }

    fun startLanSend() = reportLanUnavailable()
    fun startLanReceive() = reportLanUnavailable()
    @Suppress("UNUSED_PARAMETER")
    fun receiveLanBackup(device: LocalBackupTransfer.Device, pin: String) = reportLanUnavailable()

    fun cancelLanTransfer() {
        _lanTransfer.value = LanTransferState()
    }

    /** 第一步：读取并解析，弹出预览让用户选择合并或覆盖 */
    fun loadImport(source: Uri, recovery: Boolean = false) {
        val generation = importSession.begin()
        _importPreview.value = null
        val operation = viewModelScope.launch(Dispatchers.IO) {
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

                val text = app.contentResolver.openInputStream(source)?.use { input ->
                    importSession.attachResource(generation, input)
                    try { Backup.readJson(input) } finally { importSession.releaseResource(generation, input) }
                }
                    ?: error("无法读取文件")
                currentCoroutineContext().ensureActive()
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
                    localSnapshot = local,
                )
            }.onSuccess {
                importSession.publish(generation) { _importPreview.value = it }
            }.onFailure { e ->
                if (e is CancellationException) return@onFailure
                importSession.publish(generation) {
                    _message.value = when (e) {
                        is Backup.BackupFormatException -> e.message
                        else -> "导入失败：${e.message}"
                    }
                }
            }
        }
        importSession.attach(generation, operation)
    }

    fun confirmImport(overwrite: Boolean) {
        val preview = _importPreview.value ?: return
        // Consume this confirmation once; as on Apple, the preview closes at
        // confirmation. Cancellation before the transaction owns/cancels its job.
        _importPreview.value = null
        val generation = importSession.begin()
        val operation = viewModelScope.launch(Dispatchers.IO) {
            importCommitMutex.withLock {
                val databaseResult = runCatching {
                    currentCoroutineContext().ensureActive()
                    if (overwrite) {
                        val current = repository.replaceAllIfCurrent(
                            preview.localSnapshot, preview.logs, preview.emotions, preview.tasks)
                        if (current != null) {
                            importSession.publish(generation) {
                                _importPreview.value = preview.copy(
                                    difference = BackupDiff.analyze(
                                        current.logs, current.emotions, preview.logs, preview.emotions,
                                        current.tasks, preview.tasks,
                                    ),
                                    localSnapshot = current,
                                )
                                _message.value = "预览后本地数据有变化，差异已重新计算，请确认后再覆盖"
                            }
                            return@launch
                        }
                    } else {
                        repository.mergeAll(preview.logs, preview.emotions, preview.tasks)
                    }
                }
                if (databaseResult.isFailure) {
                    if (databaseResult.exceptionOrNull() is CancellationException) return@launch
                    importSession.publish(generation) {
                        _message.value = "导入失败：${databaseResult.exceptionOrNull()?.message}"
                    }
                    return@launch
                }

                val importedMessage = "已导入 ${preview.logCount} 条日志、${preview.emotionCount} 条情绪、" +
                    "${preview.taskCount} 个任务" +
                    if (preview.skippedLogs + preview.skippedEmotions + preview.skippedTasks > 0) {
                        "（跳过异常数据 ${preview.skippedLogs + preview.skippedEmotions + preview.skippedTasks} 条）"
                    } else {
                        ""
                    }
                // Once committed, cancellation must not leave reminder side effects
                // half-restored or pretend that committed data was rolled back.
                val reminderFailure = withContext(NonCancellable) {
                    runCatching { taskReminders.rebuild(repository.exportSnapshot().tasks) }.exceptionOrNull()
                }
                importSession.publish(generation) {
                    _message.value = if (reminderFailure == null) importedMessage
                        else "$importedMessage，但系统提醒恢复失败，请稍后重试"
                }
            }
        }
        importSession.attach(generation, operation)
    }

    fun cancelImport() {
        importSession.cancel()
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
        cancelImport()
        cancelLanTransfer()
        super.onCleared()
    }

    companion object {
        fun factory(app: FlashApplication): ViewModelProvider.Factory = viewModelFactory {
            initializer { SettingsViewModel(app, app.settings) }
        }
    }
}
