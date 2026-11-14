import SwiftData

@ModelActor actor LibraryReadActor {
  func reviewSnapshot() throws -> FlashSnapshot {
    FlashSnapshot(
      logs: try modelContext.fetch(FetchDescriptor<LogEntity>()).map { $0.toModel() },
      emotions: try modelContext.fetch(FetchDescriptor<EmotionEntity>()).map { $0.toModel() },
      tasks: [])
  }
  func records(kinds: [LibraryKind]) throws -> [LibraryRecord] {
    let logs =
      kinds.contains(.log) || kinds.contains(.idea)
      ? try modelContext.fetch(FetchDescriptor<LogEntity>()).map { $0.toModel() } : []
    let emotions =
      kinds.contains(.emotion)
      ? try modelContext.fetch(FetchDescriptor<EmotionEntity>()).map { $0.toModel() } : []
    let tasks =
      kinds.contains(.task)
      ? try modelContext.fetch(FetchDescriptor<TaskEntity>()).map { $0.toModel() } : []
    return LibraryRecord.records(.init(logs: logs, emotions: emotions, tasks: tasks)).filter {
      kinds.contains($0.kind)
    }
  }
}
extension FlashRepository {
  @MainActor public func readLibraryRecords(kinds: [LibraryKind] = LibraryKind.allCases)
    async throws -> [LibraryRecord]
  {
    let container = container
    return try await Task.detached {
      try await LibraryReadActor(modelContainer: container).records(kinds: kinds)
    }.value
  }
}

extension FlashRepository {
  @MainActor public func readReviewSnapshot() async throws -> FlashSnapshot {
    let container = container
    return try await Task.detached {
      try await LibraryReadActor(modelContainer: container).reviewSnapshot()
    }.value
  }
}
