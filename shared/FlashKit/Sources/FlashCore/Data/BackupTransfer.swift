// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import Darwin

/// 创建供 AirDrop、信息、邮件或云盘分享的一次性 JSON 副本。
/// 文件只位于 App 沙箱缓存目录，接收端仍由 BackupService 完整校验。
public enum BackupTransfer: Sendable {
    private static let directoryName = "SharedBackups"
    private static let filePrefix = "flash-aero-backup-"
    private static let maxCacheAge: TimeInterval = 24 * 60 * 60

    public static func createShareFile(json: String, baseDirectory: URL? = nil) throws -> URL {
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
        try writePrivateFile(Data(json.utf8), to: file)
        return file
    }

    /// Also run at launch so an abandoned plaintext share copy does not live forever.
    public static func cleanupExpired(in baseDirectory: URL? = nil) throws {
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
    public static func writeExportFile(
        json: String,
        to destination: URL,
        finalize: ((URL, URL) throws -> Void)? = nil
    ) throws {
        let fileManager = FileManager.default
        let temporary = destination.deletingLastPathComponent()
            .appendingPathComponent(".flash-backup-\(UUID().uuidString).tmp")
        try writePrivateFile(Data(json.utf8), to: temporary)
        defer { try? fileManager.removeItem(at: temporary) }

        if let finalize {
            try finalize(temporary, destination)
        } else if fileManager.fileExists(atPath: destination.path) {
            // Default replacement preserves old metadata, including a broad
            // destination mode. Keep the new private inode's metadata instead.
            _ = try fileManager.replaceItemAt(destination, withItemAt: temporary,
                                              options: .usingNewMetadataOnly)
        } else {
            try fileManager.moveItem(at: temporary, to: destination)
        }
    }

    /// Exclusive creation restricts access before the first plaintext byte.
    /// Failure at any write/close step removes the partial file. The injectable
    /// descriptor writer lets tests observe creation mode and failed writes.
    static func writePrivateFile(_ data: Data, to file: URL,
                                 writer: (FileHandle, Data) throws -> Void = { try $0.write(contentsOf: $1) }) throws {
        let descriptor = open(file.path, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW, 0o600)
        guard descriptor >= 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
        let handle = FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)
        var complete = false
        defer {
            try? handle.close()
            if !complete { try? FileManager.default.removeItem(at: file) }
        }
        // Some remote volumes have no POSIX mode support; their ACL remains
        // authoritative. On local volumes fail before writing any plaintext.
        if fchmod(descriptor, 0o600) != 0 && isLocalVolume(file) {
            throw BackupTransferError.permissionTighteningFailed
        }
        try writer(handle, data)
        try handle.close()
        complete = true
    }
    /// 目标路径所在卷是否为本地卷（MNT_LOCAL：APFS/HFS/直挂卷；SMB/NFS 等网络卷为否）。
    /// 查询失败按本地卷处理（chmod 失败从严判为导出失败）。
    public static func isLocalVolume(_ url: URL) -> Bool {
        var stats = statfs()
        guard statfs(url.path, &stats) == 0 else { return true }
        return (Int32(stats.f_flags) & MNT_LOCAL) != 0
    }
}

public enum BackupTransferError: Error, Sendable {
    /// 本地卷 chmod 0o600 收紧失败：明文导出视为失败，不静默留下宽松权限文件
    case permissionTighteningFailed
}
