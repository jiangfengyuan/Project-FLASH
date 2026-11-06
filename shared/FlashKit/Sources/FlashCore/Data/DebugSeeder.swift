// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

#if DEBUG
import Foundation

/// 确定性合成数据集：性能基线与大数据集手工验证共用（DEBUG 专用，不进 Release）。
/// 用法：`FLASH_SEED_SYNTHETIC=10000` 启动即灌注 1 万日志 / 5 千情绪 / 2 千任务（仅当库为空）。
public enum SyntheticDataset: Sendable {
    /// 确定性 LCG，保证多次运行的数据集完全一致（基线可比）
    public struct Lcg: RandomNumberGenerator, Sendable {
        public var state: UInt64
        public mutating func next() -> UInt64 {
            state = state &* 6364136223846793005 &+ 1442695040888963407
            return state >> 33
        }

        public init(state: UInt64) {
            self.state = state
        }
    }

    private static let sampleContents = [
        "完成了今天的 UI 设计稿", "和朋友吃饭聊天", "读完一章《设计中的设计》",
        "想做一个新的 App 概念", "晨跑五公里", "整理了摄影素材", "写了一篇周记",
        "看了一部纪录片", "调试了一个顽固的 bug", "给妈妈打了电话"
    ]
    private static let sampleTags = ColorTag.allCases
    private static let sampleLevels = EmotionLevel.allCases

    /// 生成 spreadDays 天内的合成数据；数量按比例 logs:emotions:tasks = 10:5:2
    /// 确定性 UUID 形式的 id（v4 版本位 + 变体位），保证合成数据能通过 flash-backup-v2 严格导出校验；
    /// kind 写入变体段首位区分日志 / 情绪 / 任务，同一序号在三分区间不冲突
    static func seedID(kind: Int, _ index: Int) -> String {
        String(format: "00000000-0000-4000-%X000-%012X", kind, index)
    }

    public static func generate(logs logCount: Int, spreadDays: Int = 540
    ) -> (logs: [LogItem], emotions: [EmotionRecord], tasks: [TaskItem]) {
        var rng = Lcg(state: 0xF1A5)
        let calendar = Calendar(identifier: .gregorian)
        let today = Date()
        let emotionCount = logCount / 2
        let taskCount = logCount / 5

        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        func dayString(offsetDaysBack offset: Int) -> String {
            let date = calendar.date(byAdding: .day, value: -offset, to: today)!
            return DateFormatting.dayString(date)
        }
        func iso(offsetDaysBack offset: Int, hour: Int) -> String {
            let day = calendar.date(byAdding: .day, value: -offset, to: today)!
            let date = calendar.date(bySettingHour: hour, minute: Int(rng.next() % 60), second: 0, of: day)!
            return isoFormatter.string(from: date)
        }

        let logs: [LogItem] = (0..<logCount).map { i in
            let offset = Int(rng.next() % UInt64(spreadDays))
            return LogItem(
                id: seedID(kind: 0x8, i),
                content: sampleContents[Int(rng.next()) % sampleContents.count] + " #\(i % 97)",
                colorTag: sampleTags[Int(rng.next()) % sampleTags.count],
                category: rng.next() % 4 == 0 ? .idea : .log,
                importance: [0, 0, 0, 2, 3, 4][Int(rng.next() % 6)],
                createdAt: iso(offsetDaysBack: offset, hour: Int(rng.next() % 14) + 7),
                recordDate: dayString(offsetDaysBack: offset)
            )
        }
        let emotions: [EmotionRecord] = (0..<emotionCount).map { i in
            let offset = Int(rng.next() % UInt64(spreadDays))
            return EmotionRecord(
                id: seedID(kind: 0x9, i),
                level: sampleLevels[Int(rng.next()) % sampleLevels.count],
                subEmotion: nil,
                status: nil,
                note: rng.next() % 3 == 0 ? "合成备注 #\(i % 31)" : nil,
                recordDate: dayString(offsetDaysBack: offset),
                createdAt: iso(offsetDaysBack: offset, hour: Int(rng.next() % 14) + 7)
            )
        }
        let tasks: [TaskItem] = (0..<taskCount).map { i in
            let offset = Int(rng.next() % UInt64(spreadDays / 2))
            let done = rng.next() % 2 == 0
            return TaskItem(
                id: seedID(kind: 0xA, i),
                title: "合成任务 #\(i)",
                notes: nil,
                colorTag: sampleTags[Int(rng.next()) % sampleTags.count],
                importance: [0, 0, 2, 3, 4][Int(rng.next() % 5)],
                dueKind: .allDay,
                dueDate: dayString(offsetDaysBack: offset),
                dueAt: nil,
                timeZone: nil,
                reminderAt: nil,
                completedAt: done ? iso(offsetDaysBack: offset, hour: 20) : nil,
                createdAt: iso(offsetDaysBack: offset, hour: 9),
                updatedAt: iso(offsetDaysBack: offset, hour: 21)
            )
        }
        return (logs, emotions, tasks)
    }
}

public enum DebugSeeder: Sendable {
    public static let environmentKey = "FLASH_SEED_SYNTHETIC"

    /// 环境变量触发灌注；仅当三表皆空时执行，避免污染真实数据
    @MainActor
    public static func seedIfRequested(repository: FlashRepository) {
        guard let raw = ProcessInfo.processInfo.environment[environmentKey],
              let count = Int(raw), count > 0 else { return }
        do {
            let existing = try repository.snapshot()
            guard existing.logs.isEmpty, existing.emotions.isEmpty, existing.tasks.isEmpty else {
                print("[DebugSeeder] 数据库非空，跳过灌注")
                return
            }
            let data = SyntheticDataset.generate(logs: count)
            try repository.seedBulk(logs: data.logs, emotions: data.emotions, tasks: data.tasks)
            print("[DebugSeeder] 已灌注 logs=\(data.logs.count) emotions=\(data.emotions.count) tasks=\(data.tasks.count)")
        } catch {
            print("[DebugSeeder] 灌注失败：\(error)")
        }
    }
}
#endif
