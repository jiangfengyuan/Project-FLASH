import Testing
import Foundation
@testable import Flash

@Suite("Domain 纯函数")
struct DomainTests {
    // 夹具：固定 today = 2026-08-13（周四）
    private let today = DateFormatting.parseDay("2026-08-13")!

    private func emotion(_ day: String, _ level: EmotionLevel, sub: SubEmotion? = nil) -> EmotionRecord {
        EmotionRecord(id: UUID().uuidString, level: level, subEmotion: sub,
                      status: nil, note: nil, recordDate: day,
                      createdAt: "\(day)T08:00:00.000Z")
    }

    private func log(_ day: String, content: String = "x", tag: ColorTag = .daily,
                     category: Flash.Category = .log, createdAt: String? = nil) -> LogItem {
        LogItem(id: UUID().uuidString, content: content, colorTag: tag,
                category: category, importance: 0,
                createdAt: createdAt ?? "\(day)T08:00:00.000Z", recordDate: day)
    }

    // MARK: EmotionStats

    @Test func dailyAveragesWithGapDays() {
        let emotions = [emotion("2026-08-13", .veryHappy), emotion("2026-08-13", .slightlyHappy),
                        emotion("2026-08-11", .unhappy)]
        let result = EmotionStats.dailyAverages(emotions, days: 7, today: today)
        #expect(result.count == 7)
        #expect(result[6].date == "2026-08-13")
        #expect(result[6].average == 2.0)   // (3+1)/2
        #expect(result[4].average == -2.0)  // 08-11
        #expect(result[0].average == nil)   // 08-07 无记录
    }

    @Test func subEmotionDistributionOnlyNegative() {
        let emotions = [emotion("2026-08-13", .unhappy, sub: .sad),
                        emotion("2026-08-12", .unhappy, sub: .sad),
                        emotion("2026-08-12", .veryHappy, sub: nil),
                        emotion("2026-08-12", .slightlyUnhappy, sub: .angry)]
        let dist = EmotionStats.subEmotionDistribution(emotions, days: 7, today: today)
        #expect(dist.contains { $0.name == "伤心" && $0.count == 2 })
        #expect(dist.contains { $0.name == "生气" && $0.count == 1 })
        #expect(!dist.contains { $0.name == "难受" })
    }

    @Test func hasEmotionDataRespectsWindow() {
        #expect(EmotionStats.hasEmotionData([emotion("2026-08-13", .happy)], days: 7, today: today))
        #expect(!EmotionStats.hasEmotionData([emotion("2026-08-01", .happy)], days: 7, today: today))
    }

    // MARK: LogFilter

    @Test func filterExcludesIdeasAndMatchesQuery() {
        let logs = [log("2026-08-13", content: "买牛奶"),
                    log("2026-08-13", content: "灵感闪现", category: .idea),
                    log("2026-08-13", content: "写报告")]
        let filtered = LogFilter(query: "牛奶").apply(to: logs)
        #expect(filtered.count == 1)
        #expect(filtered[0].content == "买牛奶")
    }

    @Test func filterByTagsAndDateRange() {
        let logs = [log("2026-08-10", tag: .memo),
                    log("2026-08-12", tag: .urgent),
                    log("2026-08-13", tag: .urgent)]
        let filtered = LogFilter(tags: [.urgent], startDate: "2026-08-11",
                                 endDate: "2026-08-13").apply(to: logs)
        #expect(filtered.count == 2)
    }

    @Test func sortOrders() {
        let logs = [log("2026-08-10", createdAt: "2026-08-10T01:00:00.000Z"),
                    log("2026-08-10", createdAt: "2026-08-10T03:00:00.000Z"),
                    log("2026-08-10", createdAt: "2026-08-10T02:00:00.000Z")]
        let newest = LogFilter(sort: .newest).apply(to: logs)
        #expect(newest[0].createdAt == "2026-08-10T03:00:00.000Z")
        let oldest = LogFilter(sort: .oldest).apply(to: logs)
        #expect(oldest[0].createdAt == "2026-08-10T01:00:00.000Z")
    }

    // MARK: CalendarGrid

    @Test func weeksAreMondayFirstSixRows() {
        // 2026-08-01 是周六 → 网格从 2026-07-27（周一）开始
        let month = DateFormatting.parseDay("2026-08-15")!
        let weeks = CalendarGrid.weeks(containing: month)
        #expect(weeks.count == 6)
        #expect(weeks.allSatisfy { $0.count == 7 })
        #expect(DateFormatting.dayString(weeks[0][0]) == "2026-07-27")
        #expect(DateFormatting.dayString(weeks[5][6]) == "2026-09-06")
    }

    @Test func aggregateByRecordDate() {
        let logs = [log("2026-08-13"), log("2026-08-12")]
        let emotions = [emotion("2026-08-13", .happy)]
        let map = aggregateDay(logs: logs, emotions: emotions)
        #expect(map["2026-08-13"]?.logs.count == 1)
        #expect(map["2026-08-13"]?.emotions.count == 1)
        #expect(map["2026-08-12"]?.emotions.isEmpty == true)
    }
}
