// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation

/// 分享扩展 → 主 App 的一条待收入内容。JSON 文件即跨进程协议。
public struct CaptureInboxEntry: Codable, Equatable, Sendable {
    /// 同时作为导入后的记录 id：中断后重放按 id 去重
    public var id: String
    /// 已经 `QuickCaptureCommit.prepare` 校验过的正文
    public var text: String
    public var category: Category
    /// ISO-8601；放在 JSON 里而不读文件时间戳（免去 required-reason API 申报）
    public var createdAt: String

    public init(id: String = UUID().uuidString, text: String, category: Category,
                createdAt: String = DateFormatting.isoNow()) {
        self.id = id
        self.text = text
        self.category = category
        self.createdAt = createdAt
    }

    /// 分享来的文字与链接合成正文：两者都有时链接另起一行；文字已含该链接则不重复
    public static func compose(text: String?, url: URL?) -> String {
        let body = text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard let link = url?.absoluteString, !link.isEmpty else { return body }
        if body.isEmpty { return link }
        return body.contains(link) ? body : body + "\n" + link
    }
}

public enum CaptureInboxError: Error, Equatable {
    /// 待收入条数达到上限：请用户先打开 Flash
    case full
}

/// 分享收件箱：App Group 容器下 `capture-inbox/`，一条内容一个 `<id>.json`。
///
/// SwiftData 主库不在 App Group 内（迁移属独立项目），扩展不能打开它，只往这里投递；
/// 主 App 启动与回到前台时经 `CaptureInboxImporter` 收入并删除文件。
/// - 一条一个文件：扩展与 App 永不追加写同一文件，无需跨进程锁；
/// - iOS 以 `.completeFileProtection` 写入（锁定即不可读），目录与文件标记不纳入备份，
///   与 `QuickCaptureDraftStore` 同口径：这是尚未入库的私人正文；
/// - 最多积压 `maxPending` 条，避免 App 长期不打开时无限堆积。
public final class CaptureInboxStore: Sendable {
    public static let directoryName = "capture-inbox"
    public static let maxPending = 50

    public let directory: URL

    public init(directory: URL) {
        self.directory = directory
    }

    /// App Group 不可用（未签名构建）时为 nil：扩展据此报错，不退回内存
    public static var shared: CaptureInboxStore? {
        WidgetSnapshotStore.containerDirectory.map {
            CaptureInboxStore(directory: $0.appendingPathComponent(directoryName, isDirectory: true))
        }
    }

    public func enqueue(_ entry: CaptureInboxEntry) throws {
        guard pendingFileURLs().count < Self.maxPending else { throw CaptureInboxError.full }
        try prepareDirectory()
        let data = try JSONEncoder().encode(entry)
        var url = fileURL(for: entry.id)
        #if os(iOS)
        try data.write(to: url, options: [.atomic, .completeFileProtection])
        #else
        try data.write(to: url, options: .atomic)
        #endif
        try excludeFromBackup(&url)
    }

    /// 按 createdAt 升序返回可解码的条目；损坏文件记日志后删除（无法恢复，也不该反复重试）
    public func pending() -> [CaptureInboxEntry] {
        var entries: [CaptureInboxEntry] = []
        for url in pendingFileURLs() {
            do {
                entries.append(try JSONDecoder().decode(CaptureInboxEntry.self, from: Data(contentsOf: url)))
            } catch {
                FlashLog.failure("capture_inbox_entry_unreadable", error)
                try? FileManager.default.removeItem(at: url)
            }
        }
        return entries.sorted { $0.createdAt < $1.createdAt }
    }

    public func remove(id: String) {
        try? FileManager.default.removeItem(at: fileURL(for: id))
    }

    func fileURL(for id: String) -> URL {
        directory.appendingPathComponent("\(id).json", isDirectory: false)
    }

    private func pendingFileURLs() -> [URL] {
        let urls = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
        return urls.filter { $0.pathExtension == "json" }
    }

    private func prepareDirectory() throws {
        var attributes: [FileAttributeKey: Any] = [:]
        #if os(iOS)
        attributes[.protectionKey] = FileProtectionType.complete
        #endif
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true,
                                                attributes: attributes)
        var url = directory
        try excludeFromBackup(&url)
    }

    private func excludeFromBackup(_ url: inout URL) throws {
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try url.setResourceValues(values)
    }
}

/// 主 App 收入分享收件箱：逐条经 `QuickCaptureCommit` 写库（与快速记录同一套去空白、上限、标签规则），
/// 成功后删文件。
public enum CaptureInboxImporter {
    /// - Returns: 本次新写入的条数
    /// 内存降级（`isTemporaryStore`）时不收入、不删文件：写进临时库等于丢失，留到下次正常启动。
    @MainActor
    @discardableResult
    public static func drain(_ store: CaptureInboxStore?, into repository: FlashRepository) -> Int {
        guard let store, !repository.isTemporaryStore else { return 0 }
        var imported = 0
        for entry in store.pending() {
            do {
                // 上次已写库但没来得及删文件：只补删
                if try repository.containsLog(id: entry.id) {
                    store.remove(id: entry.id)
                    continue
                }
                switch try QuickCaptureCommit.commit(entry.text, as: entry.category, id: entry.id,
                                                     repository: repository) {
                case .saved: imported += 1
                case .empty, .tooLong: FlashLog.notice("capture_inbox_entry_rejected")
                }
                store.remove(id: entry.id)
            } catch {
                // 写库失败保留文件，下次再试；后续条目大概率同样失败，本轮停止
                FlashLog.failure("capture_inbox_import_failed", error)
                break
            }
        }
        return imported
    }
}
