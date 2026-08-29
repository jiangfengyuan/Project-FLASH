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

        let existing = try fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.contentModificationDateKey])
        for url in existing where url.lastPathComponent.hasPrefix(filePrefix) && url.pathExtension == "json" {
            let modified = try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
            if let modified, Date().timeIntervalSince(modified) > maxCacheAge {
                try? fileManager.removeItem(at: url)
            }
        }

        let fileName = "\(filePrefix)\(DateFormatting.today())-\(UUID().uuidString.prefix(8)).json"
        let file = directory.appendingPathComponent(fileName)
        try json.write(to: file, atomically: true, encoding: .utf8)
        try? fileManager.setAttributes([.posixPermissions: NSNumber(value: 0o600)],
                                       ofItemAtPath: file.path)
        return file
    }
}
