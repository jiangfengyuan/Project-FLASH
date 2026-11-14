import FlashCore
import XCTest

@testable import Flash

private struct TestTagProvider: TagSuggestionProvider {
  func suggestions(for text: String, catalog: [PersonalTag], locale: String) async
    -> [TagSuggestion]
  {
    try? await Task.sleep(for: .milliseconds(40))
    return [TagSuggestion(name: text.contains("Travel") ? "Travel" : "Reading")]
  }
}
final class TagAutomationTests: XCTestCase {
  @MainActor func testNewerTextWinsAndUndoPreservesManualTags() async throws {
    let repo = FlashRepository(container: FlashDatabase.makeContainer(inMemory: true))
    var prefs = LibraryPreferences()
    prefs.taggingMode = .organize
    try repo.savePreferences(prefs)
    try repo.addLog(content: "Reading", colorTag: .daily)
    var log = try XCTUnwrap(repo.allLogs().first)
    let key = "log:" + log.id
    let manual = PersonalTag(name: "Personal")
    var draft = TagDraft()
    draft.catalog = [manual]
    draft.selected = [manual.id]
    try repo.saveTagDraft(draft, key: key)
    let coordinator = TagAutomationCoordinator(
      repository: repo, service: TagRecommendationService(provider: TestTagProvider()))
    coordinator.allowed = true
    coordinator.enqueue(key, text: log.content)
    log.content = "Travel"
    try repo.updateLog(log)
    coordinator.enqueue(key, text: log.content)
    for _ in 0..<50 {
      if coordinator.message != nil { break }
      try await Task.sleep(for: .milliseconds(20))
    }
    let after = try repo.tagDraft(for: key)
    XCTAssertTrue(after.selected.contains(manual.id))
    XCTAssertTrue(after.catalog.contains { $0.name == "Travel" && after.automatic.contains($0.id) })
    XCTAssertFalse(after.catalog.contains { $0.name == "Reading" })
    coordinator.undoLast()
    XCTAssertEqual(try repo.tagDraft(for: key).selected, [manual.id])
  }
  @MainActor func testDeletionAndBackgroundCancelInFlightWork() async throws {
    let repo = FlashRepository(container: FlashDatabase.makeContainer(inMemory: true))
    var prefs = LibraryPreferences()
    prefs.taggingMode = .organize
    try repo.savePreferences(prefs)
    try repo.addLog(content: "Reading", colorTag: .daily)
    let key = "log:" + (try XCTUnwrap(repo.allLogs().first?.id))
    let coordinator = TagAutomationCoordinator(
      repository: repo, service: TagRecommendationService(provider: TestTagProvider()))
    coordinator.allowed = true
    coordinator.enqueue(key, text: "Reading")
    coordinator.allowed = false
    _ = try repo.moveToTrash([key])
    coordinator.allowed = true
    try await Task.sleep(for: .milliseconds(180))
    XCTAssertTrue(try repo.tagCatalog().isEmpty)
    XCTAssertTrue(try repo.automaticTagLinks().isEmpty)
    XCTAssertEqual(try repo.trashItems().count, 1)
  }
}
