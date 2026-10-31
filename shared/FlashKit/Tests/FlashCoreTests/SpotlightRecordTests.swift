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
@Suite("Spotlight 映射与日志变更事件")
struct SpotlightRecordTests {
    private func log(_ content: String, category: FlashCore.Category = .idea) -> LogItem {
        LogItem(id: "l1", content: content, colorTag: category == .idea ? .idea : .daily, category: category,
                importance: 0, createdAt: "2026-10-31T08:00:00.000Z", recordDate: "2026-10-31")
    }

    // MARK: - SpotlightRecord

    @Test func firstLineIsTitleRestIsDescription() {
        let record = SpotlightRecord(log("  分享扩展 \n\n先做收件箱\n再做 Spotlight"))
        #expect(record.id == "l1")
        #expect(record.domain == "idea")
        #expect(record.title == "分享扩展")
        #expect(record.contentDescription == "先做收件箱 再做 Spotlight")
        #expect(record.keywords.first == "灵感")
        #expect(record.createdAt == DateFormatting.parseISO("2026-10-31T08:00:00.000Z"))
    }

    @Test func singleLineHasNoDescriptionAndLongTextIsClipped() {
        let record = SpotlightRecord(log(String(repeating: "长", count: 100), category: .log))
        #expect(record.domain == "log")
        #expect(record.contentDescription == nil)
        #expect(record.title.count == SpotlightRecord.titleLimit)
        #expect(record.title.hasSuffix("…"))
    }

    // MARK: - onLogChange

    private func makeObservedRepository() -> (FlashRepository, () -> [LogChange]) {
        let repository = FlashRepository(container: FlashDatabase.makeContainer(inMemory: true))
        final class Box { var changes: [LogChange] = [] }
        let box = Box()
        repository.onLogChange = { box.changes.append($0) }
        return (repository, { box.changes })
    }

    @Test func writesEmitMatchingChanges() throws {
        let (repository, changes) = makeObservedRepository()
        try repository.addLog(id: "a", content: "一条", colorTag: .daily)
        var edited = try #require(try repository.allLogs().first)
        edited.content = "改过"
        try repository.updateLog(edited)
        try repository.setLogFavorite(id: "a", true)
        try repository.deleteLog(id: "a")
        try repository.clearAll()
        let recorded = changes()
        #expect(recorded.count == 5)
        guard case .upserted(let added) = recorded[0], case .upserted(let updated) = recorded[1],
              case .upserted(let favorited) = recorded[2] else {
            Issue.record("前三次应为 upserted: \(recorded)")
            return
        }
        #expect(added.map(\.id) == ["a"])
        #expect(updated.first?.content == "改过")
        #expect(favorited.first?.isFavorite == true)
        #expect(recorded[3] == .deleted(["a"]))
        #expect(recorded[4] == .reset)
    }

    @Test func importsEmitResetOrUpserts() throws {
        let (repository, changes) = makeObservedRepository()
        let item = log("导入的")
        try repository.mergeAll(logs: [item], emotions: [])
        try repository.replaceAll(logs: [item], emotions: [])
        #expect(changes() == [.upserted([item]), .reset])
    }

    @Test func failedCommitEmitsNothing() throws {
        let repository = FlashRepository(container: FlashDatabase.makeContainer(inMemory: true),
                                         beforeSave: { throw CocoaError(.fileWriteUnknown) })
        var emitted = false
        repository.onLogChange = { _ in emitted = true }
        #expect(throws: (any Error).self) { try repository.addLog(content: "写不进", colorTag: .daily) }
        #expect(!emitted)
    }

    @Test func deletingMissingLogEmitsNothing() throws {
        let (repository, changes) = makeObservedRepository()
        try repository.deleteLog(id: "nope")
        #expect(changes().isEmpty)
    }
}
