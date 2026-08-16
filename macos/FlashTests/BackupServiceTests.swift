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

    @Test func nonDictionaryEntriesSkippedNotFatal() throws {
        let json = """
        {"version":"flash-backup-v1","logs":[
          {"id":"11111111-1111-1111-1111-111111111111","content":"好","colorTag":"daily",
           "category":"log","importance":0,"createdAt":"2026-08-13T08:00:00.000Z",
           "recordDate":"2026-08-13"},
          42
        ],"emotions":[
          {"id":"22222222-2222-2222-2222-222222222222","level":-2,"subEmotion":"sad",
           "status":null,"note":null,"recordDate":"2026-08-13",
           "createdAt":"2026-08-13T08:00:00.000Z"},
          "oops"
        ]}
        """
        let preview = try BackupService.parse(json)
        #expect(preview.skippedLogs == 1)          // 非字典元素 42 跳过
        #expect(preview.skippedEmotions == 1)      // 非字典元素 "oops" 跳过
        #expect(preview.logs.count == 1)
        #expect(preview.emotions.count == 1)
        #expect(preview.logs[0] == LogItem(id: "11111111-1111-1111-1111-111111111111",
                                           content: "好", colorTag: .daily, category: .log,
                                           importance: 0,
                                           createdAt: "2026-08-13T08:00:00.000Z",
                                           recordDate: "2026-08-13"))
        #expect(preview.emotions[0] == EmotionRecord(id: "22222222-2222-2222-2222-222222222222",
                                                     level: .unhappy, subEmotion: .sad,
                                                     status: nil, note: nil,
                                                     recordDate: "2026-08-13",
                                                     createdAt: "2026-08-13T08:00:00.000Z"))
    }

    // MARK: - F4 补充用例

    /// createdAt 规范化：Android 整秒省略小数（...T08:00:00Z）与本端 .000Z 混合导入，
    /// 统一输出 .withFractionalSeconds 格式，保证字典序 == 时间序（'.' < 'Z'）
    @Test func createdAtNormalizedToFractionalSeconds() throws {
        let json = """
        {"version":"flash-backup-v1","logs":[
          {"id":"11111111-1111-1111-1111-111111111111","content":"a","colorTag":"daily",
           "category":"log","importance":0,"createdAt":"2026-08-13T08:00:00Z",
           "recordDate":"2026-08-13"},
          {"id":"33333333-3333-3333-3333-333333333333","content":"b","colorTag":"daily",
           "category":"log","importance":0,"createdAt":"2026-08-13T08:00:00.900Z",
           "recordDate":"2026-08-13"}
        ],"emotions":[
          {"id":"22222222-2222-2222-2222-222222222222","level":-2,"subEmotion":null,
           "status":null,"note":null,"recordDate":"2026-08-13",
           "createdAt":"2026-08-13T08:00:00Z"}
        ]}
        """
        let preview = try BackupService.parse(json)
        #expect(preview.skippedLogs == 0)
        #expect(preview.skippedEmotions == 0)
        #expect(preview.logs.map(\.createdAt) == ["2026-08-13T08:00:00.000Z",
                                                  "2026-08-13T08:00:00.900Z"])
        #expect(preview.emotions[0].createdAt == "2026-08-13T08:00:00.000Z")
        // 规范化后字典序即时间序：整秒串排在 .900Z 之前（未规范化时 "Z" > "." 会排反）
        #expect(preview.logs.map(\.createdAt).sorted() == ["2026-08-13T08:00:00.000Z",
                                                           "2026-08-13T08:00:00.900Z"])
    }

    /// recordDate 只验格式不够：2026-13-40、2026-02-30 这类不存在的日期必须拒绝
    @Test func invalidRealDateRejected() throws {
        let json = """
        {"version":"flash-backup-v1","logs":[
          {"id":"11111111-1111-1111-1111-111111111111","content":"x","colorTag":"daily",
           "category":"log","importance":0,"createdAt":"2026-08-13T08:00:00.000Z",
           "recordDate":"2026-13-40"}
        ],"emotions":[
          {"id":"22222222-2222-2222-2222-222222222222","level":-2,"subEmotion":null,
           "status":null,"note":null,"recordDate":"2026-02-30",
           "createdAt":"2026-08-13T08:00:00.000Z"}
        ]}
        """
        let preview = try BackupService.parse(json)
        #expect(preview.logs.isEmpty)
        #expect(preview.skippedLogs == 1)
        #expect(preview.emotions.isEmpty)
        #expect(preview.skippedEmotions == 1)
    }

    /// 超 50MB 的输入直接拒绝（对应导入弹窗读入前的 fileSize 预检）
    @Test func oversizedInputThrows() {
        let huge = String(repeating: " ", count: BackupService.maxFileBytes + 1)
        #expect(throws: BackupError.fileTooLarge) {
            _ = try BackupService.parse(huge)
        }
    }
}
