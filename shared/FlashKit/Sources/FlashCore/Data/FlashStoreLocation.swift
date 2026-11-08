// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation

/// SwiftData 主库的位置：App 私有的 `Application Support/default.store`。
///
/// 旧版本用 `ModelConfiguration` 默认的 `groupContainer: .automatic`，iOS 声明 App Group 后
/// 主库落在组容器里，分享扩展与小组件进程都能读到。主库只属于主 App：扩展经
/// `CaptureInboxStore` 投递、小组件读 `WidgetSnapshot`，都不需要打开它。
///
/// 文件保护沿用系统默认（首次解锁后可读）：任务提醒的「完成 / 稍后」按钮和「记一闪」解锁后
/// 都可能在后台、锁屏状态下打开主库；改为 `.complete` 会让这些路径打不开库并降级为内存库。
public enum FlashStoreLocation {
    public static let fileName = "default.store"

    /// SQLite 主文件最后移动：中途失败时下次启动仍能识别为「待迁移」并补完。
    static let companionSuffixes = ["-wal", "-shm"]

    public static var privateStoreURL: URL {
        URL.applicationSupportDirectory.appending(path: fileName, directoryHint: .notDirectory)
    }

    /// `.automatic` 在 iOS 上实际使用的组容器路径；macOS 主 App 不声明 App Group，没有旧位置
    static var legacyGroupStoreURL: URL? {
        #if os(iOS)
        WidgetSnapshotStore.containerDirectory?
            .appending(path: "Library/Application Support/\(fileName)", directoryHint: .notDirectory)
        #else
        nil
        #endif
    }

    /// 生产路径：必要时把组容器里的旧库搬到私有目录。迁移失败时本次继续打开旧库，
    /// 不新建空库（否则下次会因私有库已存在而跳过迁移，用户看到的数据「消失」）。
    public static func resolve() -> URL {
        resolve(legacy: legacyGroupStoreURL, destination: privateStoreURL)
    }

    static func resolve(legacy: URL?, destination: URL) -> URL {
        do {
            try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(),
                                                    withIntermediateDirectories: true)
            if try migrateIfNeeded(from: legacy, to: destination) {
                FlashLog.notice("storage_migrated_out_of_group_container")
            }
            return destination
        } catch {
            FlashLog.failure("storage_group_migration_failed", error)
            if let legacy, FileManager.default.fileExists(atPath: legacy.path) { return legacy }
            return destination
        }
    }

    /// - Returns: 是否搬动了主库。私有库已存在时不动任何文件（不覆盖、不删除组容器里的副本）。
    @discardableResult
    static func migrateIfNeeded(from legacy: URL?, to destination: URL) throws -> Bool {
        let fileManager = FileManager.default
        guard let legacy, fileManager.fileExists(atPath: legacy.path),
              !fileManager.fileExists(atPath: destination.path) else { return false }
        try fileManager.createDirectory(at: destination.deletingLastPathComponent(),
                                        withIntermediateDirectories: true)
        for item in companionItems(of: legacy).map({ ($0, sibling($0, nextTo: destination)) }) {
            guard fileManager.fileExists(atPath: item.0.path) else { continue }
            // 上次中断留下的半截副本：以组容器里的为准
            if fileManager.fileExists(atPath: item.1.path) { try fileManager.removeItem(at: item.1) }
            try fileManager.moveItem(at: item.0, to: item.1)
        }
        try fileManager.moveItem(at: legacy, to: destination)
        return true
    }

    /// WAL / SHM 与 Core Data 外部存储目录（`.default_SUPPORT`）
    private static func companionItems(of store: URL) -> [URL] {
        let directory = store.deletingLastPathComponent()
        let stem = store.deletingPathExtension().lastPathComponent
        return companionSuffixes.map { directory.appending(path: store.lastPathComponent + $0) }
            + [directory.appending(path: ".\(stem)_SUPPORT", directoryHint: .isDirectory)]
    }

    private static func sibling(_ item: URL, nextTo destination: URL) -> URL {
        destination.deletingLastPathComponent().appending(path: item.lastPathComponent)
    }
}
