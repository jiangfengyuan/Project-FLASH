package com.flash.app.data

import android.net.Uri
import androidx.core.content.FileProvider
import androidx.test.platform.app.InstrumentationRegistry
import com.flash.app.FlashApplication
import com.flash.app.i18n.tr
import com.flash.app.ui.settings.SettingsViewModel
import kotlinx.coroutines.flow.filterNotNull
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.withTimeout
import org.junit.Assert.*
import org.junit.Assume.assumeTrue
import org.junit.Test
import java.io.File
import org.json.JSONObject

/** Opt-in paired test on a fresh disposable Debug install. The caller force-stops the app
 * between the write/read instrumentation invocations, and supplies the four Mac-generated files. */
class LibraryFileInteropTest {
    private val instrumentation get() = InstrumentationRegistry.getInstrumentation()
    private val app get() = instrumentation.targetContext.applicationContext as FlashApplication
    private val peerDir get() = File(app.filesDir, "backup-interop/mac-out")
    private fun staged(file: File): Uri {
        val copy = File(app.cacheDir, "shared-backups/interop-" + file.name)
        copy.parentFile!!.mkdirs()
        file.copyTo(copy, overwrite = true)
        return FileProvider.getUriForFile(app, app.packageName + ".backup-files", copy)
    }

    private suspend fun applyFile(vm: SettingsViewModel, file: File, overwrite: Boolean) {
        val encrypted = file.name.contains("-encrypted")
        val v2 = file.name.startsWith("records-v2")
        vm.clearMessage()
        vm.loadImport(staged(file))
        if (encrypted) {
            vm.passphrasePrompt.filterNotNull().first()
            val previous = app.repository.exportSnapshot()
            vm.submitPassphrase("incorrect-synthetic-password")
            vm.passphrasePrompt.first { it?.error != null }
            assertEquals(previous, app.repository.exportSnapshot())
            vm.submitPassphrase(PASSPHRASE)
        }
        val preview = vm.importPreview.filterNotNull().first()
        assertEquals(if (v2) Backup.BACKUP_VERSION else LibraryBackup.V4, preview.sourceVersion)
        assertEquals(0, preview.skippedLogs + preview.skippedEmotions + preview.skippedTasks)
        vm.confirmImport(overwrite)
        val success = tr("已导入 {0} 条日志、{1} 条情绪、", preview.logCount, preview.emotionCount) +
            tr("{0} 个任务", preview.taskCount)
        assertEquals(success, vm.message.filterNotNull().first())
        assertNull("Overwrite became stale", vm.importPreview.value)
    }

    private fun assertContents(expected: Backup.ImportResult, actual: FlashSnapshot, expectMetadata: Boolean) {
        assertEquals(expected.logs.sortedBy { it.id }, actual.logs.sortedBy { it.id })
        assertEquals(expected.emotions.sortedBy { it.id }, actual.emotions.sortedBy { it.id })
        assertEquals(expected.tasks.sortedBy { it.id }, actual.tasks.sortedBy { it.id })
        assertEquals(if (expectMetadata) expected.library!!.imported() else LibraryMetadata(), actual.library)
    }

