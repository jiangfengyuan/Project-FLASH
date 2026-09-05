import Foundation
import SwiftData
import Testing
@testable import Flash

@Suite("Shared backup contract")
struct BackupContractTests {
    private func fixture(_ name: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent("docs/contracts/fixtures/\(name).json"),
                          encoding: .utf8)
    }

    @Test(arguments: ["valid-minimal", "valid-full"])
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
}
