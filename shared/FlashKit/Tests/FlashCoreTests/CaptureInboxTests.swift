// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import SwiftData
import Testing
@testable import FlashCore

@MainActor
@Suite("CaptureInbox 分享收件箱")
struct CaptureInboxTests {
    /// 独立随机目录，避免碰到真实 App Group 容器
    private struct Fixture {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent(CaptureInboxStore.directoryName)

        func makeStore() -> CaptureInboxStore { CaptureInboxStore(directory: directory) }

        func cleanUp() { try? FileManager.default.removeItem(at: directory.deletingLastPathComponent()) }
    }

    private func makeRepository(temporary: Bool = false) -> FlashRepository {
        FlashRepository(container: FlashDatabase.makeContainer(inMemory: true), isTemporaryStore: temporary)
    }

    // MARK: - compose

    @Test func composeAppendsLinkOnNewLine() {
        let url = URL(string: "https://example.com/a")!
        #expect(CaptureInboxEntry.compose(text: " 好文章 ", url: url) == "好文章\nhttps://example.com/a")
        #expect(CaptureInboxEntry.compose(text: nil, url: url) == "https://example.com/a")
        #expect(CaptureInboxEntry.compose(text: "看 https://example.com/a", url: url) == "看 https://example.com/a")
        #expect(CaptureInboxEntry.compose(text: "只有文字", url: nil) == "只有文字")
    }

    // MARK: - store

    @Test func enqueueThenPendingInCreationOrder() throws {
        let fixture = Fixture()
        defer { fixture.cleanUp() }
        let store = fixture.makeStore()
        try store.enqueue(CaptureInboxEntry(id: "b", text: "后", category: .log, createdAt: "2026-10-31T10:00:01.000Z"))
        try store.enqueue(CaptureInboxEntry(id: "a", text: "先", category: .idea, createdAt: "2026-10-31T10:00:00.000Z"))
        #expect(store.pending().map(\.id) == ["a", "b"])
        store.remove(id: "a")
        #expect(store.pending().map(\.id) == ["b"])
    }

    @Test func entriesAndDirectoryAreExcludedFromBackup() throws {
        let fixture = Fixture()
        defer { fixture.cleanUp() }
        let store = fixture.makeStore()
        try store.enqueue(CaptureInboxEntry(id: "x", text: "私人正文", category: .idea))
        let fileValues = try store.fileURL(for: "x").resourceValues(forKeys: [.isExcludedFromBackupKey])
        #expect(fileValues.isExcludedFromBackup == true)
        let directoryValues = try fixture.directory.resourceValues(forKeys: [.isExcludedFromBackupKey])
        #expect(directoryValues.isExcludedFromBackup == true)
    }

    @Test func enqueueRefusesPastCap() throws {
        let fixture = Fixture()
        defer { fixture.cleanUp() }
        let store = fixture.makeStore()
        for index in 0..<CaptureInboxStore.maxPending {
            try store.enqueue(CaptureInboxEntry(id: "e\(index)", text: "\(index)", category: .log))
        }
        #expect(throws: CaptureInboxError.full) {
            try store.enqueue(CaptureInboxEntry(text: "多一条", category: .log))
        }
    }

    @Test func malformedFileIsDroppedNotRetried() throws {
        let fixture = Fixture()
        defer { fixture.cleanUp() }
        let store = fixture.makeStore()
        try store.enqueue(CaptureInboxEntry(id: "ok", text: "正常", category: .log))
        let bad = fixture.directory.appendingPathComponent("bad.json")
        try Data("not json".utf8).write(to: bad)
        #expect(store.pending().map(\.id) == ["ok"])
        #expect(!FileManager.default.fileExists(atPath: bad.path))
    }

    // MARK: - importer

    @Test func drainCommitsThroughQuickCaptureRulesAndDeletesFiles() throws {
        let fixture = Fixture()
        defer { fixture.cleanUp() }
        let store = fixture.makeStore()
        let repository = makeRepository()
        try store.enqueue(CaptureInboxEntry(id: "i1", text: "做一个分享扩展!!", category: .idea))
        try store.enqueue(CaptureInboxEntry(id: "l1", text: "读完一篇文章", category: .log))
        #expect(CaptureInboxImporter.drain(store, into: repository) == 2)
        let logs = try repository.allLogs()
        let idea = try #require(logs.first { $0.id == "i1" })
        #expect(idea.category == .idea && idea.colorTag == .idea && idea.importance == 2)
        let log = try #require(logs.first { $0.id == "l1" })
        #expect(log.category == .log && log.colorTag == .daily)
        #expect(store.pending().isEmpty)
    }

    @Test func drainIsIdempotentAfterInterruptedDelete() throws {
        let fixture = Fixture()
        defer { fixture.cleanUp() }
        let store = fixture.makeStore()
        let repository = makeRepository()
        // 模拟上次写库成功后、删文件前被杀：库里已有同 id 记录，文件仍在
        try QuickCaptureCommit.commit("已收入", as: .log, id: "dup", repository: repository)
        try store.enqueue(CaptureInboxEntry(id: "dup", text: "已收入", category: .log))
        #expect(CaptureInboxImporter.drain(store, into: repository) == 0)
        #expect(try repository.allLogs().count == 1)
        #expect(store.pending().isEmpty)
    }

    @Test func failedCommitKeepsInboxForSuccessfulRetry() throws {
        enum Failure: Error { case disk }
        let fixture = Fixture()
        defer { fixture.cleanUp() }
        let store = fixture.makeStore()
        try store.enqueue(CaptureInboxEntry(id: "retry", text: "虚构分享内容", category: .idea))
        var fail = true
        let repository = FlashRepository(container: FlashDatabase.makeContainer(inMemory: true),
            beforeSave: { if fail { throw Failure.disk } })
        #expect(CaptureInboxImporter.drain(store, into: repository) == 0)
        #expect(store.pending().map(\.id) == ["retry"])
        #expect(try repository.allLogs().isEmpty)
        fail = false
        #expect(CaptureInboxImporter.drain(store, into: repository) == 1)
        #expect(store.pending().isEmpty)
        #expect(try repository.allLogs().map(\.id) == ["retry"])
    }

    @Test func drainSkipsTemporaryStoreAndKeepsFiles() throws {
        let fixture = Fixture()
        defer { fixture.cleanUp() }
        let store = fixture.makeStore()
        let repository = makeRepository(temporary: true)
        try store.enqueue(CaptureInboxEntry(id: "keep", text: "别丢", category: .idea))
        #expect(CaptureInboxImporter.drain(store, into: repository) == 0)
        #expect(try repository.allLogs().isEmpty)
        #expect(store.pending().map(\.id) == ["keep"])
    }

    @Test func drainWithoutAppGroupIsNoOp() {
        #expect(CaptureInboxImporter.drain(nil, into: makeRepository()) == 0)
    }
}
