// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation

public struct DifferenceSummary: Equatable, Sendable {
    public let added: Int
    public let changed: Int
    public let unchanged: Int
    public let localOnly: Int

    public init(added: Int, changed: Int, unchanged: Int, localOnly: Int) {
        self.added = added
        self.changed = changed
        self.unchanged = unchanged
        self.localOnly = localOnly
    }
}

public struct BackupDifference: Equatable, Sendable {
    public let logs: DifferenceSummary
    public let emotions: DifferenceSummary
    public let tasks: DifferenceSummary

    public init(logs: DifferenceSummary, emotions: DifferenceSummary, tasks: DifferenceSummary) {
        self.logs = logs
        self.emotions = emotions
        self.tasks = tasks
    }
}

public enum BackupDiff: Sendable {
    public static func analyze(
        localLogs: [LogItem],
        localEmotions: [EmotionRecord],
        incomingLogs: [LogItem],
        incomingEmotions: [EmotionRecord],
        localTasks: [TaskItem] = [],
        incomingTasks: [TaskItem] = []
    ) -> BackupDifference {
        BackupDifference(
            logs: summarize(local: localLogs, incoming: incomingLogs, id: \.id),
            emotions: summarize(local: localEmotions, incoming: incomingEmotions, id: \.id),
            tasks: summarize(local: localTasks, incoming: incomingTasks, id: \.id)
        )
    }

    private static func summarize<T: Equatable>(
        local: [T], incoming: [T], id: KeyPath<T, String>
    ) -> DifferenceSummary {
        let localByID = Dictionary(local.map { ($0[keyPath: id], $0) }, uniquingKeysWith: { _, last in last })
        let incomingByID = Dictionary(incoming.map { ($0[keyPath: id], $0) }, uniquingKeysWith: { _, last in last })
        var added = 0
        var changed = 0
        var unchanged = 0
        for (key, value) in incomingByID {
            guard let current = localByID[key] else { added += 1; continue }
            if current == value { unchanged += 1 } else { changed += 1 }
        }
        return DifferenceSummary(
            added: added,
            changed: changed,
            unchanged: unchanged,
            localOnly: localByID.keys.filter { incomingByID[$0] == nil }.count
        )
    }
}
