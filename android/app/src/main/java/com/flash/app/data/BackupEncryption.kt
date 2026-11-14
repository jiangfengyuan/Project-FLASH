package com.flash.app.data

import com.flash.app.i18n.tr
import org.json.JSONObject
import java.security.SecureRandom
import java.text.Normalizer
import java.util.Arrays
import java.util.Base64
import javax.crypto.AEADBadTagException
import javax.crypto.Cipher
import javax.crypto.SecretKeyFactory
import javax.crypto.spec.GCMParameterSpec
import javax.crypto.spec.PBEKeySpec
import javax.crypto.spec.SecretKeySpec

/**
 * 口令加密备份信封 `flash-backup-enc-v1`（docs/contracts/flash-backup-enc-v1.md）。
 *
 * 明文是一份完整 flash-backup-v2 正式导出的 UTF-8 字节；本对象只负责加解密，
 * 解出的明文仍交给 [Backup.parseStrict] / [Backup.parseRecovery]。
 * 只用系统 API：`PBKDF2WithHmacSHA256`（API 26+）与 `AES/GCM/NoPadding`。
 */
object BackupEncryption {
    const val VERSION = "flash-backup-enc-v1"
    const val VERSION_PREFIX = "flash-backup-enc-"
    private const val KDF_NAME = "PBKDF2-HMAC-SHA256"
    private const val CIPHER_NAME = "AES-256-GCM"
    const val EXPORT_ITERATIONS = 600_000
    private val ITERATION_RANGE = 100_000..10_000_000
    private const val SALT_BYTES = 16
    private const val NONCE_BYTES = 12
    private const val TAG_BYTES = 16
    /** 50 MiB 明文 + 标签的 Base64 长度 */
    internal const val MAX_CIPHERTEXT_BASE64 = 4 * ((Backup.MAX_FILE_BYTES.toInt() + TAG_BYTES + 2) / 3)
    /** 加密文件上限：50 MiB 明文 Base64 后约 66.7 MiB，另留信封头余量 */
    const val MAX_ENVELOPE_BYTES = 72L * 1024 * 1024
    const val MIN_PASSPHRASE_LENGTH = 8
    const val MAX_PASSPHRASE_LENGTH = 1024

    /** 文件是加密备份，需要口令（UI 据此弹出口令框，而不是报错） */
    class PassphraseRequiredException : Backup.BackupFormatException(tr("这是加密备份，请输入导出时设置的口令"))

    /** 信封不符合 §2（字段、取值或 Base64 编码） */
    class InvalidEnvelopeException : Backup.BackupFormatException(tr("加密备份文件已损坏或格式不正确"))

    /** 未知的信封版本、KDF 或算法 */
    class UnsupportedEnvelopeException : Backup.BackupFormatException(tr("需要更新 Flash 才能打开此加密备份"))

    /** GCM 认证失败：口令错误或文件被改动，二者无法区分；可直接重试 */
    class AuthenticationFailedException : Backup.BackupFormatException(tr("口令错误，或文件已损坏"))

    internal class Envelope(val iterations: Int, val salt: ByteArray, val nonce: ByteArray, val sealed: ByteArray)

    // ---- 口令 ----

    private fun normalized(passphrase: String): String = Normalizer.normalize(passphrase, Normalizer.Form.NFC)

    /** 导出时检查口令长度（NFC 后按 Unicode 码点计）；导入接受任何非空口令。 */
    fun exportPassphraseProblem(passphrase: String): String? {
        val text = normalized(passphrase)
        val count = text.codePointCount(0, text.length)
        return when {
            count < MIN_PASSPHRASE_LENGTH -> tr("口令至少需要 8 个字符")
            count > MAX_PASSPHRASE_LENGTH -> tr("口令不能超过 1024 个字符")
            else -> null
        }
    }

    /**
     * PBKDF2(P = UTF-8(NFC(口令)))。Android 的 PBKDF2WithHmacSHA256 把 char[] 按 UTF-8 编码；
     * 共用样例里的中文与带重音口令锁定这一点（见 BackupEncryptionTest）。
     */
    private fun deriveKey(passphrase: String, salt: ByteArray, iterations: Int): SecretKeySpec {
        val chars = normalized(passphrase).toCharArray()
        val spec = PBEKeySpec(chars, salt, iterations, 256)
        try {
            val raw = SecretKeyFactory.getInstance("PBKDF2WithHmacSHA256").generateSecret(spec).encoded
            try {
                return SecretKeySpec(raw, "AES")
            } finally {
                Arrays.fill(raw, 0)
            }
        } finally {
            spec.clearPassword()
            Arrays.fill(chars, '\u0000')
        }
    }

    // ---- 识别与解密 ----

