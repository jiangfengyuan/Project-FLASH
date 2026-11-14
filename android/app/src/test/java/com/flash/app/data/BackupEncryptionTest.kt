package com.flash.app.data

import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Test
import java.util.Base64

/** flash-backup-enc-v1：共用加密样例（docs/contracts/fixtures/encrypted/cases.json）与往返测试 */
class BackupEncryptionTest {
    private fun fixture(path: String): String = requireNotNull(
        javaClass.classLoader!!.getResourceAsStream("fixtures/$path")
    ) { "Missing shared contract fixture: $path" }.bufferedReader().use { it.readText() }

    private fun category(e: Throwable): String = when (e) {
        is BackupEncryption.InvalidEnvelopeException -> "invalidEnvelope"
        is BackupEncryption.UnsupportedEnvelopeException -> "unsupported"
        is BackupEncryption.AuthenticationFailedException -> "authenticationFailed"
        // 通用 JSON 层：语法错误或重复键
        is Backup.BackupFormatException -> "invalidJSON"
        else -> "other: $e"
    }

    @Test fun sharedEncryptedCorpus() {
        val manifest = JSONObject(fixture("encrypted/cases.json"))
        val cases = manifest.getJSONArray("cases")
        assertTrue(cases.length() >= 30)
        for (i in 0 until cases.length()) {
            val item = cases.getJSONObject(i)
            val file = item.getString("file")
            val envelope = fixture("encrypted/$file")
            val passphrase = item.optString("passphrase", manifest.getString("passphrase"))
            when (val expect = item.getString("expect")) {
                "ok" -> {
                    val plaintext = BackupEncryption.decrypt(envelope, passphrase)
                    assertEquals(file, fixture(item.getString("plaintext")), plaintext)
                    val innerValid = runCatching { Backup.parseStrict(plaintext) }.isSuccess
                    assertEquals(file, item.getBoolean("innerValid"), innerValid)
                }
                else -> try {
                    BackupEncryption.decrypt(envelope, passphrase)
                    fail("$file decrypted but expected $expect")
                } catch (e: Exception) {
                    assertEquals(file, expect, category(e))
                }
            }
        }
    }

    @Test fun plaintextImportersSignalEncryptedFiles() {
        val envelope = fixture("encrypted/valid-enc-full.json")
        assertThrows(BackupEncryption.PassphraseRequiredException::class.java) { Backup.parseStrict(envelope) }
        assertThrows(BackupEncryption.PassphraseRequiredException::class.java) { Backup.parseRecovery(envelope) }
        val future = fixture("encrypted/enc-unknown-version.json")
        assertThrows(BackupEncryption.PassphraseRequiredException::class.java) { Backup.parseStrict(future) }
        assertThrows(BackupEncryption.UnsupportedEnvelopeException::class.java) { BackupEncryption.decrypt(future, "x") }
    }

    @Test fun roundTripUsesFreshSaltNonceAndExportIterations() {
        val plaintext = fixture("valid-full.json")
        val a = BackupEncryption.encrypt(plaintext, "correct horse")
        val b = BackupEncryption.encrypt(plaintext, "correct horse")
        val rootA = JSONObject(a)
        val rootB = JSONObject(b)
        assertEquals(BackupEncryption.EXPORT_ITERATIONS, rootA.getJSONObject("kdf").getInt("iterations"))
        assertNotEquals(rootA.getJSONObject("kdf").getString("salt"), rootB.getJSONObject("kdf").getString("salt"))
        assertNotEquals(rootA.getJSONObject("cipher").getString("nonce"), rootB.getJSONObject("cipher").getString("nonce"))
        assertEquals(plaintext, BackupEncryption.decrypt(a, "correct horse"))
        assertThrows(BackupEncryption.AuthenticationFailedException::class.java) { BackupEncryption.decrypt(a, "correct horsE") }
    }

