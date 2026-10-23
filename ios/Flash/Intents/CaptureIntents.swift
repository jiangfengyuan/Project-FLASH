// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import AppIntents
import FlashCore

/// 快速记录类型（快捷指令参数）
enum CaptureCategory: String, AppEnum {
    case idea, log

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "记录类型"
    static let caseDisplayRepresentations: [CaptureCategory: DisplayRepresentation] = [
        .idea: DisplayRepresentation(title: "灵感", image: .init(systemName: "lightbulb")),
        .log: DisplayRepresentation(title: "日志", image: .init(systemName: "square.and.pencil")),
    ]

    var model: Category {
        switch self {
        case .idea: .idea
        case .log: .log
        }
    }
}

/// 「记一闪」：不打开 App，直接把一段文字记为灵感或日志（Siri / 快捷指令 / 操作按钮）。
/// 保存规则与 App 内快速记录同源（QuickCaptureCommit）。
struct CaptureFlashIntent: AppIntent {
    static let title: LocalizedStringResource = "记一闪"
    static let description = IntentDescription("把刚闪过的念头直接记到 Flash，无需打开应用。")

    @Parameter(title: "内容", requestValueDialog: "现在想记录什么？")
    var text: String

    @Parameter(title: "类型", default: .idea)
    var category: CaptureCategory

    static var parameterSummary: some ParameterSummary {
        Summary("把 \(\.$text) 记为 \(\.$category)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let repository = IntentBridge.repository else { throw CaptureIntentError.storageUnavailable }
        switch try QuickCaptureCommit.commit(text, as: category.model, repository: repository) {
        case .saved(let toast):
            return .result(dialog: "\(toast)")
        case .empty:
            throw CaptureIntentError.empty
        case .tooLong(let message):
            throw CaptureIntentError.tooLong(message)
        }
    }
}

/// 打开 Flash 并直接进入快速记录面板（控制中心 / 锁屏控件 / 操作按钮 / 快捷指令）
struct OpenQuickCaptureIntent: AppIntent {
    static let title: LocalizedStringResource = "打开快速记录"
    static let description = IntentDescription("打开 Flash 的快速记录面板。")
    static let openAppWhenRun = true

    @Parameter(title: "类型", default: .idea)
    var category: CaptureCategory

    @MainActor
    func perform() async throws -> some IntentResult {
        IntentBridge.appState?.presentQuickCapture(category: category.model)
        return .result()
    }
}

enum CaptureIntentError: Error, CustomLocalizedStringResourceConvertible {
    case storageUnavailable
    case empty
    case tooLong(String)

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .storageUnavailable: "Flash 存储暂不可用，请打开应用后重试"
        case .empty: "内容为空，没有记录"
        case .tooLong(let message): "\(message)"
        }
    }
}

/// Siri 与「快捷指令」App 中的预置短语
struct FlashShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: OpenQuickCaptureIntent(),
                    phrases: ["用 \(.applicationName) 记一闪",
                              "在 \(.applicationName) 记录灵感",
                              "Quick capture in \(.applicationName)"],
                    shortTitle: "快速记录",
                    systemImageName: "sparkle")
        AppShortcut(intent: CaptureFlashIntent(),
                    phrases: ["用 \(.applicationName) 记下一个念头"],
                    shortTitle: "记一闪",
                    systemImageName: "square.and.pencil")
    }
}
