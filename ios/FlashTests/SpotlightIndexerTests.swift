// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Testing
import FlashCore
@testable import Flash

/// 记录系统索引调用的替身
@MainActor
private final class FakeIndex: SpotlightIndexing {
    enum Call: Equatable {
        case index([String])
        case remove([String])
        case replaceAll([String])
    }
    var calls: [Call] = []

    func index(_ records: [SpotlightRecord]) { calls.append(.index(records.map(\.id))) }
    func remove(ids: [String]) { calls.append(.remove(ids)) }
    func replaceAll(with records: [SpotlightRecord]) { calls.append(.replaceAll(records.map(\.id))) }
}

@MainActor
@Suite("Spotlight 索引同步")
struct SpotlightIndexerTests {
    private final class Flag { var enabled = true }

    private func make(temporary: Bool = false) -> (FlashRepository, FakeIndex, Flag, SpotlightIndexer) {
        let repository = FlashRepository(container: FlashDatabase.makeContainer(inMemory: true),
                                         isTemporaryStore: temporary)
        let index = FakeIndex()
        let flag = Flag()
        let indexer = SpotlightIndexer(index: index, repository: repository, isEnabled: { flag.enabled })
        repository.onLogChange = { indexer.handle($0) }
        return (repository, index, flag, indexer)
    }

    @Test func writesAndDeletesFollowRepository() throws {
        let (repository, index, _, _) = make()
        try repository.addLog(id: "a", content: "一条", colorTag: .daily)
        try repository.deleteLog(id: "a")
        #expect(index.calls == [.index(["a"]), .remove(["a"])])
    }

    @Test func clearAllAndOverwriteImportRebuildFromStore() throws {
        let (repository, index, _, _) = make()
        try repository.addLog(id: "a", content: "一条", colorTag: .daily)
        try repository.clearAll()
        let imported = LogItem(id: "b", content: "导入", colorTag: .idea, category: .idea, importance: 0,
                               createdAt: DateFormatting.isoNow(), recordDate: DateFormatting.today())
        try repository.replaceAll(logs: [imported], emotions: [])
        #expect(index.calls == [.index(["a"]), .replaceAll([]), .replaceAll(["b"])])
    }

    @Test func disabledSettingIndexesNothingAndTogglingClearsOrRebuilds() throws {
        let (repository, index, flag, indexer) = make()
        flag.enabled = false
        try repository.addLog(id: "a", content: "一条", colorTag: .daily)
        indexer.rebuild()
        indexer.settingChanged(enabled: false)
        #expect(index.calls == [.replaceAll([])])
        flag.enabled = true
        indexer.settingChanged(enabled: true)
        #expect(index.calls.last == .replaceAll(["a"]))
    }

    @Test func temporaryStoreNeverTouchesIndex() throws {
        let (repository, index, _, indexer) = make(temporary: true)
        try repository.addLog(id: "a", content: "临时", colorTag: .daily)
        try repository.clearAll()
        indexer.rebuild()
        indexer.settingChanged(enabled: false)
        indexer.resultOpened(id: "missing")
        #expect(index.calls.isEmpty)
    }

    @Test func openingStaleResultRemovesIt() throws {
        let (repository, index, _, indexer) = make()
        try repository.addLog(id: "a", content: "还在", colorTag: .daily)
        index.calls = []
        indexer.resultOpened(id: "a")
        indexer.resultOpened(id: "gone")
        #expect(index.calls == [.remove(["gone"])])
    }

    @Test func openingResultRoutesToRecord() {
        let state = AppState()
        state.selectedTab = .stats
        state.quickCapture = QuickCaptureRequest(category: nil)
        state.openSpotlightResult(id: "abc")
        #expect(state.selectedTab == .explore)
        #expect(state.quickCapture == nil)
        #expect(state.focusRouter.consume(matching: { if case .log = $0 { true } else { false } }) == .log("abc"))
    }
}
