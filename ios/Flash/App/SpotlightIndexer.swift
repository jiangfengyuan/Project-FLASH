// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import CoreSpotlight
import Foundation
import UniformTypeIdentifiers
import FlashCore

/// 系统索引的最小操作面：测试注入替身，App 用 `CoreSpotlightIndex`
@MainActor
protocol SpotlightIndexing: AnyObject {
    func index(_ records: [SpotlightRecord])
    func remove(ids: [String])
    /// 清空本 App 的整个索引后写入 `records`（空数组 = 只清空）
    func replaceAll(with records: [SpotlightRecord])
}

/// Core Spotlight 实现：独立命名索引，`.complete` 保护（设备锁定时索引数据不可读）；
/// 不设 `isEligibleForPublicIndexing`，条目只在本机。
@MainActor
final class CoreSpotlightIndex: SpotlightIndexing {
    private let index = CSSearchableIndex(name: "flash-records", protectionClass: .complete)

    func index(_ records: [SpotlightRecord]) {
        guard !records.isEmpty else { return }
        index.indexSearchableItems(records.map(Self.item)) { error in
            if let error { FlashLog.failure("spotlight_index_failed", error) }
        }
    }

    func remove(ids: [String]) {
        guard !ids.isEmpty else { return }
        index.deleteSearchableItems(withIdentifiers: ids) { error in
            if let error { FlashLog.failure("spotlight_delete_failed", error) }
        }
    }

    func replaceAll(with records: [SpotlightRecord]) {
        // 先清后写：在删除回调里写入，保证新条目不会被同一轮清空吞掉
        index.deleteAllSearchableItems { [weak self] error in
            if let error {
                FlashLog.failure("spotlight_clear_failed", error)
                return
            }
            Task { @MainActor in self?.index(records) }
        }
    }

    private static func item(_ record: SpotlightRecord) -> CSSearchableItem {
        let attributes = CSSearchableItemAttributeSet(contentType: .text)
        attributes.title = record.title
        attributes.contentDescription = record.contentDescription
        attributes.keywords = record.keywords
        attributes.contentCreationDate = record.createdAt
        return CSSearchableItem(uniqueIdentifier: record.id, domainIdentifier: record.domain,
                                attributeSet: attributes)
    }
}

/// 日志 / 灵感 → 系统搜索（Spotlight）。
/// - 增量：仓储 `onLogChange` 的新增改动即写、删除即撤；整表替换（清空、覆盖导入）整体重建；
/// - 启动对账：全量重建一次，修复关闭期间或异常退出造成的偏差；
/// - 设置关闭：清空索引，之后不再写入；重新开启时全量重建；
/// - 内存降级（`isTemporaryStore`）：完全不动索引。临时库没有真实数据，按它重建会清掉真实条目。
@MainActor
final class SpotlightIndexer {
    private let index: any SpotlightIndexing
    private let repository: FlashRepository
    private let isEnabled: () -> Bool

    init(index: any SpotlightIndexing, repository: FlashRepository, isEnabled: @escaping () -> Bool) {
        self.index = index
        self.repository = repository
        self.isEnabled = isEnabled
    }

    private var isActive: Bool { isEnabled() && !repository.isTemporaryStore }

    func handle(_ change: LogChange) {
        guard isActive else { return }
        switch change {
        case .upserted(let logs): index.index(logs.map(SpotlightRecord.init))
        case .deleted(let ids): index.remove(ids: ids)
        case .reset: rebuild()
        }
    }

    /// 启动对账与重新开启：按当前日志表全量重建
    func rebuild() {
        guard isActive else { return }
        do {
            index.replaceAll(with: try repository.allLogs().map(SpotlightRecord.init))
        } catch {
            FlashLog.failure("spotlight_rebuild_failed", error)
        }
    }

    func settingChanged(enabled: Bool) {
        if enabled {
            rebuild()
        } else if !repository.isTemporaryStore {
            index.replaceAll(with: [])
        }
    }

    /// 点开系统搜索结果：记录已不存在（例如在别处删除后索引未及时撤下）时顺手撤掉该条
    func resultOpened(id: String) {
        guard !repository.isTemporaryStore, (try? repository.containsLog(id: id)) == false else { return }
        index.remove(ids: [id])
    }
}
