import Testing
import SwiftData
@testable import Flash

@Suite("FlashRepository") @MainActor
struct FlashRepositoryTests {
    private func makeRepo() -> FlashRepository {
        FlashRepository(container: FlashDatabase.makeContainer(inMemory: true))
    }

    @Test func addLogAssignsFields() throws {
        let repo = makeRepo()
        try repo.addLog(content: "第一条", colorTag: .daily)
        let logs = try repo.allLogs()
        #expect(logs.count == 1)
        #expect(logs[0].content == "第一条")
        #expect(logs[0].colorTag == .daily)
        #expect(logs[0].category == .log)
        #expect(logs[0].importance == 0)
        #expect(logs[0].recordDate == DateFormatting.today())
        #expect(logs[0].id.count == 36) // UUID
    }

    @Test func importanceCoerced() throws {
        let repo = makeRepo()
        try repo.addLog(content: "x", colorTag: .idea, category: .idea, importance: 99)
        #expect(try repo.allLogs()[0].importance == 4)
    }

    @Test func updateAndDeleteLog() throws {
        let repo = makeRepo()
        try repo.addLog(content: "旧", colorTag: .memo)
        var log = try repo.allLogs()[0]
        log.content = "新"
        log.colorTag = .urgent
        try repo.updateLog(log)
        #expect(try repo.allLogs()[0].content == "新")
        #expect(try repo.allLogs()[0].colorTag == .urgent)
        try repo.deleteLog(id: log.id)
        #expect(try repo.allLogs().isEmpty)
    }

    @Test func addAndDeleteEmotion() throws {
        let repo = makeRepo()
        try repo.addEmotion(level: .unhappy, subEmotion: .sad, note: "下雨")
        let emotions = try repo.allEmotions()
        #expect(emotions.count == 1)
        #expect(emotions[0].level == .unhappy)
        #expect(emotions[0].subEmotion == .sad)
        #expect(emotions[0].note == "下雨")
        try repo.deleteEmotion(id: emotions[0].id)
        #expect(try repo.allEmotions().isEmpty)
    }

    @Test func logsSortedNewestFirst() throws {
        let repo = makeRepo()
        try repo.addLog(content: "A", colorTag: .daily)
        try repo.addLog(content: "B", colorTag: .daily)
        let logs = try repo.allLogs()
        #expect(logs.map(\.content) == ["B", "A"]) // createdAt 降序
    }

    @Test func mergeAllOverwritesSameId() throws {
        let repo = makeRepo()
        try repo.addLog(content: "保留", colorTag: .daily)
        let existing = try repo.allLogs()[0]
        let incoming = LogItem(id: existing.id, content: "覆盖", colorTag: .urgent,
                               category: .log, importance: 2,
                               createdAt: existing.createdAt, recordDate: existing.recordDate)
        let fresh = LogItem(id: "11111111-1111-1111-1111-111111111111", content: "新增",
                            colorTag: .memo, category: .log, importance: 0,
                            createdAt: existing.createdAt, recordDate: existing.recordDate)
        try repo.mergeAll(logs: [incoming, fresh], emotions: [])
        let logs = try repo.allLogs()
        #expect(logs.count == 2)
        #expect(logs.contains { $0.id == existing.id && $0.content == "覆盖" })
    }

    @Test func replaceAllClearsFirst() throws {
        let repo = makeRepo()
        try repo.addLog(content: "被清掉", colorTag: .daily)
        try repo.replaceAll(logs: [], emotions: [])
        #expect(try repo.allLogs().isEmpty)
    }

    @Test func clearAllWorks() throws {
        let repo = makeRepo()
        try repo.addLog(content: "x", colorTag: .daily)
        try repo.addEmotion(level: .happy, subEmotion: nil)
        try repo.clearAll()
        #expect(try repo.allLogs().isEmpty)
        #expect(try repo.allEmotions().isEmpty)
    }
}
