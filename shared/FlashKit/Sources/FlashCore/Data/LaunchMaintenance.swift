// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation

/// 启动维护（iOS / macOS 共用）：刷新小组件快照、按任务表重建系统提醒。
///
/// 内存降级（`repository.isTemporaryStore`）时整体跳过：临时库是空的，
/// 按它重建会撤掉用户全部真实提醒、把小组件归零（F-07）。真实数据仍在磁盘上，
/// 下次正常启动时再按真实任务表重建。
public enum LaunchMaintenance {
    public enum Outcome: Equatable, Sendable {
        /// 已刷新小组件并重建提醒
        case completed
        /// 临时存储：未做任何会改写磁盘外状态的操作
        case skippedTemporaryStore
    }

    /// - Parameter rebuildReminders: 测试注入替身；默认走 `TaskReminderScheduler.shared.rebuild`
    @MainActor
    @discardableResult
    public static func run(repository: FlashRepository,
                           rebuildReminders: (([TaskItem]) async throws -> Void)? = nil) async throws -> Outcome {
        guard !repository.isTemporaryStore else { return .skippedTemporaryStore }
        // 小组件共享快照：App Group 不可用（未签名构建）时零成本 no-op
        WidgetSnapshot.refresh(repository: repository)
        let tasks = try Perf.measure("TasksForReminderRebuild") { try repository.tasksOnly() }
        if let rebuildReminders {
            try await rebuildReminders(tasks)
        } else {
            try await TaskReminderScheduler.shared.rebuild(tasks)
        }
        return .completed
    }
}
