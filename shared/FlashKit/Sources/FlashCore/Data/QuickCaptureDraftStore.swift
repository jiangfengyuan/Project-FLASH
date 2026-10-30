// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation

/// Quick Capture 面板草稿（PRD §14 自动保存草稿）：未提交关闭时保留，下次打开恢复。
/// 纯值类型，Codable 持久化。
public struct QuickCaptureDraft: Codable, Equatable, Sendable {
    public var text: String
    public var category: Category

    public init(text: String, category: Category) {
        self.text = text
        self.category = category
    }
}

/// 草稿存取：Application Support 下的 JSON 小文件（F-17）。
///
/// 草稿是未保存的私人正文，此前以明文存在 UserDefaults（随设备备份、锁屏后可读）。现在：
/// - iOS 以 `.completeFileProtection` 写入：设备锁定即不可读。草稿只在前台打开 / 关闭面板时读写，
///   不受影响；
/// - 标记「不纳入备份」：草稿是会话状态，不应进入 iCloud / 电脑备份；
/// - 首次构造时把旧版 UserDefaults 里的草稿迁入文件并删除旧键。
/// 独立小类型而非塞进 SettingsStore：草稿是会话状态不是用户设置，且便于测试注入独立目录。
public final class QuickCaptureDraftStore {
    static let legacyDefaultsKey = "quickCaptureDraft"
    static let fileName = "quick-capture-draft.json"

    /// nil：Application Support 不可用，草稿只在本次会话内存中保留
    let fileURL: URL?
    private var memoryDraft: QuickCaptureDraft?

    /// - Parameters:
    ///   - defaults: 旧版草稿所在的 UserDefaults（仅用于一次性迁移）
    ///   - directory: 草稿文件目录；nil 取 Application Support
    public init(defaults: UserDefaults = .standard, directory: URL? = nil) {
        let base = directory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        fileURL = base?.appendingPathComponent(Self.fileName, isDirectory: false)
        migrateLegacyDraft(from: defaults)
    }

    public func load() -> QuickCaptureDraft? {
        guard let fileURL else { return memoryDraft }
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return try? JSONDecoder().decode(QuickCaptureDraft.self, from: data)
    }

    public func save(_ draft: QuickCaptureDraft) {
        guard let fileURL else { memoryDraft = draft; return }
        guard let data = try? JSONEncoder().encode(draft) else { return }
        do {
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(),
                                                    withIntermediateDirectories: true)
            #if os(iOS)
            try data.write(to: fileURL, options: [.atomic, .completeFileProtection])
            #else
            try data.write(to: fileURL, options: .atomic)
            #endif
            var url = fileURL
            var values = URLResourceValues()
            values.isExcludedFromBackup = true
            try url.setResourceValues(values)
        } catch {
            // 草稿是增强能力：写失败只丢草稿，不影响已保存的记录
            FlashLog.failure("draft_write_failed", error)
        }
    }

    public func clear() {
        memoryDraft = nil
        guard let fileURL else { return }
        try? FileManager.default.removeItem(at: fileURL)
    }

    /// 旧版草稿迁入受保护文件；无论迁移成败都删除旧键，不再留明文副本
    private func migrateLegacyDraft(from defaults: UserDefaults) {
        guard let data = defaults.data(forKey: Self.legacyDefaultsKey) else { return }
        defaults.removeObject(forKey: Self.legacyDefaultsKey)
        guard load() == nil, let draft = try? JSONDecoder().decode(QuickCaptureDraft.self, from: data) else { return }
        save(draft)
    }
}