    /** 根对象是否声明任意加密信封版本（>50 MiB 的文件只可能是信封） */
    fun isEnvelope(json: String): Boolean = runCatching {
        JSONObject(json).optString("version").startsWith(VERSION_PREFIX)
    }.getOrDefault(false)

    /** 按契约顺序校验：先版本，再字段集合；KDF / 算法名先于其余字段判断「不支持」。 */
    internal fun parseEnvelope(json: String): Envelope {
        if (json.length > MAX_ENVELOPE_BYTES) throw Backup.BackupFormatException(tr("备份文件超过 {0} MB，无法导入", MAX_ENVELOPE_BYTES / 1024 / 1024))
        if (json.startsWith("\uFEFF")) throw Backup.BackupFormatException(tr("/：不允许 UTF-8 BOM"))
        StrictJson(json).validate()
        val root = try { JSONObject(json) } catch (_: Exception) {
            throw Backup.BackupFormatException(tr("备份文件不是有效的 JSON 对象"))
        }
        val version = root.opt("version") as? String
        if (version == null || !version.startsWith(VERSION_PREFIX)) throw InvalidEnvelopeException()
        if (version != VERSION) throw UnsupportedEnvelopeException()
        root.exactKeys("version", "kdf", "cipher", "ciphertext")

        val kdf = root.opt("kdf") as? JSONObject ?: throw InvalidEnvelopeException()
        val kdfName = kdf.opt("name") as? String ?: throw InvalidEnvelopeException()
        if (kdfName != KDF_NAME) throw UnsupportedEnvelopeException()
        kdf.exactKeys("name", "iterations", "salt")
        val iterations = integer(kdf.opt("iterations"))?.takeIf { it in ITERATION_RANGE } ?: throw InvalidEnvelopeException()
        val salt = canonicalBase64(kdf.opt("salt"))
        if (salt.size != SALT_BYTES) throw InvalidEnvelopeException()

        val cipher = root.opt("cipher") as? JSONObject ?: throw InvalidEnvelopeException()
        val cipherName = cipher.opt("name") as? String ?: throw InvalidEnvelopeException()
        if (cipherName != CIPHER_NAME) throw UnsupportedEnvelopeException()
        cipher.exactKeys("name", "nonce")
        val nonce = canonicalBase64(cipher.opt("nonce"))
        if (nonce.size != NONCE_BYTES) throw InvalidEnvelopeException()

        val ciphertext = root.opt("ciphertext") as? String ?: throw InvalidEnvelopeException()
        if (ciphertext.length > MAX_CIPHERTEXT_BASE64) throw InvalidEnvelopeException()
        val sealed = canonicalBase64(ciphertext)
        if (sealed.size < TAG_BYTES) throw InvalidEnvelopeException()
        return Envelope(iterations, salt, nonce, sealed)
    }

    /** 校验信封、派生密钥并解密，返回内层 flash-backup-v2 文本（尚未校验）。 */
    fun decrypt(json: String, passphrase: String): String {
        val envelope = parseEnvelope(json)
        val plaintext = open(envelope, deriveKey(passphrase, envelope.salt, envelope.iterations))
        if (plaintext.size > Backup.MAX_FILE_BYTES) throw Backup.BackupFormatException(tr("文件超过 50 MiB"))
        return try {
            Charsets.UTF_8.newDecoder()
                .onMalformedInput(java.nio.charset.CodingErrorAction.REPORT)
                .onUnmappableCharacter(java.nio.charset.CodingErrorAction.REPORT)
                .decode(java.nio.ByteBuffer.wrap(plaintext))
                .toString()
        } catch (_: Exception) {
            throw Backup.BackupFormatException(tr("备份文件不是有效的 UTF-8 JSON"))
        } finally {
            Arrays.fill(plaintext, 0)
        }
    }

    private fun open(envelope: Envelope, key: SecretKeySpec): ByteArray = try {
        Cipher.getInstance("AES/GCM/NoPadding").run {
            init(Cipher.DECRYPT_MODE, key, GCMParameterSpec(TAG_BYTES * 8, envelope.nonce))
            updateAAD(VERSION.toByteArray(Charsets.UTF_8))
            doFinal(envelope.sealed)
        }
    } catch (_: AEADBadTagException) {
        throw AuthenticationFailedException()
    } catch (_: java.security.GeneralSecurityException) {
        throw AuthenticationFailedException()
    }

