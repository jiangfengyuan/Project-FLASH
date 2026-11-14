// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import CommonCrypto
import CryptoKit
import Security

/// 口令加密备份信封 `flash-backup-enc-v1`（docs/contracts/flash-backup-enc-v1.md）。
///
/// 明文是一份完整 flash-backup-v2 正式导出的 UTF-8 字节；信封只负责加解密，
/// 解出的明文仍交给 `BackupService.parseStrict / parseRecovery`。
/// 只用系统 API：CommonCrypto PBKDF2（CryptoKit 没有 PBKDF2）+ CryptoKit AES-GCM。
public enum BackupEncryption: Sendable {
    public static let version = "flash-backup-enc-v1"
    public static let versionPrefix = "flash-backup-enc-"
    static let kdfName = "PBKDF2-HMAC-SHA256"
    static let cipherName = "AES-256-GCM"
    public static let exportIterations = 600_000
    static let iterationRange = 100_000...10_000_000
    static let saltBytes = 16
    static let nonceBytes = 12
    static let tagBytes = 16
    /// 50 MiB 明文 + 标签的 Base64 长度
    static let maxCiphertextBase64 = 4 * ((BackupService.maxFileBytes + 16 + 2) / 3)
    /// 加密文件上限：50 MiB 明文 Base64 后约 66.7 MiB，另留信封头余量
    public static let maxEnvelopeBytes = 72 * 1024 * 1024
    public static let minimumPassphraseLength = 8
    public static let maximumPassphraseLength = 1024

    /// 已通过 §2 校验的信封
    struct Envelope: Sendable {
        let iterations: Int
        let salt: Data
        let nonce: Data
        let sealed: Data
    }

    // MARK: - 口令

    /// 导出时检查口令长度（NFC 后按 Unicode 标量计）；导入接受任何非空口令。
    public static func validateExportPassphrase(_ passphrase: String) throws {
        let count = passphrase.precomposedStringWithCanonicalMapping.unicodeScalars.count
        if count < minimumPassphraseLength { throw BackupError.passphraseTooShort }
        if count > maximumPassphraseLength { throw BackupError.passphraseTooLong }
    }

