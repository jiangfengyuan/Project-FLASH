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

    @Test func aggregateDaySinglePassEquivalent() {
        // 单遍分组版与逐日 filter 版结果等价：双侧命中、缺侧为空、组内保持原顺序
        let logs = [log("2026-08-13", content: "a"), log("2026-08-13", content: "b"),
                    log("2026-08-12", content: "c")]
        let emotions = [emotion("2026-08-13", .happy), emotion("2026-08-11", .unhappy)]
        let map = aggregateDay(logs: logs, emotions: emotions)
        #expect(map.count == 3)
        #expect(map["2026-08-13"]?.logs.map(\.content) == ["a", "b"])
        #expect(map["2026-08-13"]?.emotions.count == 1)
        #expect(map["2026-08-12"]?.logs.map(\.content) == ["c"])
        #expect(map["2026-08-12"]?.emotions.isEmpty == true)
        #expect(map["2026-08-11"]?.logs.isEmpty == true)
        #expect(map["2026-08-11"]?.emotions.count == 1)
    }

    // MARK: DateFormatting

    @Test func monthFormatting() {
        #expect(DateFormatting.monthString(today) == "2026-08")
        #expect(CalendarGrid.monthString(today) == "2026-08")  // 委托给 DateFormatting
        #expect(DateFormatting.monthTitle(today) == "2026年8月")
    }

    @Test func localTimeFormatsOrDashes() {
        #expect(DateFormatting.localTime(fromISO: "not-a-date") == "--:--")
        let t = DateFormatting.localTime(fromISO: "2026-08-13T08:00:00.000Z")
        #expect(t.range(of: #"^\d{2}:\d{2}$"#, options: .regularExpression) != nil)
        // 与本地时区参考格式一致（时区无关断言）
        let reference = DateFormatter()
        reference.dateFormat = "HH:mm"
        let parsed = ISO8601DateFormatter()
        parsed.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        #expect(t == reference.string(from: parsed.date(from: "2026-08-13T08:00:00.000Z")!))
    }

    // MARK: DateWindows

    @Test func lastNDaysEndsTodayAscending() {
        let days = DateWindows.lastNDays(7, today: today)
        #expect(days == ["2026-08-07", "2026-08-08", "2026-08-09", "2026-08-10",
                         "2026-08-11", "2026-08-12", "2026-08-13"])
        #expect(DateWindows.lastNDays(0, today: today).isEmpty)
    }

    @Test func currentWeekIsMondayToSunday() {
        // 2026-08-13 是周四 → 本周 08-10（周一）至 08-16（周日）
        let week = DateWindows.currentWeek(today: today)
        #expect(week == ["2026-08-10", "2026-08-11", "2026-08-12", "2026-08-13",
                         "2026-08-14", "2026-08-15", "2026-08-16"])
        // 周日边界：2026-08-16（周日）仍属同一周
        let sunday = DateFormatting.parseDay("2026-08-16")!
        let weekFromSunday = DateWindows.currentWeek(today: sunday)
        #expect(weekFromSunday.first == "2026-08-10")
        #expect(weekFromSunday.last == "2026-08-16")
    }

    // MARK: EmotionStats 舍入与 onDays

    @Test func negativeAverageRoundsHalfUp() {
        // 均值 -0.125：Kotlin Math.round(-12.5)/100 = -0.12（half-up）；
        // 旧实现 .rounded() 是 half-away-from-zero，会得 -0.13
        let emotions = [emotion("2026-08-13", .slightlyUnhappy)] +
            (0..<7).map { _ in emotion("2026-08-13", .neutral) }
        let result = EmotionStats.dailyAverages(emotions, days: 1, today: today)
        #expect(result.count == 1)
        #expect(result[0].average == -0.12)
    }

    @Test func dailyAveragesOnDaysAligns() {
        let emotions = [emotion("2026-08-12", .happy), emotion("2026-08-12", .neutral),
                        emotion("2026-08-13", .unhappy),
                        emotion("2026-08-20", .veryHappy)]  // 不在 onDays 内，应被忽略
        let result = EmotionStats.dailyAverages(emotions,
                                                onDays: ["2026-08-11", "2026-08-12", "2026-08-13"])
        #expect(result.count == 3)
        #expect(result[0] == nil)   // 08-11 无记录
        #expect(result[1] == 1.0)   // (2+0)/2
        #expect(result[2] == -2.0)
    }

    // MARK: GlobalSearch

    @Test func searchIsCaseInsensitiveAcrossTypes() {
        let logs = [log("2026-08-13", content: "Buy Milk",
                        createdAt: "2026-08-13T09:00:00.000Z"),
                    log("2026-08-13", content: "写报告",
                        createdAt: "2026-08-13T11:00:00.000Z")]
        let emotions = [EmotionRecord(id: "e1", level: .happy, subEmotion: nil, status: nil,
                                      note: "milk 心情", recordDate: "2026-08-13",
                                      createdAt: "2026-08-13T10:00:00.000Z")]
        let result = GlobalSearch.search(logs: logs, emotions: emotions, query: "MILK")
        #expect(result.count == 2)
        // createdAt 倒序：情绪(10:00) 在日志(09:00) 前
        #expect(result[0].isEmotion)
        #expect(result[0].title == "😊 milk 心情")
        #expect(!result[1].isEmotion)
        #expect(result[1].title == "Buy Milk")
    }

    @Test func searchMatchesEmotionDisplayNameWhenNoNote() {
        let emotions = [EmotionRecord(id: "e2", level: .veryHappy, subEmotion: nil, status: nil,
                                      note: nil, recordDate: "2026-08-13",
                                      createdAt: "2026-08-13T08:00:00.000Z")]
        let result = GlobalSearch.search(logs: [], emotions: emotions, query: "非常开心")
        #expect(result.count == 1)
        #expect(result[0].title == "😍 非常开心")
    }

    @Test func searchRespectsLimit() {
        let logs = (0..<25).map { i in
            log("2026-08-13", content: "x",
                createdAt: String(format: "2026-08-13T08:%02d:00.000Z", i))
        }
        let result = GlobalSearch.search(logs: logs, emotions: [], query: "x")
        #expect(result.count == 20)
        #expect(result[0].createdAt == "2026-08-13T08:24:00.000Z")  // 最新的在前
        #expect(result.last?.createdAt == "2026-08-13T08:05:00.000Z")
    }

    @Test func searchEmptyQueryReturnsEmpty() {
        // 空查询：localizedCaseInsensitiveContains("") 为 false → 无命中
        let logs = [log("2026-08-13", content: "a", createdAt: "2026-08-13T09:00:00.000Z")]
        let emotions = [emotion("2026-08-13", .happy)]
        #expect(GlobalSearch.search(logs: logs, emotions: emotions, query: "").isEmpty)
    }
}
