package com.flash.app.data

import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.fail
import org.junit.Test
import org.junit.runner.RunWith

/**
 * 在 Android 自带的加密提供者上跑共用加密样例：JVM 单元测试用的是桌面 JDK 的 PBKDF2，
 * 这里锁定 Android `PBKDF2WithHmacSHA256` 对中文 / 带重音口令按 UTF-8 编码。
 */
@RunWith(AndroidJUnit4::class)
class BackupEncryptionDeviceTest {
    private val assets = InstrumentationRegistry.getInstrumentation().context.assets
    private fun fixture(path: String) = assets.open("fixtures/$path").bufferedReader().use { it.readText() }

    @Test fun sharedEncryptedCorpusOnPlatformCrypto() {
        val manifest = JSONObject(fixture("encrypted/cases.json"))
        val cases = manifest.getJSONArray("cases")
        for (i in 0 until cases.length()) {
            val item = cases.getJSONObject(i)
            val file = item.getString("file")
            val envelope = fixture("encrypted/$file")
            val passphrase = item.optString("passphrase", manifest.getString("passphrase"))
            val expect = item.getString("expect")
            if (expect == "ok") {
                assertEquals(file, fixture(item.getString("plaintext")), BackupEncryption.decrypt(envelope, passphrase))
                continue
            }
            try {
                BackupEncryption.decrypt(envelope, passphrase)
                fail("$file decrypted but expected $expect")
            } catch (e: Backup.BackupFormatException) {
                val actual = when (e) {
                    is BackupEncryption.InvalidEnvelopeException -> "invalidEnvelope"
                    is BackupEncryption.UnsupportedEnvelopeException -> "unsupported"
                    is BackupEncryption.AuthenticationFailedException -> "authenticationFailed"
                    else -> "invalidJSON"
                }
                assertEquals(file, expect, actual)
            }
        }
    }

    @Test fun exportRoundTripOnPlatformCrypto() {
        val plaintext = fixture("valid-full.json")
        val sealed = BackupEncryption.encrypt(plaintext, "Flash 备份 café 2026")
        assertEquals(plaintext, BackupEncryption.decrypt(sealed, "Flash 备份 café 2026"))
    }
}
