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

        let second = try BackupTransfer.createShareFile(json: "{\"second\":true}", baseDirectory: root)
        #expect(!FileManager.default.fileExists(atPath: first.path))
        #expect(try String(contentsOf: second, encoding: .utf8) == "{\"second\":true}")
    }
}
