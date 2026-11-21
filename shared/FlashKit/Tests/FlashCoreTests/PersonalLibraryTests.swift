import Foundation
import Testing
import SwiftData
@testable import FlashCore

@Suite @MainActor struct PersonalLibraryTests {
    @Test(arguments: [false, true])
    func ambiguousTagRenameRefusesMergeAtomically(reverseIncomingOrder: Bool) async throws {
        let repo = FlashRepository(container: FlashDatabase.makeContainer(inMemory: true))
        let logID = UUID().uuidString
        try repo.addLog(id: logID, content: "Keep local text", colorTag: .daily)
        let original = PersonalTag(name: "Reading")
        var local = PersonalLibrary()
        local.tags = [original]
        local.links["log:" + logID] = [original.id]
        try repo.savePersonalLibrary(local)
        let before = try repo.snapshot()

        var renamed = original
        renamed.name = "Journal"
        let alias = PersonalTag(name: "Reading")
        var incoming = PersonalLibrary()
        incoming.tags = reverseIncomingOrder ? [renamed, alias] : [alias, renamed]
        incoming.links["log:" + logID] = [alias.id, renamed.id]
        var changedLog = before.logs[0]
        changedLog.content = "Incoming text"
        let file = try LibraryBackup.export(FlashSnapshot(logs: [changedLog], emotions: [], tasks: [],
                                                          library: incoming), appVersion: "test")
        let preview = try await BackupImportCoordinator.preview(text: file, recovery: false, passphrase: nil, against: before)
        var rebuilt = false
        await #expect(throws: BackupError.conflictingLibraryTags) {
            _ = try await BackupImportCoordinator.apply(preview, overwrite: false, previewSnapshot: before,
                                                        repository: repo, rebuildReminders: { _ in rebuilt = true })
        }
        #expect(try repo.snapshot() == before)
        #expect(!rebuilt)
    }

    @Test func tagsFiltersAndEncryptedBackupRoundTrip() async throws {
        let container = FlashDatabase.makeContainer(inMemory:true)
        let repository = FlashRepository(container:container)
        let id = UUID().uuidString
        try repository.addLog(id:id,content:"A remembered idea",colorTag:.idea,category:.idea)
        var value = PersonalLibrary()
        let tag = PersonalTag(name:" 阅读 ")
        value.tags = [tag]; value.links["log:"+id] = [tag.id]
        var filter = LibraryFilter(); filter.name = "Reading"; filter.tagIDs = [tag.id]; value.filters = [filter]
        value.reminders = [PersonalReminder(ideaID:id)]
        try repository.savePersonalLibrary(value)
        let snapshot = try repository.snapshot()
        #expect(snapshot.library == value)
        let text = try await BackupImportCoordinator.exportJSON(snapshot:snapshot,appVersion:"test",passphrase:"test-password")
        let preview = try await BackupImportCoordinator.preview(text:text,recovery:false,passphrase:"test-password",against:snapshot)
        #expect(preview.sourceVersion == LibraryBackup.version)
        #expect(preview.library == value)
        let second = FlashRepository(container:FlashDatabase.makeContainer(inMemory:true))
        _ = try await BackupImportCoordinator.apply(preview,overwrite:false,previewSnapshot:nil,repository:second,rebuildReminders:{ _ in })
        #expect(try second.personalLibrary().tags == value.tags)
        #expect(try second.personalLibrary().remindersNeedConfirmation)
        try second.deleteLog(id:id)
        #expect(try second.personalLibrary().links["log:"+id] == nil)
        #expect(try second.personalLibrary().reminders.isEmpty)
    }
    @Test func strictV3RejectsUnknownMetadataAndDanglingLinks() throws {
        let empty = FlashSnapshot(logs:[],emotions:[],tasks:[])
        let text = try LibraryBackup.export(empty,appVersion:"test")
        var root = try JSONSerialization.jsonObject(with:Data(text.utf8)) as! [String:Any]
        var library = root["personalLibrary"] as! [String:Any]; library["unknown"] = true; root["personalLibrary"] = library
        let unknown = String(decoding:try JSONSerialization.data(withJSONObject:root),as:UTF8.self)
        #expect(throws:BackupError.self) { try BackupService.parseStrict(unknown) }
        var value = PersonalLibrary(); value.links["task:missing"] = []
        #expect(throws:BackupError.self) { try value.validated(records:[]) }
    }
    @Test func filtersAndTagDeletionDoNotBroadenSavedQueries() {
        var library = PersonalLibrary(); let tag = PersonalTag(name:"阅读"); library.tags = [tag]
        var filter = LibraryFilter(); filter.name = "未完成的阅读"; filter.kinds = [.task]; filter.tagIDs = [tag.id]; filter.taskStatus = "open"
        library.filters = [filter]; library.links["task:a"] = [tag.id]
        let a = LibraryRecord(key:"task:a",kind:.task,title:"Book",day:"2026-11-14",createdAt:"a",color:"",favorite:false,completed:false)
        let b = LibraryRecord(key:"task:b",kind:.task,title:"Book",day:"2026-11-14",createdAt:"b",color:"",favorite:false,completed:true)
        #expect(filter.apply([a,b],library:library).map(\.key) == ["task:a"])
        library.deleteTag(tag.id)
        #expect(library.filters.isEmpty)
        #expect(library.links["task:a"] == [])
    }
    @Test func monthEndsAndLeapDay() throws {
        let calendar = Calendar(identifier:.gregorian)
        let leap = try #require(calendar.date(from:DateComponents(year:2024,month:2,day:29,hour:12)))
        #expect(HistoricalRecall.day(before:leap,years:1,calendar:calendar) == "2023-02-28")
        let march = try #require(calendar.date(from:DateComponents(year:2026,month:3,day:31,hour:12)))
        #expect(HistoricalRecall.day(before:march,months:1,calendar:calendar) == "2026-02-28")
    }
    @Test func reminderHasTwoOccurrencesAndHonorsQuietHours() throws {
        let calendar = Calendar.current
        let now = try #require(calendar.date(from:DateComponents(year:2026,month:11,day:14,hour:19)))
        var rule = PersonalReminder(ideaID:"test",anchorDay:"2026-11-14")
        let cycles = PeriodicIdeaPlan.cycles(rule:rule,now:now,calendar:calendar)
        #expect(cycles.count == 28)
        #expect(cycles[1].date.timeIntervalSince(cycles[0].date) == 1800)
        rule.hour = 21; rule.minute = 45
        #expect(PeriodicIdeaPlan.cycles(rule:rule,now:now,calendar:calendar).count == 14)
        rule.enabled = false
        #expect(PeriodicIdeaPlan.cycles(rule:rule,now:now).isEmpty)
    }
    @Test func failedImportRollsBackContentAndMetadataTogether() throws {
        enum Failure: Error { case injected }
        let container = FlashDatabase.makeContainer(inMemory:true)
        let original = FlashRepository(container:container)
        try original.addLog(content:"Keep me",colorTag:.daily)
        var library = PersonalLibrary(); library.tags = [PersonalTag(name:"Keep tag")]
        try original.savePersonalLibrary(library)
        let before = try original.snapshot()
        let failing = FlashRepository(container:container,beforeSave:{ throw Failure.injected })
        #expect(throws:Failure.self) { try failing.replaceAll(logs:[],emotions:[],library:.init()) }
        #expect(try original.snapshot() == before)
    }
    @Test func migrationPersistsExistingRecordsAndMetadata() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("store")
        defer { try? FileManager.default.removeItem(at:url) }
        do {
            let schema = Schema(versionedSchema:FlashSchemaV2.self)
            let container = try ModelContainer(for:schema,configurations:[ModelConfiguration(schema:schema,url:url)])
            let repo = FlashRepository(container:container)
            try repo.addLog(content:"Before migration",colorTag:.daily)
        }
        let result = FlashDatabase.makeContainerWithFallback(storeURL:url)
        #expect(!result.didFallbackToMemory)
        let repository = FlashRepository(container:result.container)
        #expect(try repository.allLogs().first?.content == "Before migration")
        var library = PersonalLibrary(); library.tags = [PersonalTag(name:"Travel")]
        try repository.savePersonalLibrary(library)
        #expect(try repository.personalLibrary() == library)
    }
}
