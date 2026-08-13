import Testing
import Foundation
@testable import Flash

@Suite("BackupService")
struct BackupServiceTests {
    private func sampleLog(id: String = "11111111-1111-1111-1111-111111111111") -> LogItem {
        LogItem(id: id, content: "测试!!", colorTag: .urgent, category: .log,
                importance: 2, createdAt: "2026-08-13T08:00:00.000Z",
                recordDate: "2026-08-13")
    }

    private func sampleEmotion(id: String = "22222222-2222-2222-2222-222222222222") -> EmotionRecord {
        EmotionRecord(id: id, level: .unhappy, subEmotion: .sad, status: nil,
                      note: "雨", recordDate: "2026-08-13",
                      createdAt: "2026-08-13T08:00:00.000Z")
    }

    @Test func exportParseRoundTrip() throws {
        let json = BackupService.exportJSON(logs: [sampleLog()],
                                            emotions: [sampleEmotion()],
                                            appVersion: "0.1.0")
        let preview = try BackupService.parse(json)
        #expect(preview.logCount == 1)
        #expect(preview.emotionCount == 1)
        #expect(preview.skippedLogs == 0)
        #expect(preview.skippedEmotions == 0)
        #expect(preview.logs[0] == sampleLog())
        #expect(preview.emotions[0] == sampleEmotion())
    }

    @Test func exportContainsMetaFields() {
        let json = BackupService.exportJSON(logs: [], emotions: [], appVersion: "0.1.0")
        #expect(json.contains("\"version\" : \"flash-backup-v1\"") || json.contains("\"version\":\"flash-backup-v1\""))
        #expect(json.contains("exportedAt"))
        #expect(json.contains("appVersion"))
        #expect(json.contains("notes"))
    }

    @Test func invalidJSONThrows() {
        #expect(throws: BackupError.invalidJSON) {
            _ = try BackupService.parse("not json")
        }
    }

    @Test func missingVersionThrows() {
        #expect(throws: BackupError.missingVersion) {
            _ = try BackupService.parse("{\"logs\":[],\"emotions\":[]}")
        }
    }

    @Test func incompatibleVersionThrows() {
        #expect(throws: BackupError.incompatibleVersion("v0")) {
            _ = try BackupService.parse("{\"version\":\"v0\",\"logs\":[],\"emotions\":[]}")
        }
    }

    @Test func invalidEntriesSkippedNotFatal() throws {
        let json = """
        {"version":"flash-backup-v1","exportedAt":"2026-08-13T08:00:00.000Z",
        "appVersion":"0.1.0","notes":"",
        "logs":[
          {"id":"bad-id","content":"x","colorTag":"daily","category":"log",
           "importance":0,"createdAt":"2026-08-13T08:00:00.000Z","recordDate":"2026-08-13"},
          {"id":"11111111-1111-1111-1111-111111111111","content":"好","colorTag":"daily",
           "category":"log","importance":99,"createdAt":"2026-08-13T08:00:00.000Z",
           "recordDate":"2026-08-13"}
        ],
        "emotions":[
          {"id":"22222222-2222-2222-2222-222222222222","level":9,"subEmotion":null,
           "status":null,"note":null,"recordDate":"2026-08-13",
           "createdAt":"2026-08-13T08:00:00.000Z"}
        ]}
        """
        let preview = try BackupService.parse(json)
        #expect(preview.skippedLogs == 1)          // 非法 UUID 跳过
        #expect(preview.skippedEmotions == 1)      // level 越界跳过
        #expect(preview.logs.count == 1)
        #expect(preview.logs[0].importance == 4)   // importance 收敛到 0-4
    }

    @Test func unknownColorTagSkipped() throws {
        let json = """
        {"version":"flash-backup-v1","logs":[
          {"id":"11111111-1111-1111-1111-111111111111","content":"x","colorTag":"weird",
           "category":"log","importance":0,"createdAt":"2026-08-13T08:00:00.000Z",
           "recordDate":"2026-08-13"}
        ],"emotions":[]}
        """
        let preview = try BackupService.parse(json)
        #expect(preview.skippedLogs == 1)
        #expect(preview.logs.isEmpty)
    }
}
