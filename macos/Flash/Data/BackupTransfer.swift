// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import Darwin

/// 创建供 AirDrop、信息、邮件或云盘分享的一次性 JSON 副本。
/// 文件只位于 App 沙箱缓存目录，接收端仍由 BackupService 完整校验。
enum BackupTransfer {
    private static let directoryName = "SharedBackups"
    private static let filePrefix = "flash-aero-backup-"
    private static let maxCacheAge: TimeInterval = 24 * 60 * 60

    static func createShareFile(json: String, baseDirectory: URL? = nil) throws -> URL {
        let fileManager = FileManager.default
        let base = try baseDirectory ?? fileManager.url(
            for: .cachesDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true)
        let directory = base.appendingPathComponent(directoryName, isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)

        try cleanupExpired(in: base)

        let fileName = "\(filePrefix)\(DateFormatting.today())-\(UUID().uuidString.prefix(8)).json"
        let file = directory.appendingPathComponent(fileName)
        try json.write(to: file, atomically: true, encoding: .utf8)
        try? fileManager.setAttributes([.posixPermissions: NSNumber(value: 0o600)],
                                       ofItemAtPath: file.path)
        return file
    }

    /// Also run at launch so an abandoned plaintext share copy does not live forever.
    static func cleanupExpired(in baseDirectory: URL? = nil) throws {
        let fileManager = FileManager.default
        let base = try baseDirectory ?? fileManager.url(
            for: .cachesDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true)
        let directory = base.appendingPathComponent(directoryName, isDirectory: true)
        guard fileManager.fileExists(atPath: directory.path) else { return }

        let existing = try fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.contentModificationDateKey])
        for url in existing where url.lastPathComponent.hasPrefix(filePrefix) && url.pathExtension == "json" {
            let modified = try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
            if let modified, Date().timeIntervalSince(modified) > maxCacheAge {
                try? fileManager.removeItem(at: url)
            }
        }
    }

    /// Write an export beside its destination, then atomically replace the old
    /// file. The deferred cleanup closes every error path after plaintext has
    /// reached disk, while replaceItemAt preserves a valid existing backup if
    /// the final swap fails.
    static func writeExportFile(
        json: String,
        to destination: URL,
        finalize: ((URL, URL) throws -> Void)? = nil
    ) throws {
        let fileManager = FileManager.default
        let temporary = destination.deletingLastPathComponent()
            .appendingPathComponent(".flash-backup-\(UUID().uuidString).tmp")
        try json.write(to: temporary, atomically: false, encoding: .utf8)
        // 明文备份在临时文件上收紧到 0o600 再原子换入（rename 同卷内属性随 inode 生效）。
        // 本地卷（MNT_LOCAL：APFS/HFS/直挂卷）chmod 失败视为导出失败；
        // 网络卷（SMB/NFS 等）不实现 POSIX 模式，该卷的系统权限仍为最终权威。
        if isLocalVolume(destination) {
            do {
                try fileManager.setAttributes([.posixPermissions: NSNumber(value: 0o600)],
                                              ofItemAtPath: temporary.path)
            } catch {
                try? fileManager.removeItem(at: temporary)
                throw BackupTransferError.permissionTighteningFailed
            }
        } else {
            // 网络卷（SMB/NFS 等）不实现 POSIX 模式：尽力收紧，失败则以该卷系统权限为准
            try? fileManager.setAttributes([.posixPermissions: NSNumber(value: 0o600)],
                                           ofItemAtPath: temporary.path)
        }
        defer { try? fileManager.removeItem(at: temporary) }

        if let finalize {
            try finalize(temporary, destination)
        } else if fileManager.fileExists(atPath: destination.path) {
            _ = try fileManager.replaceItemAt(destination, withItemAt: temporary)
        } else {
            try fileManager.moveItem(at: temporary, to: destination)
        }
    }
    /// 目标路径所在卷是否为本地卷（MNT_LOCAL：APFS/HFS/直挂卷；SMB/NFS 等网络卷为否）。
    /// 查询失败按本地卷处理（chmod 失败从严判为导出失败）。
    static func isLocalVolume(_ url: URL) -> Bool {
        var stats = statfs()
        guard statfs(url.path, &stats) == 0 else { return true }
        return (Int32(stats.f_flags) & MNT_LOCAL) != 0
    }
}

enum BackupTransferError: Error {
    /// 本地卷 chmod 0o600 收紧失败：明文导出视为失败，不静默留下宽松权限文件
    case permissionTighteningFailed
}