    static func deriveKey(passphrase: String, salt: Data, iterations: Int) throws -> SymmetricKey {
        let password = Array(passphrase.precomposedStringWithCanonicalMapping.utf8)
        var key = [UInt8](repeating: 0, count: 32)
        defer { key.withUnsafeMutableBytes { memset_s($0.baseAddress, $0.count, 0, $0.count) } }
        let status = password.withUnsafeBufferPointer { passwordBuffer in
            salt.withUnsafeBytes { saltBuffer in
                CCKeyDerivationPBKDF(CCPBKDFAlgorithm(kCCPBKDF2),
                                     passwordBuffer.baseAddress.map { UnsafeRawPointer($0).assumingMemoryBound(to: CChar.self) },
                                     passwordBuffer.count,
                                     saltBuffer.bindMemory(to: UInt8.self).baseAddress, saltBuffer.count,
                                     CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256), UInt32(iterations),
                                     &key, key.count)
            }
        }
        guard status == kCCSuccess else { throw BackupError.encryptedInvalid }
        return SymmetricKey(data: key)
    }

    // MARK: - 解密

    /// 文本是否声明了任意加密信封版本（用于 >50 MiB 的文件：明文备份不可能这么大）
    public static func isEnvelope(_ json: String) -> Bool {
        guard let root = try? JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any],
              let version = root["version"] as? String else { return false }
        return version.hasPrefix(versionPrefix)
    }

    /// 按契约顺序校验信封：先版本，再字段集合，KDF / 算法名先于其余字段判断「不支持」。
    static func parseEnvelope(_ json: String) throws -> Envelope {
        guard json.utf8.count <= maxEnvelopeBytes else { throw BackupError.fileTooLarge }
        guard !json.hasPrefix("\u{FEFF}") else { throw BackupError.invalidJSON }
        try BackupService.strictScan(json)
        guard let root = try? JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any] else {
            throw BackupError.invalidJSON
        }
        guard let version = root["version"] as? String, version.hasPrefix(versionPrefix) else {
            throw BackupError.encryptedInvalid
        }
        guard version == self.version else { throw BackupError.encryptedUnsupported }
        try exactKeys(root, ["version", "kdf", "cipher", "ciphertext"])

        guard let kdf = root["kdf"] as? [String: Any], let kdfName = kdf["name"] as? String else {
            throw BackupError.encryptedInvalid
        }
        guard kdfName == self.kdfName else { throw BackupError.encryptedUnsupported }
        try exactKeys(kdf, ["name", "iterations", "salt"])
        guard let iterations = BackupService.integerValue(kdf["iterations"]), iterationRange.contains(iterations) else {
            throw BackupError.encryptedInvalid
        }
        let salt = try canonicalBase64(kdf["salt"])
        guard salt.count == saltBytes else { throw BackupError.encryptedInvalid }

        guard let cipher = root["cipher"] as? [String: Any], let cipherName = cipher["name"] as? String else {
            throw BackupError.encryptedInvalid
        }
        guard cipherName == self.cipherName else { throw BackupError.encryptedUnsupported }
        try exactKeys(cipher, ["name", "nonce"])
        let nonce = try canonicalBase64(cipher["nonce"])
        guard nonce.count == nonceBytes else { throw BackupError.encryptedInvalid }

        guard let ciphertext = root["ciphertext"] as? String, ciphertext.utf8.count <= maxCiphertextBase64 else {
            throw BackupError.encryptedInvalid
        }
        let sealed = try canonicalBase64(ciphertext)
        guard sealed.count >= tagBytes else { throw BackupError.encryptedInvalid }
        return Envelope(iterations: iterations, salt: salt, nonce: nonce, sealed: sealed)
    }

    /// 校验信封、派生密钥并解密，返回内层 flash-backup-v2 文本（尚未校验）。
    public static func decrypt(_ json: String, passphrase: String) throws -> String {
        let envelope = try parseEnvelope(json)
        let key = try deriveKey(passphrase: passphrase, salt: envelope.salt, iterations: envelope.iterations)
        let plaintext = try open(envelope, key: key)
        // 明文仍须满足文件层规则：UTF-8、无 BOM（大小已由密文上限保证 ≤ 50 MiB + 0）
        guard plaintext.count <= BackupService.maxFileBytes else { throw BackupError.fileTooLarge }
        guard let text = String(data: plaintext, encoding: .utf8), !text.hasPrefix("\u{FEFF}") else {
            throw BackupError.invalidJSON
        }
        return text
    }

    private static func open(_ envelope: Envelope, key: SymmetricKey) throws -> Data {
        do {
            let body = envelope.sealed.prefix(envelope.sealed.count - tagBytes)
            let tag = envelope.sealed.suffix(tagBytes)
            let box = try AES.GCM.SealedBox(nonce: AES.GCM.Nonce(data: envelope.nonce), ciphertext: body, tag: tag)
            return try AES.GCM.open(box, using: key, authenticating: Data(version.utf8))
        } catch {
            throw BackupError.encryptedAuthenticationFailed
        }
    }

    // MARK: - 加密

    /// 加密一份已通过正式导出校验的 v2 文本；随后立即用同一密钥解密自检。
    /// `salt` / `nonce` / `iterations` 仅供测试注入，正式导出一律随机生成并用 600,000 次。
    public static func encrypt(_ plaintext: String, passphrase: String) throws -> String {
        try validateExportPassphrase(passphrase)
        return try encrypt(plaintext, passphrase: passphrase,
                           salt: randomBytes(saltBytes), nonce: randomBytes(nonceBytes),
                           iterations: exportIterations)
    }

    static func encrypt(_ plaintext: String, passphrase: String, salt: Data, nonce: Data,
                        iterations: Int) throws -> String {
        let bytes = Data(plaintext.utf8)
        guard bytes.count <= BackupService.maxFileBytes else { throw BackupError.fileTooLarge }
        let key = try deriveKey(passphrase: passphrase, salt: salt, iterations: iterations)
        let box = try AES.GCM.seal(bytes, using: key, nonce: AES.GCM.Nonce(data: nonce),
                                   authenticating: Data(version.utf8))
        let envelope = Envelope(iterations: iterations, salt: salt, nonce: nonce, sealed: box.ciphertext + box.tag)
        guard try open(envelope, key: key) == bytes else { throw BackupError.encryptedAuthenticationFailed }
        // 与参考实现相同的键序与缩进，方便人工核对；读取端不依赖排版
        return """
        {
          "version": "\(version)",
          "kdf": {
            "name": "\(kdfName)",
            "iterations": \(iterations),
            "salt": "\(salt.base64EncodedString())"
          },
          "cipher": {
            "name": "\(cipherName)",
            "nonce": "\(nonce.base64EncodedString())"
          },
          "ciphertext": "\(envelope.sealed.base64EncodedString())"
        }

        """
    }

    // MARK: - 工具

    private static func exactKeys(_ object: [String: Any], _ keys: Set<String>) throws {
        guard Set(object.keys) == keys else { throw BackupError.encryptedInvalid }
    }

    /// RFC 4648 §4 规范编码：解码后再编码必须与原文一致（拒绝空白、缺填充、非零尾位）
    private static func canonicalBase64(_ value: Any?) throws -> Data {
        guard let text = value as? String, let data = Data(base64Encoded: text),
              data.base64EncodedString() == text else { throw BackupError.encryptedInvalid }
        return data
    }

    private static func randomBytes(_ count: Int) throws -> Data {
        var bytes = [UInt8](repeating: 0, count: count)
        guard SecRandomCopyBytes(kSecRandomDefault, count, &bytes) == errSecSuccess else {
            throw BackupError.encryptedInvalid
        }
        return Data(bytes)
    }
}
