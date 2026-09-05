// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import Testing
@testable import Flash

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

    private enum InjectedExportError: Error {
        case failed
    }
}
