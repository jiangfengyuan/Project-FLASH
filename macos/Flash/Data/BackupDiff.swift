// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation

struct DifferenceSummary: Equatable {
    let added: Int
    let changed: Int
    let unchanged: Int
    let localOnly: Int
}

struct BackupDifference: Equatable {
    let logs: DifferenceSummary
    let emotions: DifferenceSummary
}

enum BackupDiff {
    static func analyze(
        localLogs: [LogItem],
        localEmotions: [EmotionRecord],
        incomingLogs: [LogItem],
        incomingEmotions: [EmotionRecord]
    ) -> BackupDifference {
        BackupDifference(
            logs: summarize(local: localLogs, incoming: incomingLogs, id: \.id),
            emotions: summarize(local: localEmotions, incoming: incomingEmotions, id: \.id)
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
