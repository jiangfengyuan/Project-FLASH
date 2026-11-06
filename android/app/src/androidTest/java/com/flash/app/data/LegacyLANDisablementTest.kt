package com.flash.app.data

import androidx.test.core.app.ApplicationProvider
import androidx.test.platform.app.InstrumentationRegistry
import com.flash.app.FlashApplication
import com.flash.app.ui.settings.LanTransferMode
import com.flash.app.ui.settings.SettingsViewModel
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class LegacyLANDisablementTest {
    @Test fun everyApplicationActionStaysIdleWithActionableMessage() {
        val app = ApplicationProvider.getApplicationContext<FlashApplication>()
        InstrumentationRegistry.getInstrumentation().runOnMainSync {
            val model = SettingsViewModel(app, app.settings)
            model.startLanSend()
            assertUnavailable(model)
            model.startLanReceive()
            assertUnavailable(model)
            model.receiveLanBackup(LocalBackupTransfer.Device("spoof", "Spoofed name", "127.0.0.1", 9), "123456")
            assertUnavailable(model)
        }
    }

    private fun assertUnavailable(model: SettingsViewModel) {
        assertEquals(LanTransferMode.IDLE, model.lanTransfer.value.mode)
        assertTrue(model.lanTransfer.value.pin.isEmpty())
        assertTrue(model.lanTransfer.value.devices.isEmpty())
        assertTrue(model.message.value.orEmpty().contains("局域网传输暂时停用"))
        assertTrue(model.message.value.orEmpty().contains("导出备份"))
    }
}
