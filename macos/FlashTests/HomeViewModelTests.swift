// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import Testing
@testable import Flash

/// HomeViewModel：今日口径、最近闪念、情绪快照与 update 守卫
struct HomeViewModelTests {

    private func log(_ id: String, category: Flash.Category = .log, recordDate: String,
                     createdAt: String) -> LogItem {
        LogItem(id: id, content: "内容 \(id)", colorTag: .daily, category: category,
                importance: 0, createdAt: createdAt, recordDate: recordDate)
    }

    private func emotion(_ id: String, level: EmotionLevel, recordDate: String,
                         createdAt: String) -> EmotionRecord {
        EmotionRecord(id: id, level: level, subEmotion: nil, status: nil, note: nil,
                      recordDate: recordDate, createdAt: createdAt)
    }

    private let today = Date()
    private var todayString: String { DateFormatting.today() }

    @Test func todayCountsSplitByCategory() {
        let vm = HomeViewModel(logs: [
            log("a", recordDate: todayString, createdAt: "2026-10-06T01:00:00.000Z"),
            log("b", category: .idea, recordDate: todayString, createdAt: "2026-10-06T02:00:00.000Z"),
            log("c", recordDate: "2001-01-01", createdAt: "2001-01-01T00:00:00.000Z")
        ], today: today)
        #expect(vm.todayRecordCount == 2)
        #expect(vm.todayIdeaCount == 1)
    }

    @Test func recentLogsTakesFirstSixInGivenOrder() {
        let logs = (1...8).map { log("\($0)", recordDate: todayString, createdAt: "2026-10-06T0\($0 % 10):00:00.000Z") }
        let vm = HomeViewModel(logs: logs, today: today)
        #expect(vm.recentLogs.count == 6)
        #expect(vm.recentLogs.first?.id == "1")
        #expect(vm.recentLogs.last?.id == "6")
    }

    @Test func placeholderSnapshotWhenNoEmotions() {
        let vm = HomeViewModel(logs: [], emotions: [], today: today)
        #expect(vm.emotionSnapshot.title == "还没有记录")
        #expect(vm.emotionSnapshot.points.allSatisfy { $0 == nil })
    }

    @Test func emotionSnapshotUsesLatestEmotionAndWeeklyPoints() {
        let vm = HomeViewModel(emotions: [
            emotion("e1", level: .happy, recordDate: todayString, createdAt: "2026-10-06T01:00:00.000Z")
        ], today: today)
        #expect(vm.emotionSnapshot.emoji == EmotionLevel.happy.emoji)
        #expect(vm.emotionSnapshot.title == EmotionLevel.happy.displayName)
        // 本周 7 个点对齐周一到周日；今天有记录的点 = level 2 + 3 = 5
        let days = DateWindows.currentWeek(today: today)
        #expect(vm.emotionSnapshot.points.count == 7)
        if let index = days.firstIndex(of: todayString) {
            #expect(vm.emotionSnapshot.points[index] == 5)
        } else {
            Issue.record("today 不在 currentWeek 内")
        }
    }

    @Test func updateWithIdenticalDataKeepsDerivedState() {
        let logs = [log("a", recordDate: todayString, createdAt: "2026-10-06T01:00:00.000Z")]
        let vm = HomeViewModel(logs: logs, today: today)
        let snapshotBefore = vm.emotionSnapshot.title
        vm.update(logs: logs, emotions: [], today: today)
        #expect(vm.todayRecordCount == 1)
        #expect(vm.emotionSnapshot.title == snapshotBefore)
    }

    @Test func updateWithNewDataRecomputes() {
        let vm = HomeViewModel(logs: [], today: today)
        #expect(vm.todayRecordCount == 0)
        vm.update(logs: [log("a", recordDate: todayString, createdAt: "2026-10-06T01:00:00.000Z")], emotions: [], today: today)
        #expect(vm.todayRecordCount == 1)
        #expect(vm.recentLogs.first?.id == "a")
    }
}
