import Foundation
import Testing
@testable import FlashCore

/// flash-backup-enc-v1：共用加密样例（docs/contracts/fixtures/encrypted/cases.json）与往返测试
@Suite("Backup encryption")
struct BackupEncryptionTests {
    private static let fixtures = URL(fileURLWithPath: #filePath)
        // app/shared/FlashKit/Tests/FlashCoreTests/<file> → app/
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("docs/contracts/fixtures")

    private struct Manifest: Decodable {
        struct Case: Decodable {
            let file: String
            let expect: String
            let passphrase: String?
            let plaintext: String?
            let innerValid: Bool?
        }
        let passphrase: String
        let cases: [Case]
    }

    private static func text(_ relative: String) throws -> String {
        try String(contentsOf: fixtures.appendingPathComponent(relative), encoding: .utf8)
    }

    private static func manifest() throws -> Manifest {
        try JSONDecoder().decode(Manifest.self, from: Data(text("encrypted/cases.json").utf8))
    }

    private static func category(_ error: Error) -> String {
        switch error as? BackupError {
        case .encryptedInvalid: "invalidEnvelope"
        case .encryptedUnsupported: "unsupported"
        case .encryptedAuthenticationFailed: "authenticationFailed"
        // 通用 JSON 层：语法错误或重复键（重复键在严格扫描中报为契约路径）
        case .invalidJSON, .contract: "invalidJSON"
        default: "other: \(error)"
        }
    }

    @Test func sharedEncryptedCorpus() throws {
        let manifest = try Self.manifest()
        #expect(manifest.cases.count >= 30)
        for item in manifest.cases {
            let envelope = try Self.text("encrypted/\(item.file)")
            let passphrase = item.passphrase ?? manifest.passphrase
            if item.expect == "ok" {
                let plaintext = try BackupEncryption.decrypt(envelope, passphrase: passphrase)
                #expect(plaintext == (try Self.text(try #require(item.plaintext))), "\(item.file)")
                let innerValid = (try? BackupService.parseStrict(plaintext)) != nil
                #expect(innerValid == item.innerValid, "\(item.file)")
            } else {
                do {
                    _ = try BackupEncryption.decrypt(envelope, passphrase: passphrase)
                    Issue.record("\(item.file) decrypted but expected \(item.expect)")
                } catch {
                    #expect(Self.category(error) == item.expect, "\(item.file)")
                }
            }
        }
    }

    @Test func plaintextImportersSignalEncryptedFiles() throws {
        let envelope = try Self.text("encrypted/valid-enc-full.json")
        #expect(throws: BackupError.encrypted) { _ = try BackupService.parseStrict(envelope) }
        #expect(throws: BackupError.encrypted) { _ = try BackupService.parseRecovery(envelope) }
        // 未来版本也先被识别为加密文件，再由信封层报「需要更新」
        let future = try Self.text("encrypted/enc-unknown-version.json")
        #expect(throws: BackupError.encrypted) { _ = try BackupService.parseStrict(future) }
        #expect(throws: BackupError.encryptedUnsupported) { _ = try BackupEncryption.decrypt(future, passphrase: "x") }
    }

    @Test func roundTripUsesFreshSaltNonceAndExportIterations() throws {
        let plaintext = try Self.text("valid-full.json")
        let a = try BackupEncryption.encrypt(plaintext, passphrase: "correct horse")
        let b = try BackupEncryption.encrypt(plaintext, passphrase: "correct horse")
        let rootA = try #require(JSONSerialization.jsonObject(with: Data(a.utf8)) as? [String: Any])
        let rootB = try #require(JSONSerialization.jsonObject(with: Data(b.utf8)) as? [String: Any])
        let kdfA = try #require(rootA["kdf"] as? [String: Any])
        #expect(kdfA["iterations"] as? Int == BackupEncryption.exportIterations)
        #expect((kdfA["salt"] as? String) != ((rootB["kdf"] as? [String: Any])?["salt"] as? String))
        #expect(((rootA["cipher"] as? [String: Any])?["nonce"] as? String) != ((rootB["cipher"] as? [String: Any])?["nonce"] as? String))
        #expect(try BackupEncryption.decrypt(a, passphrase: "correct horse") == plaintext)
        #expect(throws: BackupError.encryptedAuthenticationFailed) { _ = try BackupEncryption.decrypt(a, passphrase: "correct horsE") }
    }

    /// 注入同一 salt/nonce/迭代数时，Swift 输出与 Node 参考实现生成的样例逐字节相同
    @Test func deterministicEncryptionMatchesReferenceFixture() throws {
        let manifest = try Self.manifest()
        let fixture = try Self.text("encrypted/valid-enc-minimal.json")
        let root = try #require(JSONSerialization.jsonObject(with: Data(fixture.utf8)) as? [String: Any])
        let kdf = try #require(root["kdf"] as? [String: Any])
        let cipher = try #require(root["cipher"] as? [String: Any])
        let produced = try BackupEncryption.encrypt(try Self.text("valid-minimal.json"), passphrase: manifest.passphrase,
                                                    salt: try #require(Data(base64Encoded: kdf["salt"] as! String)),
                                                    nonce: try #require(Data(base64Encoded: cipher["nonce"] as! String)),
                                                    iterations: kdf["iterations"] as! Int)
        #expect(produced == fixture)
    }

    @Test func exportPassphraseRules() throws {
        #expect(throws: BackupError.passphraseTooShort) { try BackupEncryption.validateExportPassphrase("1234567") }
        try BackupEncryption.validateExportPassphrase("12345678")
        // 7 个 emoji = 14 个 UTF-16 单元，仍算 7 个字符
        #expect(throws: BackupError.passphraseTooShort) { try BackupEncryption.validateExportPassphrase(String(repeating: "😀", count: 7)) }
        // NFD「e + 组合重音」规范化后只算 1 个字符
        #expect(throws: BackupError.passphraseTooShort) { try BackupEncryption.validateExportPassphrase("cafe\u{301} 12") }
        #expect(throws: BackupError.passphraseTooLong) { try BackupEncryption.validateExportPassphrase(String(repeating: "x", count: 1025)) }
        #expect(throws: BackupError.passphraseTooShort) { _ = try BackupEncryption.encrypt("{}", passphrase: "short") }
    }

    @Test func limitsMatchContract() {
        #expect(BackupEncryption.maxCiphertextBase64 == 69_905_088)
        #expect(BackupEncryption.maxEnvelopeBytes == 75_497_472)
    }

    // MARK: - Coordinator

    @Test func coordinatorExportsEncryptedOrUnchangedPlaintext() async throws {
        let full = try BackupService.parse(try Self.text("valid-full.json"))
        let snapshot = FlashSnapshot(logs: full.logs, emotions: full.emotions, tasks: full.tasks)
        let plain = try await BackupImportCoordinator.exportJSON(snapshot: snapshot, appVersion: "test")
        #expect(throws: Never.self) { _ = try BackupService.parseStrict(plain) }
        let sealed = try await BackupImportCoordinator.exportJSON(snapshot: snapshot, appVersion: "test",
                                                                  passphrase: "correct horse")
        #expect(throws: BackupError.encrypted) { _ = try BackupService.parseStrict(sealed) }
        let opened = try BackupEncryption.decrypt(sealed, passphrase: "correct horse")
        let reparsed = try BackupService.parseStrict(opened)
        #expect(reparsed.logs == full.logs && reparsed.emotions == full.emotions && reparsed.tasks == full.tasks)
        await #expect(throws: BackupError.passphraseTooShort) {
            _ = try await BackupImportCoordinator.exportJSON(snapshot: snapshot, appVersion: "test", passphrase: "short")
        }
        #expect(BackupImportCoordinator.exportFileName(encrypted: true).hasSuffix("-encrypted.json"))
        #expect(!BackupImportCoordinator.exportFileName(encrypted: false).contains("encrypted"))
    }

