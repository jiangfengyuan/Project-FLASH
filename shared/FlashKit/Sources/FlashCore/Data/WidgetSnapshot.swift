// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation

/// 桌面小组件（WidgetKit）共享快照。
///
/// 数据通道是 App Group 容器里的 `widget-snapshot.json`：主 App 写、Widget 读，
/// JSON 文件即跨进程协议。本文件同时编入 Flash 与 FlashWidget 两个 target
/// （widget target 经手工 PBXBuildFile 引用本文件，见 project.pbxproj 注释）。
///
/// 已知限制（adhoc 签名）：`com.apple.security.application-groups` 使用未注册组 ID 时
/// 进程会被 secinit 杀死，因此两个 target 的 entitlements 都不声明 App Group。
/// 沙盒 App 未声明组权限时 `containerURL(forSecurityApplicationGroupIdentifier:)`
/// 返回 nil（安全，不崩溃），写入端据此静默 no-op、读取端据此走引导态视图。
/// 数据联通需 Developer ID 签名版本。
public struct WidgetSnapshot: Codable, Equatable, Sendable {
    /// 快照对应的本地日期（yyyy-MM-dd）
    public var recordDate: String
    /// 当日记录（日志 + 灵感）条数
    public var todayLogCount: Int
    /// 今日到期且未完成的待办数
    public var openTaskCount: Int
    /// 今日主导情绪 emoji（当日无情绪记录时为 nil）
    public var dominantEmotionEmoji: String?
    /// 生成时间（ISO-8601）
    public var generatedAt: String

    public init(recordDate: String, todayLogCount: Int, openTaskCount: Int, dominantEmotionEmoji: String? = nil, generatedAt: String) {
        self.recordDate = recordDate
        self.todayLogCount = todayLogCount
        self.openTaskCount = openTaskCount
        self.dominantEmotionEmoji = dominantEmotionEmoji
        self.generatedAt = generatedAt
    }
}

public enum WidgetSnapshotStore: Sendable {
    #if os(iOS)
    public static let groupIdentifier = "group.com.flash.app.ios"
    #else
    public static let groupIdentifier = "group.com.flash.app.macos"
    #endif
    public static let fileName = "widget-snapshot.json"

    /// App Group 容器；未声明组权限（adhoc 构建）时返回 nil，是运行时探测的合法手段
    public static var containerDirectory: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupIdentifier)
    }

    public static func fileURL(in directory: URL) -> URL {
        directory.appendingPathComponent(fileName, isDirectory: false)
    }
}

public enum WidgetSnapshotWriter: Sendable {
    /// 组不可用时静默 no-op（零成本）；写入失败同样静默（小组件是增强能力，不影响主流程）
    public static func write(_ snapshot: WidgetSnapshot) {
        guard let directory = WidgetSnapshotStore.containerDirectory else { return }
        try? write(snapshot, to: directory)
    }

    /// 原子写入；目录注入版，供测试与容器路径解耦
    public static func write(_ snapshot: WidgetSnapshot, to directory: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(snapshot)
        try data.write(to: WidgetSnapshotStore.fileURL(in: directory), options: .atomic)
    }
}

public enum WidgetSnapshotReader: Sendable {
    /// 组不可用 / 文件缺失 / JSON 损坏均回退 nil，由 Widget 侧走引导态视图
    public static func read() -> WidgetSnapshot? {
        guard let directory = WidgetSnapshotStore.containerDirectory else { return nil }
        return read(from: directory)
    }

    public static func read(from directory: URL) -> WidgetSnapshot? {
        guard let data = try? Data(contentsOf: WidgetSnapshotStore.fileURL(in: directory)) else { return nil }
        return try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
    }
}
