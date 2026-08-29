// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Testing
@testable import Flash

@Suite("BackupDiff")
struct BackupDiffTests {
    private func log(_ id: String, _ content: String) -> LogItem {
        LogItem(id: id, content: content, colorTag: .daily, category: .log,
                importance: 0, createdAt: "2026-08-29T00:00:00.000Z", recordDate: "2026-08-29")
    }

    @Test func separatesAddedChangedUnchangedAndLocalOnlyRecords() {
        let local = [log("same", "A"), log("changed", "old"), log("local", "L")]
        let incoming = [log("same", "A"), log("changed", "new"), log("added", "N")]
        let difference = BackupDiff.analyze(
            localLogs: local, localEmotions: [], incomingLogs: incoming, incomingEmotions: [])

        #expect(difference.logs == DifferenceSummary(added: 1, changed: 1, unchanged: 1, localOnly: 1))
        #expect(difference.emotions == DifferenceSummary(added: 0, changed: 0, unchanged: 0, localOnly: 0))
    }
}
