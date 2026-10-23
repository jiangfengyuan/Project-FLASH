// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Testing
import Foundation
@testable import FlashCore

@Suite("WidgetSnapshot")
struct WidgetSnapshotTests {
    private func makeDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("widget-snapshot-test-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func sample() -> WidgetSnapshot {
        WidgetSnapshot(recordDate: "2026-10-06", todayLogCount: 3, openTaskCount: 2,
                       dominantEmotionEmoji: "😊", generatedAt: "2026-10-06T01:02:03.000Z")
    }

    @Test func codableRoundtrip() throws {
        let snapshot = sample()
        let data = try JSONEncoder().encode(snapshot)
        let decoded = try JSONDecoder().decode(WidgetSnapshot.self, from: data)
        #expect(decoded == snapshot)
    }

    @Test func codableRoundtripWithoutEmotion() throws {
        var snapshot = sample()
        snapshot.dominantEmotionEmoji = nil
        let data = try JSONEncoder().encode(snapshot)
        let decoded = try JSONDecoder().decode(WidgetSnapshot.self, from: data)
        #expect(decoded == snapshot)
        #expect(decoded.dominantEmotionEmoji == nil)
    }

    @Test func writeReadRoundtrip() throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        try WidgetSnapshotWriter.write(sample(), to: directory)
        #expect(WidgetSnapshotReader.read(from: directory) == sample())
    }

    @Test func readMissingFileReturnsNil() throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        #expect(WidgetSnapshotReader.read(from: directory) == nil)
    }

    @Test func readCorruptedJSONReturnsNil() throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        try Data("not-json".utf8).write(to: WidgetSnapshotStore.fileURL(in: directory))
        #expect(WidgetSnapshotReader.read(from: directory) == nil)
    }

    /// 组不可用时写入端必须静默 no-op、不抛错不崩溃；读取端回退 nil。
    /// 注意 containerURL 是否返回 nil 取决于运行环境：沙盒化主 App（adhoc）下为 nil，
    /// 但全量测试的并行 runner（非沙盒进程）会返回
    /// ~/Library/Group Containers/<group> 路径。两种路径都要安全。
    @Test func groupContainerProbeIsSafeEitherWay() throws {
        guard let directory = WidgetSnapshotStore.containerDirectory else {
            WidgetSnapshotWriter.write(sample())
            #expect(WidgetSnapshotReader.read() == nil)
            return
        }
        let fileURL = WidgetSnapshotStore.fileURL(in: directory)
        // 探测容器是否真实可写：并行 runner 返回 URL 但沙盒仍拒绝 IO，
        // 此时写入端同样必须静默 no-op
        let probeURL = directory.appendingPathComponent(".probe-\(UUID().uuidString)")
        let writable: Bool
        do {
            try Data("probe".utf8).write(to: probeURL)
            try FileManager.default.removeItem(at: probeURL)
            writable = true
        } catch {
            writable = false
        }
        guard writable else {
            WidgetSnapshotWriter.write(sample())
            #expect(WidgetSnapshotReader.read() == nil)
            return
        }
        let hadFile = FileManager.default.fileExists(atPath: fileURL.path)
        let backup = try? Data(contentsOf: fileURL)
        defer {
            if hadFile, let backup { try? backup.write(to: fileURL, options: .atomic) }
            else { try? FileManager.default.removeItem(at: fileURL) }
        }
        WidgetSnapshotWriter.write(sample())
        #expect(WidgetSnapshotReader.read() == sample())
    }

    /// 旧快照（无 unreadIdeaCount 字段，macOS 与 iOS 早期版本写入）仍可解码
    @Test func decodesLegacySnapshotWithoutUnreadCount() throws {
        let legacy = #"{"generatedAt":"2026-10-23T08:00:00.000Z","openTaskCount":2,"recordDate":"2026-10-23","todayLogCount":5}"#
        let snapshot = try JSONDecoder().decode(WidgetSnapshot.self, from: Data(legacy.utf8))
        #expect(snapshot.unreadIdeaCount == nil)
        #expect(snapshot.todayLogCount == 5)
        #expect(snapshot.isCurrent(today: "2026-10-23"))
        #expect(!snapshot.isCurrent(today: "2026-10-24"))
    }

    @Test func unreadCountRoundtrips() throws {
        var snapshot = sample()
        snapshot.unreadIdeaCount = 4
        let data = try JSONEncoder().encode(snapshot)
        #expect(try JSONDecoder().decode(WidgetSnapshot.self, from: data).unreadIdeaCount == 4)
    }
}