    @Test fun filesSurviveProcessRestart() = runBlocking {
        val phase = InstrumentationRegistry.getArguments().getString("libraryInteropPhase")
        assumeTrue("Paired Android/Mac probe requires explicit write/read phase", phase in setOf("write", "read"))
        val vm = SettingsViewModel(app, app.settings)
        val marker = File(peerDir.parentFile, "write.ok")
        val expected = Backup.parseStrict(File(peerDir, "full-v4.json").readText())
        val assets = instrumentation.context.assets
        fun fixture(name: String) = assets.open("fixtures/" + name + ".json").bufferedReader().use { Backup.parseStrict(it.readText()) }
        val core = fixture("valid-schema2")
        val archive = fixture("valid-library-v4")
        assertEquals((core.logs + archive.logs).sortedBy { it.id }, expected.logs.sortedBy { it.id })
        assertEquals(core.emotions.sortedBy { it.id }, expected.emotions.sortedBy { it.id })
        assertEquals(core.tasks.sortedBy { it.id }, expected.tasks.sortedBy { it.id })
        val before = app.repository.exportSnapshot()
        if (phase == "write") {
            // Never replace an existing user's library, even on an accidentally targeted install.
            check(before == FlashSnapshot(emptyList(), emptyList(), emptyList())) { "Use a fresh disposable install" }
        } else {
            check(marker.isFile && marker.readText() == "synthetic-v4") { "write phase required" }
            assertContents(expected, before, true)
        }
        withTimeout(180_000) {
            if (phase == "write") {
                val complete = File(peerDir, "full-v4.json")
                vm.loadImport(staged(complete))
                vm.importPreview.filterNotNull().first()
                vm.cancelImport()
                assertEquals(before, app.repository.exportSnapshot())
                val bad = File(peerDir.parentFile, "invalid-test.json")
                for (contents in listOf("{", JSONObject(complete.readText()).put("version", "flash-backup-v99").toString())) {
                    bad.writeText(contents)
                    vm.clearMessage()
                    vm.loadImport(staged(bad))
                    vm.message.filterNotNull().first()
                    assertNull(vm.importPreview.value)
                    assertEquals(before, app.repository.exportSnapshot())
                }
                for (name in listOf("full-v4.json", "full-v4-encrypted.json")) {
                    for (overwrite in listOf(true, false)) {
                        applyFile(vm, File(peerDir, name), overwrite)
                        assertContents(expected, app.repository.exportSnapshot(), true)
                    }
                }
                for (name in listOf("records-v2.json", "records-v2-encrypted.json")) {
                    applyFile(vm, File(peerDir, name), overwrite = false)
                    assertContents(expected, app.repository.exportSnapshot(), true)
                    applyFile(vm, File(peerDir, name), overwrite = true)
                    assertContents(expected, app.repository.exportSnapshot(), false)
                    applyFile(vm, complete, overwrite = true)
                    assertContents(expected, app.repository.exportSnapshot(), true)
                }
                marker.writeText("synthetic-v4")
            } else {
                val destination = File(app.filesDir, "backup-interop/android-out").apply { mkdirs() }
                for (v2 in listOf(false, true)) {
                    for (encrypted in listOf(false, true)) {
                        val passphrase = if (encrypted) PASSPHRASE else null
                        val name = (if (v2) "records-v2" else "full-v4") + (if (encrypted) "-encrypted" else "") + ".json"
                        val file = File(destination, name)
                        vm.clearMessage()
                        vm.chooseExport(passphrase, compatibleV2 = v2)
                        vm.exportBackup(Uri.fromFile(file))
                        assertEquals(tr("备份已导出"), vm.message.filterNotNull().first())
                        val result = BackupEncryption.parseText(file.readText(), false, passphrase)
                        assertContents(expected, FlashSnapshot(result.logs, result.emotions, result.tasks,
                            result.library ?: LibraryMetadata()), !v2)
                        vm.prepareBackupTransfer(passphrase, compatibleV2 = v2)
                        val shared = vm.shareUri.filterNotNull().first()
                        val text = app.contentResolver.openInputStream(shared)!!.use { Backup.readJson(it, BackupEncryption.MAX_ENVELOPE_BYTES) }
                        assertEquals(result, BackupEncryption.parseText(text, false, passphrase))
                        vm.consumeShareUri()
                        // Restore the Android-produced file through the same file UI as the Mac peer.
                        applyFile(vm, file, overwrite = true)
                        assertContents(expected, app.repository.exportSnapshot(), !v2)
                        if (v2) applyFile(vm, File(peerDir, "full-v4.json"), overwrite = true)
                    }
                }
            }
        }
    }

    companion object { private const val PASSPHRASE = "flash-interop-20261121" }
}
