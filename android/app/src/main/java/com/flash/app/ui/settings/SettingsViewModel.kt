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
import com.flash.app.data.BackupEncryption
import com.flash.app.data.BackupImportSession
import com.flash.app.data.LocalBackupTransfer
import com.flash.app.data.SettingsStore
import com.flash.app.data.ThemeMode
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

/** 加密备份的口令框：`error` 为上次尝试的错误（口令错误等） */
data class PassphrasePrompt(val recovery: Boolean, val error: String? = null)

class SettingsViewModel(
    private val app: Application,
    private val settings: SettingsStore,
) : ViewModel() {

    private val repository get() = (app as FlashApplication).repository
    private val taskReminders get() = (app as FlashApplication).taskReminders

    val themeMode = settings.themeMode

    private val _message = MutableStateFlow<String?>(null)
    val message: StateFlow<String?> = _message.asStateFlow()

    private val _importPreview = MutableStateFlow<ImportPreview?>(null)
    val importPreview: StateFlow<ImportPreview?> = _importPreview.asStateFlow()
    private val importSession = BackupImportSession()
    private val importCommitMutex = Mutex()

    private val _passphrasePrompt = MutableStateFlow<PassphrasePrompt?>(null)
    val passphrasePrompt: StateFlow<PassphrasePrompt?> = _passphrasePrompt.asStateFlow()
    /** 等待口令的加密备份原文：只在内存中，取消或成功后清空 */
    private var pendingEncryptedText: String? = null

    /**
     * 导出前的加密选择（明文或带口令），`null` 为尚未选择。系统「创建文件」页面期间保存在
     * ViewModel（随配置变更保留）；进程被回收则丢失，导出会中止而不是悄悄写明文。
     */
    private var pendingExport: ExportChoice? = null

    private sealed interface ExportChoice {
        data object Plain : ExportChoice
        class Encrypted(val passphrase: String) : ExportChoice
    }

    private val _shareUri = MutableStateFlow<Uri?>(null)
    val shareUri: StateFlow<Uri?> = _shareUri.asStateFlow()

    private val _transferInProgress = MutableStateFlow(false)
    val transferInProgress: StateFlow<Boolean> = _transferInProgress.asStateFlow()

    private val _lanTransfer = MutableStateFlow(LanTransferState())
    val lanTransfer: StateFlow<LanTransferState> = _lanTransfer.asStateFlow()

    fun setThemeMode(mode: ThemeMode) = settings.setThemeMode(mode)

    fun clearMessage() {
        _message.value = null
    }

    /** 第一步：记下加密选择（`null` = 不加密），随后界面打开系统「创建文件」 */
    fun chooseExport(passphrase: String?) {
        pendingExport = if (passphrase == null) ExportChoice.Plain else ExportChoice.Encrypted(passphrase)
    }

    /** 用户取消了系统「创建文件」：丢弃记下的口令 */
    fun cancelExport() {
        pendingExport = null
    }

    fun exportBackup(target: Uri) {
        val choice = pendingExport
        pendingExport = null
        if (choice == null) {
            _message.value = com.flash.app.i18n.tr("导出已中断，请重新导出")
            return
        }
        viewModelScope.launch(Dispatchers.IO) {
            runCatching {
                val snapshot = repository.exportSnapshot()
                val plain = Backup.exportJson(snapshot.logs, snapshot.emotions, snapshot.tasks)
                val json = if (choice is ExportChoice.Encrypted) BackupEncryption.encrypt(plain, choice.passphrase) else plain
                app.contentResolver.openOutputStream(target, "wt")?.use { out ->
                    out.write(json.toByteArray(Charsets.UTF_8))
                } ?: error(com.flash.app.i18n.tr("无法写入文件"))
            }.onSuccess {
                _message.value = com.flash.app.i18n.tr("备份已导出")
            }.onFailure {
                _message.value = com.flash.app.i18n.tr("导出失败：{0}", it.message)
            }
        }
    }

    /** `passphrase` 为 null 时分享明文备份 */
    fun prepareBackupTransfer(passphrase: String?) {
        if (_transferInProgress.value) return
        _transferInProgress.value = true
        viewModelScope.launch(Dispatchers.IO) {
            runCatching {
                val snapshot = repository.exportSnapshot()
                val plain = Backup.exportJson(snapshot.logs, snapshot.emotions, snapshot.tasks)
                val json = if (passphrase != null) BackupEncryption.encrypt(plain, passphrase) else plain
                BackupTransfer.createShareUri(app, json, encrypted = passphrase != null)
            }.onSuccess {
                _shareUri.value = it
            }.onFailure {
                _message.value = com.flash.app.i18n.tr("生成传输文件失败：{0}", it.message)
            }
            _transferInProgress.value = false
        }
    }

    fun consumeShareUri() {
        _shareUri.value = null
    }

    fun reportShareFailure() {
        _message.value = com.flash.app.i18n.tr("无法打开系统分享，请先安装可接收文件的应用")
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
                if (size > BackupEncryption.MAX_ENVELOPE_BYTES) {
                    throw Backup.BackupFormatException(com.flash.app.i18n.tr("备份文件超过 {0} MB，无法导入", BackupEncryption.MAX_ENVELOPE_BYTES / 1024 / 1024))
                }

                val text = app.contentResolver.openInputStream(source)?.use { input ->
                    importSession.attachResource(generation, input)
                    try { Backup.readJson(input, BackupEncryption.MAX_ENVELOPE_BYTES) } finally { importSession.releaseResource(generation, input) }
                }
                    ?: error(com.flash.app.i18n.tr("无法读取文件"))
                currentCoroutineContext().ensureActive()
                try {
                    buildPreview(text, recovery, passphrase = null)
                } catch (e: BackupEncryption.PassphraseRequiredException) {
                    // 原文留在内存里，等用户输入口令；不必再次读取 content:// 文件
                    importSession.publish(generation) {
                        pendingEncryptedText = text
                        _passphrasePrompt.value = PassphrasePrompt(recovery)
                    }
                    return@launch
                }
            }.onSuccess {
                importSession.publish(generation) { _importPreview.value = it }
            }.onFailure { e ->
                if (e is CancellationException) return@onFailure
                importSession.publish(generation) {
                    _message.value = when (e) {
                        is Backup.BackupFormatException -> e.message
                        else -> com.flash.app.i18n.tr("导入失败：{0}", e.message)
                    }
                }
            }
        }
        importSession.attach(generation, operation)
    }

    /** 加密备份：用口令解密并生成预览；口令错误时口令框带错误提示重新出现 */
    fun submitPassphrase(passphrase: String) {
        val prompt = _passphrasePrompt.value ?: return
        val text = pendingEncryptedText ?: return
        _passphrasePrompt.value = null
        val generation = importSession.begin()
        val operation = viewModelScope.launch(Dispatchers.IO) {
            runCatching {
                buildPreview(text, prompt.recovery, passphrase)
            }.onSuccess {
                importSession.publish(generation) {
                    pendingEncryptedText = null
                    _importPreview.value = it
                }
            }.onFailure { e ->
                if (e is CancellationException) return@onFailure
                importSession.publish(generation) {
                    if (e is BackupEncryption.AuthenticationFailedException) {
                        _passphrasePrompt.value = prompt.copy(error = e.message)
                    } else {
                        pendingEncryptedText = null
                        _message.value = when (e) {
                            is Backup.BackupFormatException -> e.message
                            else -> com.flash.app.i18n.tr("导入失败：{0}", e.message)
                        }
                    }
                }
            }
        }
        importSession.attach(generation, operation)
    }

    fun cancelPassphrase() {
        _passphrasePrompt.value = null
        pendingEncryptedText = null
    }

    private suspend fun buildPreview(text: String, recovery: Boolean, passphrase: String?): ImportPreview {
        val result = BackupEncryption.parseText(text, recovery, passphrase)
        currentCoroutineContext().ensureActive()
        val local = repository.exportSnapshot()
        return ImportPreview(
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
                                _message.value = com.flash.app.i18n.tr("预览后本地数据有变化，差异已重新计算，请确认后再覆盖")
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
                        _message.value = com.flash.app.i18n.tr("导入失败：{0}", databaseResult.exceptionOrNull()?.message)
                    }
                    return@launch
                }

                val importedMessage = com.flash.app.i18n.tr("已导入 {0} 条日志、{1} 条情绪、", preview.logCount, preview.emotionCount) +
                    com.flash.app.i18n.tr("{0} 个任务", preview.taskCount) +
                    if (preview.skippedLogs + preview.skippedEmotions + preview.skippedTasks > 0) {
                        com.flash.app.i18n.tr("（跳过异常数据 {0} 条）", preview.skippedLogs + preview.skippedEmotions + preview.skippedTasks)
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
                        else com.flash.app.i18n.tr("{0}，但系统提醒恢复失败，请稍后重试", importedMessage)
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
                _message.value = com.flash.app.i18n.tr("清空失败：{0}", databaseResult.exceptionOrNull()?.message)
                return@launch
            }
            val reminderFailure = runCatching { taskReminders.rebuild(emptyList()) }.exceptionOrNull()
            _message.value = if (reminderFailure == null) {
                com.flash.app.i18n.tr("已清空全部数据")
            } else {
                com.flash.app.i18n.tr("已清空全部数据，但系统提醒清理失败，请重启应用后重试")
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
