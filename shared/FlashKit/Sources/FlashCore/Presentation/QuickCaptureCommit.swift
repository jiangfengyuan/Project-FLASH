// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation

/// 快速记录的保存规则（此刻页快速捕捉卡、iOS 分享扩展）：macOS 与 iOS 共用同一口径。
/// - 去首尾空白，空内容不写入
/// - 契约上限（UTF-16 单元）超限不静默截断，交由调用方保留草稿并提示
/// - 日志 → daily 标签；灵感 → idea 标签 + 从 `!!` 标记推断重要度（与 Web/Android 对齐）
public enum QuickCaptureCommit {
    public enum Outcome: Equatable, Sendable {
        /// 已写入；`toast` 为保存成功的轻提示文案
        case saved(toast: String)
        /// 去空白后为空，什么都不做
        case empty
        /// 超出 `TextLimits.maxContentUTF16`，保留草稿
        case tooLong(message: String)
    }

    /// 写入前的校验结果：不触库的纯函数，分享扩展（不能打开主库）先用它拦下空内容与超长
    public enum Prepared: Equatable, Sendable {
        case ready(String)
        case empty
        case tooLong(message: String)
    }

    public static func prepare(_ draft: String) -> Prepared {
        let content = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else { return .empty }
        guard TextLimits.fits(content) else {
            return .tooLong(message: L("内容超出 \(TextLimits.maxContentUTF16) 字上限，请删减后再保存"))
        }
        return .ready(content)
    }

    /// - Parameter id: 指定记录 id（收件箱导入用于去重）；nil 新生成
    @MainActor
    public static func commit(_ draft: String, as category: Category, id: String? = nil,
                              repository: FlashRepository) throws -> Outcome {
        let content: String
        switch prepare(draft) {
        case .empty: return .empty
        case .tooLong(let message): return .tooLong(message: message)
        case .ready(let value): content = value
        }
        switch category {
        case .log:
            try repository.addLog(id: id, content: content, colorTag: .daily, category: .log)
        case .idea:
            try repository.addLog(id: id, content: content, colorTag: .idea, category: .idea,
                                  importance: importanceFromContent(content))
        }
        return .saved(toast: category == .idea ? L("✓ 已保存到灵感") : L("✓ 已保存到日志"))
    }
}
