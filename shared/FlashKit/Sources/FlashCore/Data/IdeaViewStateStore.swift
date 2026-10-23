// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import Observation

/// 灵感已读状态（本地 UI 状态，刻意不进 flash-backup-v2 备份，与 Android / HarmonyOS 一致）。
/// 存为 Application Support 下的 JSON（已读 id 集 + 基线标记）。
///
/// 首次启用时建立基线：现有灵感全部视为已读，只有之后新建或导入的灵感进入提醒队列
/// （对齐 Android v1→v2 迁移：不能把历史灵感冒充为「从未查看」）。
@Observable
public final class IdeaViewStateStore {
    public private(set) var viewedIDs: Set<String>
    public private(set) var hasBaseline: Bool

    @ObservationIgnored private let fileURL: URL?

    private struct Payload: Codable {
        var viewed: [String]
        var baseline: Bool
    }

    /// directory 为 nil 时取 Application Support；fileURL 为 nil（目录不可用）时只在内存中工作
    public init(directory: URL? = nil) {
        let base = directory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        fileURL = base?.appendingPathComponent("idea-view-state.json", isDirectory: false)
        if let fileURL, let data = try? Data(contentsOf: fileURL),
           let payload = try? JSONDecoder().decode(Payload.self, from: data) {
            viewedIDs = Set(payload.viewed)
            hasBaseline = payload.baseline
        } else {
            // 文件缺失或损坏：视为首次启用（随后建立基线，不会把历史灵感误报为未读）
            viewedIDs = []
            hasBaseline = false
        }
    }

    /// 首次启用：把当前全部灵感记为已读
    public func establishBaselineIfNeeded(existingIdeaIDs: [String]) {
        guard !hasBaseline else { return }
        viewedIDs.formUnion(existingIdeaIDs)
        hasBaseline = true
        persist()
    }

    public func markViewed(_ id: String) {
        guard viewedIDs.insert(id).inserted else { return }
        persist()
    }

    public func markViewed(_ ids: some Sequence<String>) {
        let before = viewedIDs.count
        viewedIDs.formUnion(ids)
        if viewedIDs.count != before { persist() }
    }

    /// 只保留仍存在的灵感 id（删除 / 覆盖导入 / 清空后收敛，避免集合无限增长）
    public func prune(keeping existingIdeaIDs: Set<String>) {
        let pruned = viewedIDs.intersection(existingIdeaIDs)
        guard pruned.count != viewedIDs.count else { return }
        viewedIDs = pruned
        persist()
    }

    private func persist() {
        guard let fileURL else { return }
        do {
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(),
                                                    withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(Payload(viewed: viewedIDs.sorted(), baseline: hasBaseline))
            try data.write(to: fileURL, options: [.atomic, .completeFileProtection])
        } catch {
            // 已读状态是增强能力：写失败只影响提醒精度，不影响记录数据
            print("IdeaViewStateStore: 写入失败 - \(error)")
        }
    }
}
