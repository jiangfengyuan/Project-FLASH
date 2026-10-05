// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation

/// Quick Capture 面板草稿（PRD §14 自动保存草稿）：未提交关闭时保留，下次打开恢复。
/// 纯值类型，Codable 持久化。
struct QuickCaptureDraft: Codable, Equatable, Sendable {
    var text: String
    var category: Category
}

/// 草稿存取（UserDefaults + JSON）。独立小类型而非塞进 SettingsStore：
/// 草稿是会话状态不是用户设置，且便于测试注入独立 suite。
final class QuickCaptureDraftStore {
    private let defaults: UserDefaults
    private let key = "quickCaptureDraft"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> QuickCaptureDraft? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(QuickCaptureDraft.self, from: data)
    }

    func save(_ draft: QuickCaptureDraft) {
        guard let data = try? JSONEncoder().encode(draft) else { return }
        defaults.set(data, forKey: key)
    }

    func clear() {
        defaults.removeObject(forKey: key)
    }
}
