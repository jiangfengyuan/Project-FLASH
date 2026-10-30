import Foundation
import SwiftData
import Testing
import FlashCore
@testable import Flash

/// Exercise the iOS FileDocument bytes with the production import pipeline and
/// an isolated on-disk store. This does not claim file-picker UI acceptance.
@MainActor
@Suite("iOS 文件备份与持久化")
struct BackupFileFlowTests {
    @Test func documentBytesImportAndReopenWithoutLosingMetadata() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ios-file-flow-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let source = FlashRepository(container: FlashDatabase.makeContainer(inMemory: true))
        _ = try QuickCaptureCommit.commit("虚构文件往返 🌿", as: .idea, repository: source)
        let idea = try #require(source.allLogs().first)
        try source.setLogFavorite(id: idea.id, true)
        try source.addEmotion(level: .unhappy, subEmotion: .sad, note: "虚构备注", intensity: 4)
        let now = DateFormatting.isoNow()
        try source.saveTask(TaskItem(id: UUID().uuidString, title: "虚构灵感任务", notes: nil,
            colorTag: .memo, importance: 1,
            dueKind: .dateTime, dueDate: nil, dueAt: "2026-11-02T08:00:00.000Z",
            timeZone: "Asia/Kolkata", reminderAt: "2026-11-02T07:50:00.000Z",
            completedAt: nil, sourceLogId: idea.id, isFavorite: true, createdAt: now, updatedAt: now))
        let original = try source.snapshot()
        let json = try await BackupImportCoordinator.exportJSON(snapshot: original, appVersion: "acceptance")
        let document = BackupJSONDocument(json: json)
        let file = directory.appendingPathComponent("backup.json")
        try Data(document.json.utf8).write(to: file)
        let schema = Schema(versionedSchema: FlashSchemaV2.self)
        let storeURL = directory.appendingPathComponent("roundtrip.store")
        func openRepository() throws -> FlashRepository {
            FlashRepository(container: try ModelContainer(for: schema,
                migrationPlan: FlashMigrationPlan.self,
                configurations: [ModelConfiguration(schema: schema, url: storeURL)]))
        }
        do {
            let target = try openRepository()
            let empty = try target.snapshot()
            let preview = try await BackupImportCoordinator.preview(fileAt: file, recovery: false, against: empty)
            _ = try await BackupImportCoordinator.apply(preview, overwrite: true,
                previewSnapshot: empty, repository: target, rebuildReminders: { _ in })
            #expect(try target.snapshot() == original)
        }
        let reopened = try openRepository()
        #expect(try reopened.snapshot() == original)
        #expect(try reopened.allLogs().first?.isFavorite == true)
        let exported = try await BackupImportCoordinator.exportJSON(snapshot: reopened.snapshot(), appVersion: "acceptance")
        let parsed = try BackupService.parseStrict(exported)
        #expect(parsed.logs == original.logs)
        #expect(parsed.emotions == original.emotions)
        #expect(parsed.tasks == original.tasks)
    }
}
