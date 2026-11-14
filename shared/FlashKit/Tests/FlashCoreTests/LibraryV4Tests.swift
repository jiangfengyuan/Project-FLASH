import Foundation
import SwiftData
import Testing

@testable import FlashCore

@Suite @MainActor struct LibraryV4Tests {
  private func repository() -> FlashRepository {
    FlashRepository(container: FlashDatabase.makeContainer(inMemory: true))
  }
  private func task() -> TaskItem {
    TaskItem(
      id: UUID().uuidString, title: "Read a book", notes: "Page 42", colorTag: .memo, importance: 2,
      dueKind: .allDay, dueDate: "2026-11-14", isFavorite: true,
      createdAt: "2026-11-14T08:00:00.000Z", updatedAt: "2026-11-14T08:00:00.000Z")
  }
  @Test func batchTrashRestoresAllKindsAndMetadata() throws {
    let repo = repository()
    try repo.addLog(content: "Daily entry", colorTag: .daily)
    try repo.addLog(content: "Reading idea", colorTag: .idea, category: .idea)
    try repo.addEmotion(level: .happy, subEmotion: nil, note: "A good walk", intensity: 4)
    try repo.saveTask(task())
    let before = try repo.snapshot()
    let idea = try #require(before.logs.first { $0.category == .idea })
    var library = PersonalLibrary()
    let tag = PersonalTag(name: "Reading")
    library.tags = [tag]
    library.reminders = [PersonalReminder(ideaID: idea.id)]
    let keys = LibraryRecord.records(before).map(\.key)
    for key in keys { library.links[key] = [tag.id] }
    try repo.savePersonalLibrary(library)
    var draft = try repo.tagDraft(for: "log:" + idea.id)
    draft.automatic = [tag.id]
    try repo.saveTagDraft(draft, key: "log:" + idea.id)
    let ids = try repo.moveToTrash(keys)
    #expect(ids.count == 4)
    #expect(try repo.snapshot().logs.isEmpty)
    #expect(try repo.snapshot().emotions.isEmpty)
    #expect(try repo.snapshot().tasks.isEmpty)
    #expect(try repo.personalLibrary().links.isEmpty)
    try repo.restoreTrash(ids)
    let after = try repo.snapshot()
    #expect(Set(after.logs.map(\.id)) == Set(before.logs.map(\.id)))
    #expect(after.emotions == before.emotions)
    #expect(after.tasks == before.tasks)
    #expect(after.library.links == library.links)
    #expect(after.library.reminders.first?.enabled == false)
    #expect(after.automaticTags["log:" + idea.id] == [tag.id])
    #expect(after.trash.isEmpty)
  }
  @Test func trashAndPreferencesSurviveReopeningStore() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let url = directory.appendingPathComponent("library.store")
    var archivedID = ""
    do {
      let result = FlashDatabase.makeContainerWithFallback(storeURL: url)
      #expect(!result.didFallbackToMemory)
      let repo = FlashRepository(container: result.container)
      try repo.addLog(content: "Persist through restart", colorTag: .daily)
      let id = try #require(repo.allLogs().first?.id)
      var prefs = LibraryPreferences()
      prefs.retentionDays = 0
      prefs.taggingMode = .organize
      try repo.savePreferences(prefs)
      archivedID = try #require(repo.moveToTrash(["log:" + id]).first)
    }
    let result = FlashDatabase.makeContainerWithFallback(storeURL: url)
    #expect(!result.didFallbackToMemory)
    let repo = FlashRepository(container: result.container)
    #expect(try repo.preferences().retentionDays == 0)
    #expect(try repo.preferences().taggingMode == .organize)
    #expect(try repo.trashItems().first?.id == archivedID)
    try repo.restoreTrash([archivedID])
    #expect(try repo.allLogs().first?.content == "Persist through restart")
  }
  @Test func retentionAndExpirationAreDeterministic() throws {
    let repo = repository()
    let now = Date()
    try repo.addLog(content: "Expires", colorTag: .daily)
    let id = try #require(repo.allLogs().first?.id)
    let start = Calendar.current.date(byAdding: .day, value: -10, to: now)!
    _ = try repo.moveToTrash(["log:" + id], now: start)
    #expect(try repo.trashItems(now: now).count == 1)
    var prefs = LibraryPreferences()
    prefs.retentionDays = 7
    try repo.savePreferences(prefs, now: now)
    #expect(try repo.trashItems(now: start).isEmpty)  // physically purged, not only hidden
    prefs.retentionDays = 366
    #expect(throws: BackupError.self) { try repo.savePreferences(prefs) }
    #expect(try repo.preferences().retentionDays == 7)
  }
  @Test func restorationConflictIsAtomicAndCanCreateCopy() throws {
    let repo = repository()
    try repo.addLog(content: "Original", colorTag: .daily)
    let log = try #require(repo.allLogs().first)
    let ids = try repo.moveToTrash(["log:" + log.id])
    try repo.addLog(id: log.id, content: "Newer existing content", colorTag: .daily)
    #expect(throws: BackupError.self) { try repo.restoreTrash(ids) }
    #expect(try repo.trashItems().count == 1)
    #expect(try repo.allLogs().first?.content == "Newer existing content")
    try repo.restoreTrash(ids, asCopy: true)
    #expect(try repo.allLogs().count == 2)
    #expect(try repo.trashItems().isEmpty)
  }
  @Test func failedDeletionRollsBackArchiveContentAndLinks() throws {
    enum Failure: Error { case injected }
    let container = FlashDatabase.makeContainer(inMemory: true)
    let repo = FlashRepository(container: container)
    try repo.addLog(content: "Keep me", colorTag: .daily)
    let before = try repo.snapshot()
    let key = "log:" + before.logs[0].id
    let failing = FlashRepository(container: container, beforeSave: { throw Failure.injected })
    #expect(throws: Failure.self) { try failing.moveToTrash([key]) }
    #expect(try failing.snapshot() == before)
  }
  @Test func v3MigrationNormalizesTagsWithoutChangingContent() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let url = directory.appendingPathComponent("library.store")
    var before: FlashSnapshot!
    do {
      let schema = Schema(versionedSchema: FlashSchemaV3.self)
      let container = try ModelContainer(
        for: schema, configurations: [ModelConfiguration(schema: schema, url: url)])
      let repo = FlashRepository(container: container)
      try repo.addLog(content: "Before v4", colorTag: .idea, category: .idea)
      let id = try #require(repo.allLogs().first?.id)
      var library = PersonalLibrary()
      let tag = PersonalTag(name: "阅读")
      library.tags = [tag]
      library.links["log:" + id] = [tag.id]
      library.reminders = [PersonalReminder(ideaID: id)]
      try repo.savePersonalLibrary(library)
      before = try repo.snapshot()
    }
    let result = FlashDatabase.makeContainerWithFallback(storeURL: url)
    #expect(!result.didFallbackToMemory)
    let repo = FlashRepository(container: result.container)
    #expect(try repo.snapshot() == before)
    #expect(try result.container.mainContext.fetchCount(FetchDescriptor<LibraryTagEntity>()) == 1)
    #expect(
      try result.container.mainContext.fetchCount(FetchDescriptor<LibraryTagLinkEntity>()) == 1)
    #expect(try repo.automaticTagLinks().isEmpty)
  }
  @Test func mergeMapsAutomaticTagIDsAndPreservesManualChoices() throws {
    let repo = repository()
    try repo.addLog(content: "Reading", colorTag: .daily)
    let key = "log:" + (try #require(repo.allLogs().first?.id))
    let localTag = PersonalTag(name: "Reading")
    let remoteTag = PersonalTag(name: "reading")
    var local = PersonalLibrary()
    local.tags = [localTag]
    local.links[key] = [localTag.id]
    try repo.savePersonalLibrary(local)
    var incoming = PersonalLibrary()
    incoming.tags = [remoteTag]
    incoming.links[key] = [remoteTag.id]
    try repo.mergeAll(
      logs: [], emotions: [], library: incoming, automaticTags: [key: [remoteTag.id]])
    #expect(try repo.tagDraft(for: key).selected == [localTag.id])
    #expect(try repo.tagDraft(for: key).automatic.isEmpty)
    var draft = try repo.tagDraft(for: key)
    draft.selected = []
    try repo.saveTagDraft(draft, key: key)
    try repo.mergeAll(
      logs: [], emotions: [], library: incoming, automaticTags: [key: [remoteTag.id]])
    #expect(try repo.tagDraft(for: key).automatic == [localTag.id])
  }
  @Test func metadataOnlyEditsDoNotAdvanceContentRevision() throws {
    let repo = repository()
    let contentRevision = repo.contentRevision
    var library = PersonalLibrary()
    library.tags = [PersonalTag(name: "Work")]
    try repo.savePersonalLibrary(library)
    var prefs = LibraryPreferences()
    prefs.taggingMode = .existing
    try repo.savePreferences(prefs)
    #expect(repo.contentRevision == contentRevision)
    #expect(repo.revision > 0)
    var invalid = library
    invalid.links["task:" + UUID().uuidString] = []
    #expect(throws: BackupError.self) { try repo.savePersonalLibrary(invalid) }
  }
  @Test func v4BackupRoundTripAndStrictRejection() async throws {
    let repo = repository()
    var prefs = LibraryPreferences()
    prefs.retentionDays = 0
    prefs.taggingMode = .existing
    try repo.savePreferences(prefs)
    try repo.addLog(content: "Archived idea", colorTag: .idea, category: .idea)
    let id = try #require(repo.allLogs().first?.id)
    var library = PersonalLibrary()
    let tag = PersonalTag(name: "阅读")
    library.tags = [tag]
    library.links["log:" + id] = [tag.id]
    try repo.savePersonalLibrary(library)
    var draft = try repo.tagDraft(for: "log:" + id)
    draft.automatic = [tag.id]
    try repo.saveTagDraft(draft, key: "log:" + id)
    try repo.addLog(content: "Archived daily", colorTag: .daily)
    try repo.addEmotion(level: .happy, subEmotion: nil, note: "Archived emotion", intensity: 3)
    try repo.saveTask(task())
    _ = try repo.moveToTrash(LibraryRecord.records(try repo.snapshot()).map(\.key))
    try repo.addLog(content: "Still active", colorTag: .daily)
    let activeKey = "log:" + (try #require(repo.allLogs().first?.id))
    draft.selected = [tag.id]
    try repo.saveTagDraft(draft, key: activeKey)

    let snapshot = try repo.snapshot()
    let text = try LibraryBackup.export(snapshot, appVersion: "v4-test")
    if let path = ProcessInfo.processInfo.environment["FLASH_V4_FIXTURE"] {
      try text.write(toFile: path, atomically: true, encoding: .utf8)
    }
    let preview = try BackupService.parseStrict(text)
    #expect(preview.trash == snapshot.trash)
    #expect(preview.preferences == prefs)
    #expect(preview.automaticTags == snapshot.automaticTags)
    let target = repository()
    _ = try await BackupImportCoordinator.apply(
      preview, overwrite: true, previewSnapshot: try target.snapshot(), repository: target,
      rebuildReminders: { _ in })
    #expect(try target.trashItems() == snapshot.trash)
    try target.restoreTrash(snapshot.trash.map(\.id))
    #expect(try target.allLogs().contains { $0.content == "Archived idea" })
    #expect(try target.allEmotions().count == 1)
    #expect(try target.allTasks().count == 1)
    var root = try JSONSerialization.jsonObject(with: Data(text.utf8)) as! [String: Any]
    var trash = root["trash"] as! [[String: Any]]
    trash[0]["unexpected"] = true
    root["trash"] = trash
    let bad = String(decoding: try JSONSerialization.data(withJSONObject: root), as: UTF8.self)
    #expect(throws: BackupError.self) { try BackupService.parseStrict(bad) }
  }
  @Test func suggestionsRespectManualTagsAndModes() async {
    let reading = PersonalTag(name: "Reading")
    let manual = PersonalTag(name: "Personal")
    var draft = TagDraft()
    draft.catalog = [reading, manual]
    draft.selected = [manual.id]
    let suggestions = [
      TagSuggestion(name: "Reading", existingID: reading.id), TagSuggestion(name: "Travel"),
    ]
    #expect(draft.applying(suggestions, mode: .suggest) == draft)
    let existing = draft.applying(suggestions, mode: .existing)
    #expect(Set(existing.selected) == [manual.id, reading.id])
    #expect(existing.catalog.count == 2)
    let organized = existing.applying([TagSuggestion(name: "Work")], mode: .organize)
    #expect(organized.selected.contains(manual.id))
    #expect(!organized.selected.contains(reading.id))
    #expect(organized.automatic.count == 1)
    #expect(
      draft.applying(suggestions, mode: .existing, excluding: [reading.normalized]).selected == [
        manual.id
      ])
    let keywords = await KeywordTagProvider().suggestions(
      for: "Reading a book while traveling", catalog: [reading], locale: "en")
    #expect(keywords.first?.existingID == reading.id)
    #expect(
      KeywordTagProvider.resolve([" Reading ", "READING", "旅行", "工作", "学习"], catalog: [reading])
        .count == 3)
  }
  @Test func reviewAxesHaveUniqueBoundedTicksForEveryWindow() {
    for window in ReviewWindow.allCases {
      let days = EmotionStats.dailyAverages([], days: window.days(today: Date()), today: Date())
        .map(\.date)
      for maximum in [2, 4] {
        let ticks = ReviewDateAxis.ticks(days, maximum: maximum)
        #expect(ticks.count <= maximum)
        #expect(Set(ticks).count == ticks.count)
        #expect(ticks.first == days.first)
        #expect(ticks.last == days.last)
      }
    }
  }
  @Test func templatesRemainOrdinaryEditableText() {
    #expect(RecordTemplate.allCases.count == 4)
    for template in RecordTemplate.allCases {
      #expect(RecordTemplate.containsOnlyPrompts(template.body))
      #expect(!RecordTemplate.containsOnlyPrompts(template.body + "A real reflection"))
    }
    #expect(RecordTemplate.idea.category == .idea)
    #expect(RecordTemplate.emotion.category == .log)
  }
}

private actor CountingTagProvider: TagSuggestionProvider {
  var calls = 0
  func suggestions(for text: String, catalog: [PersonalTag], locale: String) async
    -> [TagSuggestion]
  {
    calls += 1
    try? await Task.sleep(for: .milliseconds(40))
    return Task.isCancelled ? [] : [TagSuggestion(name: text)]
  }
}
@Suite struct TagRecommendationServiceTests {
  @Test func cacheAndCancellationDoNotReturnStaleResults() async {
    let provider = CountingTagProvider()
    let service = TagRecommendationService(provider: CountingTagProvider())
    let cached = TagRecommendationService(provider: provider)
    _ = await cached.suggestions(text: "Reading", catalog: [], locale: "en")
    _ = await cached.suggestions(text: "Reading", catalog: [], locale: "en")
    #expect(await provider.calls == 1)
    let old = Task { await service.suggestions(text: "Old", catalog: [], locale: "en") }
    try? await Task.sleep(for: .milliseconds(5))
    old.cancel()
    let fresh = await service.suggestions(text: "New", catalog: [], locale: "en")
    #expect(await old.value.isEmpty)
    #expect(fresh.map(\.name) == ["New"])
  }
}
