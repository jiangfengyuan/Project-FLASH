// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation

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
        try json.write(to: temporary, atomically: true, encoding: .utf8)
        defer { try? fileManager.removeItem(at: temporary) }
        do {
            try fileManager.setAttributes([.posixPermissions: NSNumber(value: 0o600)],
                                          ofItemAtPath: temporary.path)
        } catch {
            // Some user-selected volumes do not implement POSIX modes. The
            // system's volume permissions remain authoritative there.
            print("chmod temp 文件失败: \(error)")
        }

        if let finalize {
            try finalize(temporary, destination)
        } else if fileManager.fileExists(atPath: destination.path) {
            _ = try fileManager.replaceItemAt(destination, withItemAt: temporary)
        } else {
            try fileManager.moveItem(at: temporary, to: destination)
        }
    }
}