    @Test func coordinatorPreviewAsksForPassphraseThenDecrypts() async throws {
        let manifest = try Self.manifest()
        let empty = FlashSnapshot(logs: [], emotions: [], tasks: [])
        let envelope = try Self.text("encrypted/valid-enc-full.json")
        await #expect(throws: BackupError.encrypted) {
            _ = try await BackupImportCoordinator.preview(text: envelope, recovery: false, passphrase: nil, against: empty)
        }
        await #expect(throws: BackupError.encryptedAuthenticationFailed) {
            _ = try await BackupImportCoordinator.preview(text: envelope, recovery: false, passphrase: "wrong", against: empty)
        }
        let preview = try await BackupImportCoordinator.preview(text: envelope, recovery: false,
                                                                passphrase: manifest.passphrase, against: empty)
        let expected = try BackupService.parseStrict(try Self.text("valid-full.json"))
        #expect(preview.logs == expected.logs && preview.tasks == expected.tasks)
        #expect(preview.difference != nil)
    }

    @Test func coordinatorInnerRulesStillApply() async throws {
        let manifest = try Self.manifest()
        let empty = FlashSnapshot(logs: [], emotions: [], tasks: [])
        let inner = try Self.text("encrypted/enc-inner-invalid.json")
        await #expect(throws: BackupError.self) {
            _ = try await BackupImportCoordinator.preview(text: inner, recovery: false, passphrase: manifest.passphrase, against: empty)
        }
        // 恢复入口：信封必须完整，跳过坏记录只作用于解出的内容
        let recovered = try await BackupImportCoordinator.preview(text: inner, recovery: true,
                                                                  passphrase: manifest.passphrase, against: empty)
        #expect(recovered.skippedLogs == 1)
        // 嵌套信封不递归解密
        let nested = try Self.text("encrypted/enc-inner-envelope.json")
        await #expect(throws: BackupError.contract("/version")) {
            _ = try await BackupImportCoordinator.preview(text: nested, recovery: false, passphrase: manifest.passphrase, against: empty)
        }
    }

    @Test func coordinatorPlaintextPathUnchanged() async throws {
        let empty = FlashSnapshot(logs: [], emotions: [], tasks: [])
        let preview = try await BackupImportCoordinator.preview(text: try Self.text("valid-full.json"), recovery: false,
                                                                passphrase: "ignored for plaintext", against: empty)
        #expect(preview.sourceVersion == BackupService.backupVersion)
        // 超过 50 MB 的非信封文本仍是「文件过大」
        let oversized = "{\"version\":\"flash-backup-v2\",\"notes\":\"" + String(repeating: "a", count: BackupService.maxFileBytes) + "\"}"
        await #expect(throws: BackupError.fileTooLarge) {
            _ = try await BackupImportCoordinator.preview(text: oversized, recovery: false, passphrase: nil, against: empty)
        }
    }

    @Test func shareFileNameMarksEncryptedCopies() throws {
        let base = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: base) }
        let url = try BackupTransfer.createShareFile(json: "{}", encrypted: true, baseDirectory: base)
        #expect(url.lastPathComponent.hasSuffix("-encrypted.json"))
    }
}