    /**
     * 文本 → 导入结果。明文 v1/v2 行为不变；加密备份缺口令时抛 [PassphraseRequiredException]，
     * 口令错误抛 [AuthenticationFailedException]（可直接重试）。解出的明文只按 v2 解析，不递归解密。
     */
    fun parseText(text: String, recovery: Boolean, passphrase: String?): Backup.ImportResult {
        val parse: (String) -> Backup.ImportResult = if (recovery) Backup::parseRecovery else Backup::parseStrict
        // 每个字符至少 1 字节：长度超过 50 MiB 的文本不可能是明文备份；信封是纯 ASCII
        if (text.length > Backup.MAX_FILE_BYTES) {
            if (!isEnvelope(text)) throw Backup.BackupFormatException(tr("文件超过 50 MiB"))
        } else {
            try {
                return parse(text)
            } catch (_: PassphraseRequiredException) {
                // 加密信封：继续走解密
            }
        }
        if (passphrase == null) throw PassphraseRequiredException()
        val plaintext = decrypt(text, passphrase)
        return try {
            parse(plaintext)
        } catch (_: PassphraseRequiredException) {
            throw Backup.BackupFormatException(tr("/version：加密备份里不能再嵌套加密备份"))
        }
    }

    // ---- 加密 ----

    private val random = SecureRandom()

    /** 加密一份已通过正式导出校验的 v2 文本；随后用同一密钥解密自检。 */
    fun encrypt(plaintext: String, passphrase: String): String {
        exportPassphraseProblem(passphrase)?.let { throw Backup.BackupFormatException(it) }
        val salt = ByteArray(SALT_BYTES).also(random::nextBytes)
        val nonce = ByteArray(NONCE_BYTES).also(random::nextBytes)
        return encrypt(plaintext, passphrase, salt, nonce, EXPORT_ITERATIONS)
    }

    /** 测试注入 salt / nonce / 迭代数；正式导出一律随机生成并用 600,000 次。 */
    internal fun encrypt(plaintext: String, passphrase: String, salt: ByteArray, nonce: ByteArray, iterations: Int): String {
        val bytes = plaintext.toByteArray(Charsets.UTF_8)
        if (bytes.size > Backup.MAX_FILE_BYTES) throw Backup.BackupFormatException(tr("文件超过 50 MiB"))
        val key = deriveKey(passphrase, salt, iterations)
        val sealed = Cipher.getInstance("AES/GCM/NoPadding").run {
            init(Cipher.ENCRYPT_MODE, key, GCMParameterSpec(TAG_BYTES * 8, nonce))
            updateAAD(VERSION.toByteArray(Charsets.UTF_8))
            doFinal(bytes) // 密文 || 16 字节标签
        }
        val check = open(Envelope(iterations, salt, nonce, sealed), key)
        val matches = check.contentEquals(bytes)
        Arrays.fill(check, 0)
        if (!matches) throw AuthenticationFailedException()
        val encoder = Base64.getEncoder()
        // 与参考实现相同的键序与缩进，方便人工核对；读取端不依赖排版
        return buildString {
            append("{\n")
            append("  \"version\": \"").append(VERSION).append("\",\n")
            append("  \"kdf\": {\n")
            append("    \"name\": \"").append(KDF_NAME).append("\",\n")
            append("    \"iterations\": ").append(iterations).append(",\n")
            append("    \"salt\": \"").append(encoder.encodeToString(salt)).append("\"\n")
            append("  },\n")
            append("  \"cipher\": {\n")
            append("    \"name\": \"").append(CIPHER_NAME).append("\",\n")
            append("    \"nonce\": \"").append(encoder.encodeToString(nonce)).append("\"\n")
            append("  },\n")
            append("  \"ciphertext\": \"").append(encoder.encodeToString(sealed)).append("\"\n")
            append("}\n")
        }
    }

    // ---- 工具 ----

    private fun JSONObject.exactKeys(vararg keys: String) {
        val actual = keys().asSequence().toSet()
        if (actual != keys.toSet()) throw InvalidEnvelopeException()
    }

    /** 整数值：允许 1.0，拒绝布尔、字符串与小数 */
    private fun integer(value: Any?): Int? {
        if (value !is Number) return null
        val d = value.toDouble()
        return d.takeIf { it.isFinite() && it % 1.0 == 0.0 && it >= Int.MIN_VALUE && it <= Int.MAX_VALUE }?.toInt()
    }

    /** RFC 4648 §4 规范编码：解码后再编码必须与原文一致（拒绝空白、缺填充、非零尾位） */
    private fun canonicalBase64(value: Any?): ByteArray {
        val text = value as? String ?: throw InvalidEnvelopeException()
        val bytes = try { Base64.getDecoder().decode(text) } catch (_: IllegalArgumentException) {
            throw InvalidEnvelopeException()
        }
        if (Base64.getEncoder().encodeToString(bytes) != text) throw InvalidEnvelopeException()
        return bytes
    }
}
