// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Testing
@testable import Flash

@Suite("AppState 数据库降级标记")
struct AppStateTests {
    @Test func checkDatabaseFallbackSetsMessageAndPersistentFlag() {
        let appState = AppState()
        #expect(appState.isDatabaseInMemoryFallback == false)
        appState.checkDatabaseFallback(didFallbackToMemory: true)
        #expect(appState.isDatabaseInMemoryFallback == true)
        #expect(appState.databaseFallbackMessage != nil)
    }

    @Test func checkDatabaseFallbackNoFallbackKeepsDefaults() {
        let appState = AppState()
        appState.checkDatabaseFallback(didFallbackToMemory: false)
        #expect(appState.isDatabaseInMemoryFallback == false)
        #expect(appState.databaseFallbackMessage == nil)
    }

    @Test func clearingMessageKeepsPersistentFlag() {
        // 菜单栏伴侣的持久警示依赖 isDatabaseInMemoryFallback：
        // 用户在主窗口点「我知道了」只清 alert 文案，不得清除降级标记
        let appState = AppState()
        appState.checkDatabaseFallback(didFallbackToMemory: true)
        appState.clearDatabaseFallbackMessage()
        #expect(appState.databaseFallbackMessage == nil)
        #expect(appState.isDatabaseInMemoryFallback == true)
    }
}
