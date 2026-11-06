import Foundation
import SwiftData
import Testing
@testable import FlashCore

@Suite("Shared backup contract")
struct BackupContractTests {
    private func fixture(_ name: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            // app/shared/FlashKit/Tests/FlashCoreTests/<file> → app/
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent("docs/contracts/fixtures/\(name).json"),
                          encoding: .utf8)
    }

    @Test(arguments: ["valid-minimal", "valid-full", "valid-schema2"])
    func sharedFixturesRoundTripWithoutLoss(_ name: String) throws {
        let json = try fixture(name)
        let root = try #require(JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any])
        let data = try #require(root["data"] as? [String: [[String: Any]]])
        let imported = try BackupService.parse(json)
        #expect(imported.skippedLogs + imported.skippedEmotions + imported.skippedTasks == 0)
        #expect(imported.logs.map(\.id) == data["logs"]?.compactMap { $0["id"] as? String })
        #expect(imported.emotions.map(\.id) == data["emotions"]?.compactMap { $0["id"] as? String })
        #expect(imported.tasks.map(\.id) == data["tasks"]?.compactMap { $0["id"] as? String })
        let exported = try BackupService.exportStrictJSON(logs: imported.logs, emotions: imported.emotions,
                                               tasks: imported.tasks, appVersion: "contract-test")
        let roundTrip = try BackupService.parse(exported)
        #expect(roundTrip.logs == imported.logs)
        #expect(roundTrip.emotions == imported.emotions)
        #expect(roundTrip.tasks == imported.tasks)
        #expect(roundTrip.skippedLogs + roundTrip.skippedEmotions + roundTrip.skippedTasks == 0)
    }

    @Test func sharedStrictCorpus() throws {
        struct Case: Decodable { let file: String; let valid: Bool }
        let cases = try JSONDecoder().decode([Case].self, from: Data(fixture("cases").utf8))
        for item in cases {
            let json = try fixture(String(item.file.dropLast(5)))
            if item.valid {
                let result = try BackupService.parseStrict(json)
                #expect(result.skippedLogs + result.skippedEmotions + result.skippedTasks == 0, "\(item.file)")
            } else {
                #expect(throws: (any Error).self, "\(item.file)") { _ = try BackupService.parseStrict(json) }
            }
        }
    }

    @Test @MainActor func sharedMergeAndOverwriteResults() throws {
        let local = try BackupService.parseStrict(fixture("merge-local"))
        let incoming = try BackupService.parseStrict(fixture("merge-incoming"))
        let repo = FlashRepository(container: FlashDatabase.makeContainer(inMemory: true))
        try repo.replaceAll(logs: local.logs, emotions: local.emotions, tasks: local.tasks)
        try repo.mergeAll(logs: incoming.logs, emotions: incoming.emotions, tasks: incoming.tasks)
        func check(_ name: String) throws {
            let expected = try BackupService.parseStrict(fixture(name))
            #expect(try repo.allLogs().sorted { $0.id < $1.id } == expected.logs.sorted { $0.id < $1.id })
            #expect(try repo.allEmotions().sorted { $0.id < $1.id } == expected.emotions.sorted { $0.id < $1.id })
            #expect(try repo.allTasks().sorted { $0.id < $1.id } == expected.tasks.sorted { $0.id < $1.id })
        }
        try check("merge-expected")
        try repo.replaceAll(logs: incoming.logs, emotions: incoming.emotions, tasks: incoming.tasks)
        try check("overwrite-expected")
    }

    @Test func recoveryIsExplicit() throws {
        let json = try fixture("invalid-importance-range")
        #expect(throws: (any Error).self) { _ = try BackupService.parseStrict(json) }
        #expect(try BackupService.parseRecovery(json).skippedLogs == 1)
        #expect(throws: (any Error).self) { _ = try BackupService.parseRecovery(fixture("invalid-unknown-section")) }
    }

    @Test func strictExportRejectsInvalidDataAndNormalizesTimes() throws {
        let input = try BackupService.parseStrict(fixture("valid-full"))
        var log = try #require(input.logs.first)
        log.importance = 9
        #expect(throws: (any Error).self) {
            _ = try BackupService.exportStrictJSON(logs: [log], emotions: [], appVersion: "test")
        }
        log.importance = 2
        log.createdAt = "2026-09-05T08:00:00.123456789+08:00"
        let json = try BackupService.exportStrictJSON(logs: [log], emotions: [], appVersion: "test")
        #expect(try BackupService.parseStrict(json).logs.first?.createdAt == "2026-09-05T00:00:00.123Z")
    }

    @Test func sharedLegacyFixtureMigratesWithoutTasks() throws {
        let imported = try BackupService.parse(fixture("legacy-v1"))
        #expect(imported.sourceVersion == BackupService.legacyBackupVersion)
        #expect(imported.logs.count == 1)
        #expect(imported.tasks.isEmpty)
    }

    /// 契约 0.2.0：分区版本声明记录结构。schema 1 分区禁止新字段；schema 2 字段有取值规则。
    @Test func schema2VersionDeclaresStructure() throws {
        let json = try fixture("valid-schema2")
        let strict = try BackupService.parseStrict(json)
        #expect(strict.logs.first?.isFavorite == true)
        #expect(strict.logs.last?.isFavorite == nil)
        #expect(strict.emotions.first?.intensity == 4)
        #expect(strict.tasks.first?.sourceLogId == "55555555-5555-4555-8555-555555555555")

        // schema 1 分区携带新字段 → 严格入口拒绝（不静默丢弃）
        var root = try #require(JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any])
        root["schemas"] = ["logs": 1, "emotions": 1, "tasks": 1]
        let downgraded = String(decoding: try JSONSerialization.data(withJSONObject: root), as: UTF8.self)
        #expect(throws: (any Error).self) { _ = try BackupService.parseStrict(downgraded) }
    }

    @Test func schema2FieldValueRules() throws {
        let json = try fixture("valid-schema2")
        func mutated(_ mutate: (inout [String: Any]) -> Void) throws -> String {
            var root = try #require(JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any])
            mutate(&root)
            return String(decoding: try JSONSerialization.data(withJSONObject: root), as: UTF8.self)
        }
        // intensity 越界 / 类型错误
        let badIntensity = try mutated { root in
            var data = root["data"] as! [String: Any]
            var emotions = data["emotions"] as! [[String: Any]]
            emotions[0]["intensity"] = 6
            data["emotions"] = emotions
            root["data"] = data
        }
        #expect(throws: (any Error).self) { _ = try BackupService.parseStrict(badIntensity) }
        #expect(try BackupService.parse(badIntensity).skippedEmotions == 1)
        // isFavorite 非布尔
        let badFavorite = try mutated { root in
            var data = root["data"] as! [String: Any]
            var logs = data["logs"] as! [[String: Any]]
            logs[0]["isFavorite"] = "yes"
            data["logs"] = logs
            root["data"] = data
        }
        #expect(throws: (any Error).self) { _ = try BackupService.parseStrict(badFavorite) }
        #expect(try BackupService.parse(badFavorite).skippedLogs == 1)
        // sourceLogId 非 UUID 外形
        let badSource = try mutated { root in
            var data = root["data"] as! [String: Any]
            var tasks = data["tasks"] as! [[String: Any]]
            tasks[0]["sourceLogId"] = "not-a-uuid"
            data["tasks"] = tasks
            root["data"] = data
        }
        #expect(throws: (any Error).self) { _ = try BackupService.parseStrict(badSource) }
        #expect(try BackupService.parse(badSource).skippedTasks == 1)
    }
}
