// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Testing
import Foundation
@testable import FlashCore

@Suite("QuickCaptureDraftStore")
struct QuickCaptureDraftStoreTests {
    /// 独立随机目录 + suite，避免污染标准 defaults 与真实 Application Support
    private struct Fixture {
        let name = "test-\(UUID().uuidString)"
        let suite: UserDefaults
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)

        init() { suite = UserDefaults(suiteName: name)! }

        func makeStore() -> QuickCaptureDraftStore { QuickCaptureDraftStore(defaults: suite, directory: directory) }

        func cleanUp() {
            suite.removePersistentDomain(forName: name)
            try? FileManager.default.removeItem(at: directory)
        }
    }

    @Test func loadReturnsNilWhenEmpty() {
        let fixture = Fixture()
        defer { fixture.cleanUp() }
        #expect(fixture.makeStore().load() == nil)
    }

    @Test func saveLoadRoundtrip() {
        let fixture = Fixture()
        defer { fixture.cleanUp() }
        let store = fixture.makeStore()
        store.save(QuickCaptureDraft(text: "记到一半的闪念", category: .log))
        #expect(store.load() == QuickCaptureDraft(text: "记到一半的闪念", category: .log))
        // 新实例（下次打开面板 / 重启 App）仍能恢复
        #expect(fixture.makeStore().load() == QuickCaptureDraft(text: "记到一半的闪念", category: .log))
    }

    @Test func saveOverwrites() {
        let fixture = Fixture()
        defer { fixture.cleanUp() }
        let store = fixture.makeStore()
        store.save(QuickCaptureDraft(text: "旧", category: .idea))
        store.save(QuickCaptureDraft(text: "新", category: .log))
        #expect(store.load() == QuickCaptureDraft(text: "新", category: .log))
    }

    @Test func clearRemovesDraft() {
        let fixture = Fixture()
        defer { fixture.cleanUp() }
        let store = fixture.makeStore()
        store.save(QuickCaptureDraft(text: "待清", category: .idea))
        store.clear()
        #expect(store.load() == nil)
        #expect(!FileManager.default.fileExists(atPath: store.fileURL!.path))
    }

    /// 损坏数据按无草稿处理（不崩溃、不抛出）
    @Test func corruptFileFallsBackToNil() throws {
        let fixture = Fixture()
        defer { fixture.cleanUp() }
        let store = fixture.makeStore()
        try FileManager.default.createDirectory(at: fixture.directory, withIntermediateDirectories: true)
        try Data("not json".utf8).write(to: store.fileURL!)
        #expect(store.load() == nil)
    }

    // MARK: - F-17：不再明文留在 UserDefaults

    @Test func draftIsNeverWrittenToUserDefaults() {
        let fixture = Fixture()
        defer { fixture.cleanUp() }
        fixture.makeStore().save(QuickCaptureDraft(text: "私人草稿", category: .idea))
        #expect(fixture.suite.data(forKey: QuickCaptureDraftStore.legacyDefaultsKey) == nil)
    }

    @Test func draftFileIsExcludedFromBackup() throws {
        let fixture = Fixture()
        defer { fixture.cleanUp() }
        let store = fixture.makeStore()
        store.save(QuickCaptureDraft(text: "私人草稿", category: .idea))
        let values = try store.fileURL!.resourceValues(forKeys: [.isExcludedFromBackupKey])
        #expect(values.isExcludedFromBackup == true)
    }

    @Test func legacyDefaultsDraftMigratesOnceAndPlaintextKeyIsRemoved() throws {
        let fixture = Fixture()
        defer { fixture.cleanUp() }
        let legacy = try JSONEncoder().encode(QuickCaptureDraft(text: "旧版草稿", category: .log))
        fixture.suite.set(legacy, forKey: QuickCaptureDraftStore.legacyDefaultsKey)

        let store = fixture.makeStore()
        #expect(store.load() == QuickCaptureDraft(text: "旧版草稿", category: .log))
        #expect(fixture.suite.data(forKey: QuickCaptureDraftStore.legacyDefaultsKey) == nil)
    }

    @Test func corruptLegacyDraftIsDroppedNotKept() {
        let fixture = Fixture()
        defer { fixture.cleanUp() }
        fixture.suite.set(Data("not json".utf8), forKey: QuickCaptureDraftStore.legacyDefaultsKey)
        #expect(fixture.makeStore().load() == nil)
        #expect(fixture.suite.data(forKey: QuickCaptureDraftStore.legacyDefaultsKey) == nil)
    }

    @Test func legacyDraftDoesNotOverwriteNewerFileDraft() throws {
        let fixture = Fixture()
        defer { fixture.cleanUp() }
        fixture.makeStore().save(QuickCaptureDraft(text: "新文件草稿", category: .idea))
        let legacy = try JSONEncoder().encode(QuickCaptureDraft(text: "旧版草稿", category: .log))
        fixture.suite.set(legacy, forKey: QuickCaptureDraftStore.legacyDefaultsKey)
        #expect(fixture.makeStore().load() == QuickCaptureDraft(text: "新文件草稿", category: .idea))
        #expect(fixture.suite.data(forKey: QuickCaptureDraftStore.legacyDefaultsKey) == nil)
    }
}