    /** 注入同一 salt / nonce / 迭代数时，Kotlin 输出与 Node 参考实现生成的样例逐字节相同 */
    @Test fun deterministicEncryptionMatchesReferenceFixture() {
        val manifest = JSONObject(fixture("encrypted/cases.json"))
        val expected = fixture("encrypted/valid-enc-minimal.json")
        val root = JSONObject(expected)
        val decoder = Base64.getDecoder()
        val produced = BackupEncryption.encrypt(
            fixture("valid-minimal.json"), manifest.getString("passphrase"),
            decoder.decode(root.getJSONObject("kdf").getString("salt")),
            decoder.decode(root.getJSONObject("cipher").getString("nonce")),
            root.getJSONObject("kdf").getInt("iterations"),
        )
        assertEquals(expected, produced)
    }

    @Test fun exportPassphraseRules() {
        assertTrue(BackupEncryption.exportPassphraseProblem("1234567") != null)
        assertNull(BackupEncryption.exportPassphraseProblem("12345678"))
        // 7 个 emoji = 14 个 UTF-16 单元，仍算 7 个字符
        assertTrue(BackupEncryption.exportPassphraseProblem("😀".repeat(7)) != null)
        // NFD「e + 组合重音」规范化后只算 1 个字符
        assertTrue(BackupEncryption.exportPassphraseProblem("café 12") != null)
        assertTrue(BackupEncryption.exportPassphraseProblem("x".repeat(1025)) != null)
        assertThrows(Backup.BackupFormatException::class.java) { BackupEncryption.encrypt("{}", "short") }
    }

    @Test fun limitsMatchContract() {
        assertEquals(69_905_088, BackupEncryption.MAX_CIPHERTEXT_BASE64)
        assertEquals(75_497_472L, BackupEncryption.MAX_ENVELOPE_BYTES)
    }

    @Test fun parseTextAsksForPassphraseThenDecrypts() {
        val manifest = JSONObject(fixture("encrypted/cases.json"))
        val envelope = fixture("encrypted/valid-enc-full.json")
        assertThrows(BackupEncryption.PassphraseRequiredException::class.java) {
            BackupEncryption.parseText(envelope, recovery = false, passphrase = null)
        }
        assertThrows(BackupEncryption.AuthenticationFailedException::class.java) {
            BackupEncryption.parseText(envelope, recovery = false, passphrase = "wrong")
        }
        val result = BackupEncryption.parseText(envelope, recovery = false, passphrase = manifest.getString("passphrase"))
        assertEquals(Backup.parseStrict(fixture("valid-full.json")), result)
    }

    @Test fun parseTextKeepsInnerRules() {
        val passphrase = JSONObject(fixture("encrypted/cases.json")).getString("passphrase")
        val inner = fixture("encrypted/enc-inner-invalid.json")
        assertThrows(Backup.BackupFormatException::class.java) { BackupEncryption.parseText(inner, false, passphrase) }
        // 恢复入口：信封必须完整，跳过坏记录只作用于解出的内容
        assertEquals(1, BackupEncryption.parseText(inner, true, passphrase).skippedLogs)
        // 嵌套信封不递归解密
        val nested = fixture("encrypted/enc-inner-envelope.json")
        val error = assertThrows(Backup.BackupFormatException::class.java) { BackupEncryption.parseText(nested, false, passphrase) }
        assertTrue(error !is BackupEncryption.PassphraseRequiredException)
    }

    @Test fun parseTextPlaintextPathUnchanged() {
        val full = fixture("valid-full.json")
        assertEquals(Backup.parseStrict(full), BackupEncryption.parseText(full, false, "ignored for plaintext"))
        val oversized = "{\"version\":\"flash-backup-v2\",\"notes\":\"" + "a".repeat(Backup.MAX_FILE_BYTES.toInt()) + "\"}"
        val error = assertThrows(Backup.BackupFormatException::class.java) { BackupEncryption.parseText(oversized, false, null) }
        assertTrue(error !is BackupEncryption.PassphraseRequiredException)
    }
}
