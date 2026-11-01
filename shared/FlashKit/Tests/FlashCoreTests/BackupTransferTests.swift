// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import Testing
@testable import FlashCore

@Suite("BackupTransfer")
struct BackupTransferTests {
    @Test func createsJSONShareFileAndRemovesStaleCopy() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("flash-transfer-test-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let first = try BackupTransfer.createShareFile(json: "{\"first\":true}", baseDirectory: root)
        #expect(first.pathExtension == "json")
        #expect(try String(contentsOf: first, encoding: .utf8) == "{\"first\":true}")
        try FileManager.default.setAttributes(
            [.modificationDate: Date().addingTimeInterval(-25 * 60 * 60)],
            ofItemAtPath: first.path)

        try BackupTransfer.cleanupExpired(in: root)
        #expect(!FileManager.default.fileExists(atPath: first.path))

        let second = try BackupTransfer.createShareFile(json: "{\"second\":true}", baseDirectory: root)
        #expect(try String(contentsOf: second, encoding: .utf8) == "{\"second\":true}")
    }

    @Test func failedFinalSwapPreservesOldBackupAndCleansPlaintextTemp() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("flash-export-test-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let destination = root.appendingPathComponent("backup.json")
        try "old-valid-backup".write(to: destination, atomically: true, encoding: .utf8)

        #expect(throws: InjectedExportError.self) {
            try BackupTransfer.writeExportFile(json: "sensitive-new-backup", to: destination) { _, _ in
                throw InjectedExportError.failed
            }
        }

        #expect(try String(contentsOf: destination, encoding: .utf8) == "old-valid-backup")
        let leftovers = try FileManager.default.contentsOfDirectory(atPath: root.path)
            .filter { $0.hasPrefix(".flash-backup-") && $0.hasSuffix(".tmp") }
        #expect(leftovers.isEmpty)
    }

    @Test func successfulExportAtomicallyReplacesExistingBackup() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("flash-export-test-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let destination = root.appendingPathComponent("backup.json")
        try "old".write(to: destination, atomically: true, encoding: .utf8)

        try BackupTransfer.writeExportFile(json: "new", to: destination)

        #expect(try String(contentsOf: destination, encoding: .utf8) == "new")
        #expect(try FileManager.default.contentsOfDirectory(atPath: root.path)
            .allSatisfy { !$0.hasPrefix(".flash-backup-") || !$0.hasSuffix(".tmp") })
    }

    @Test func exportedFileIsTightenedToOwnerOnlyPermissions() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("flash-export-test-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let destination = root.appendingPathComponent("backup.json")

        try BackupTransfer.writeExportFile(json: "sensitive-plaintext", to: destination)

        // 本地卷 chmod 必须生效：明文备份不允许以宽松权限落盘
        let attributes = try FileManager.default.attributesOfItem(atPath: destination.path)
        let permissions = try #require(attributes[.posixPermissions] as? Int)
        #expect(permissions == 0o600)
    }

    @Test func replacingReadableDestinationDoesNotRestoreItsOldPermissions() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("flash-export-mode-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let destination = root.appendingPathComponent("backup.json")
        try "old".write(to: destination, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: destination.path)
        try BackupTransfer.writeExportFile(json: "private-new-backup", to: destination)
        let mode = try FileManager.default.attributesOfItem(atPath: destination.path)[.posixPermissions] as? Int
        #expect(mode == 0o600)
        #expect(try String(contentsOf: destination, encoding: .utf8) == "private-new-backup")
    }

    private enum InjectedExportError: Error {
        case failed
    }

    @Test func stagingModeIsPrivateBeforeWritingAndPartialFailureIsCleaned() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("flash-stage-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let file = root.appendingPathComponent("partial.json")
        #expect(throws: InjectedExportError.self) {
            try BackupTransfer.writePrivateFile(Data("synthetic-private".utf8), to: file) { handle, data in
                let mode = try FileManager.default.attributesOfItem(atPath: file.path)[.posixPermissions] as? Int
                #expect(mode == 0o600)
                try handle.write(contentsOf: data.prefix(4))
                throw InjectedExportError.failed
            }
        }
        #expect(!FileManager.default.fileExists(atPath: file.path))
    }

    @Test func privateWriterDoesNotFollowOrRemovePreexistingSymlink() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("flash-link-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let target = root.appendingPathComponent("untouched.json")
        let link = root.appendingPathComponent("link.json")
        try "original".write(to: target, atomically: true, encoding: .utf8)
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: target)
        #expect(throws: (any Error).self) { try BackupTransfer.writePrivateFile(Data("private".utf8), to: link) }
        #expect(try String(contentsOf: target, encoding: .utf8) == "original")
        #expect(try FileManager.default.destinationOfSymbolicLink(atPath: link.path) == target.path)
    }
}
