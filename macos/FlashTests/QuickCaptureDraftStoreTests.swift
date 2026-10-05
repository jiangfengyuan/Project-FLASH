// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Testing
import Foundation
@testable import Flash

@Suite("QuickCaptureDraftStore")
struct QuickCaptureDraftStoreTests {
    /// 独立随机 suite，避免污染标准 defaults；各测试 defer 清理残留
    private func makeSuite() -> (name: String, suite: UserDefaults) {
        let name = "test-\(UUID().uuidString)"
        return (name, UserDefaults(suiteName: name)!)
    }

    @Test func loadReturnsNilWhenEmpty() {
        let (name, suite) = makeSuite()
        defer { suite.removePersistentDomain(forName: name) }
        #expect(QuickCaptureDraftStore(defaults: suite).load() == nil)
    }

    @Test func saveLoadRoundtrip() {
        let (name, suite) = makeSuite()
        defer { suite.removePersistentDomain(forName: name) }
        let store = QuickCaptureDraftStore(defaults: suite)
        store.save(QuickCaptureDraft(text: "记到一半的闪念", category: .log))
        #expect(store.load() == QuickCaptureDraft(text: "记到一半的闪念", category: .log))
    }

    @Test func saveOverwrites() {
        let (name, suite) = makeSuite()
        defer { suite.removePersistentDomain(forName: name) }
        let store = QuickCaptureDraftStore(defaults: suite)
        store.save(QuickCaptureDraft(text: "旧", category: .idea))
        store.save(QuickCaptureDraft(text: "新", category: .log))
        #expect(store.load() == QuickCaptureDraft(text: "新", category: .log))
    }

    @Test func clearRemovesDraft() {
        let (name, suite) = makeSuite()
        defer { suite.removePersistentDomain(forName: name) }
        let store = QuickCaptureDraftStore(defaults: suite)
        store.save(QuickCaptureDraft(text: "待清", category: .idea))
        store.clear()
        #expect(store.load() == nil)
    }

    /// 损坏数据按无草稿处理（不崩溃、不抛出）
    @Test func corruptDataFallsBackToNil() {
        let (name, suite) = makeSuite()
        defer { suite.removePersistentDomain(forName: name) }
        suite.set(Data("not json".utf8), forKey: "quickCaptureDraft")
        #expect(QuickCaptureDraftStore(defaults: suite).load() == nil)
    }
}
