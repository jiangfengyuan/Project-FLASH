import Foundation
import SwiftData

extension FlashRepository {
  var supportsV4: Bool { container.schema.entities.contains { $0.name == "LibraryTagEntity" } }
  @MainActor func readLibraryV4(includeLinks: Bool = true) throws -> PersonalLibrary {
    let entity = try context.fetch(FetchDescriptor<PersonalLibraryEntity>()).first
    var value =
      try entity.map { try JSONDecoder().decode(PersonalLibrary.self, from: $0.payload) } ?? .init()
    value.tags = try context.fetch(
      FetchDescriptor<LibraryTagEntity>(sortBy: [SortDescriptor(\.name)])
    ).map { $0.value() }
    value.links = [:]
    if includeLinks {
      for link in try context.fetch(FetchDescriptor<LibraryTagLinkEntity>()) {
        value.links[link.recordKey, default: []].append(link.tagID)
      }
      value.links = value.links.mapValues { $0.sorted() }
    }
    return value
  }
  @MainActor func writeLibraryV4(_ value: PersonalLibrary) throws {
    var metadata = value
    metadata.tags = []
    metadata.links = [:]
    let data = try JSONEncoder().encode(metadata)
    if let entity = try context.fetch(FetchDescriptor<PersonalLibraryEntity>()).first {
      entity.payload = data
    } else {
      context.insert(PersonalLibraryEntity(payload: data))
    }
    let incoming = Dictionary(uniqueKeysWithValues: value.tags.map { ($0.id, $0) })
    var existing = Set<String>()
    for entity in try context.fetch(FetchDescriptor<LibraryTagEntity>()) {
      if let tag = incoming[entity.id] {
        entity.name = tag.name
        existing.insert(entity.id)
      } else {
        context.delete(entity)
      }
    }
    for tag in value.tags where !existing.contains(tag.id) { context.insert(LibraryTagEntity(tag)) }
    var desired = Set(value.links.flatMap { key, ids in ids.map { key + "|" + $0 } })
    for entity in try context.fetch(FetchDescriptor<LibraryTagLinkEntity>()) {
      if desired.remove(entity.id) == nil { context.delete(entity) }
    }
    for (key, ids) in value.links {
      for id in ids where desired.contains(key + "|" + id) {
        context.insert(LibraryTagLinkEntity(recordKey: key, tagID: id))
      }
    }
  }
  @MainActor public func tagCatalog() throws -> [PersonalTag] {
    supportsV4
      ? try context.fetch(FetchDescriptor<LibraryTagEntity>(sortBy: [SortDescriptor(\.name)])).map {
        $0.value()
      } : try personalLibrary().tags
  }
  @MainActor public func tagDraft(for key: String) throws -> TagDraft {
    var draft = TagDraft()
    draft.catalog = try tagCatalog()
    if supportsV4 {
      let rows = try context.fetch(
        FetchDescriptor<LibraryTagLinkEntity>(predicate: #Predicate { $0.recordKey == key }))
      draft.selected = rows.map(\.tagID).sorted()
      draft.automatic = rows.filter(\.automatic).map(\.tagID).sorted()
    } else {
      draft.selected = try personalLibrary().links[key] ?? []
    }
    return draft
  }
  @MainActor func writeTagDraft(_ draft: TagDraft, key: String) throws {
    guard supportsV4 else { return }
    let names = draft.catalog.filter { draft.selected.contains($0.id) }
    guard Set(draft.selected).count == draft.selected.count, draft.selected.count <= 20,
      names.count == draft.selected.count, Set(draft.automatic).count == draft.automatic.count,
      Set(draft.automatic).isSubset(of: Set(draft.selected))
    else { throw BackupError.contract("/tags") }
    var catalog = try tagCatalog()
    for tag in names {
      guard !tag.name.isEmpty, tag.name.unicodeScalars.count <= 80,
        PersonalTag(name: tag.name).name == tag.name, UUID(uuidString: tag.id) != nil
      else { throw BackupError.contract("/tags") }
      if catalog.contains(where: { $0.normalized == tag.normalized && $0.id != tag.id }) {
        throw BackupError.contract("/tags/duplicate")
      }
      if !catalog.contains(where: { $0.id == tag.id }) {
        guard catalog.count < 1000 else { throw BackupError.contract("/tags/limit") }
        context.insert(LibraryTagEntity(tag))
        catalog.append(tag)
      }
    }
    for entity in try context.fetch(
      FetchDescriptor<LibraryTagLinkEntity>(predicate: #Predicate { $0.recordKey == key }))
    { context.delete(entity) }
    for id in draft.selected {
      context.insert(
        LibraryTagLinkEntity(recordKey: key, tagID: id, automatic: draft.automatic.contains(id)))
    }
  }
  @MainActor public func saveTagDraft(_ draft: TagDraft, key: String) throws {
    guard !isTemporaryStore, try textForRecord(key) != nil else {
      throw BackupError.contract("/record")
    }
    try commit(metadataOnly: true) { try writeTagDraft(draft, key: key) }
  }
  @MainActor public func textForRecord(_ key: String) throws -> String? {
    let id = String(
      key.dropFirst(
        key.firstIndex(of: ":").map { key.distance(from: key.startIndex, to: $0) + 1 } ?? key.count)
    )
    if key.hasPrefix("log:") { return try fetchLog(id: id)?.content }
    if key.hasPrefix("task:"), let task = try fetchTask(id: id) {
      return task.title + "\n" + (task.notes ?? "")
    }
    if key.hasPrefix("emotion:"), let emotion = try fetchEmotion(id: id) {
      return emotion.note ?? ""
    }
    return nil
  }
  @MainActor public func preferences() throws -> LibraryPreferences {
    guard supportsV4,
      let entity = try context.fetch(FetchDescriptor<LibraryPreferencesEntity>()).first
    else { return .init() }
    return try JSONDecoder().decode(LibraryPreferences.self, from: entity.payload)
  }
  @MainActor func writePreferences(_ value: LibraryPreferences) throws {
    guard supportsV4 else { return }
    guard (0...365).contains(value.retentionDays) else {
      throw BackupError.contract("/preferences")
    }
    let data = try JSONEncoder().encode(value)
    if let entity = try context.fetch(FetchDescriptor<LibraryPreferencesEntity>()).first {
      entity.payload = data
    } else {
      context.insert(LibraryPreferencesEntity(data))
    }
  }
  @MainActor public func savePreferences(_ value: LibraryPreferences, now: Date = Date()) throws {
    guard !isTemporaryStore else { throw BackupError.temporaryStore }
    let previous = try preferences()
    try commit(metadataOnly: true) {
      try writePreferences(value)
      if previous.retentionDays != value.retentionDays {
        for entity in try context.fetch(FetchDescriptor<TrashEntity>()) {
          var item = try JSONDecoder().decode(TrashItem.self, from: entity.payload)
          item.expiresAt =
            value.retentionDays == 0
            ? nil
            : Calendar.current.date(byAdding: .day, value: value.retentionDays, to: item.deletedAt)
          if item.expired(at: now) {
            context.delete(entity)
          } else {
            entity.expiresAt = item.expiresAt
            entity.payload = try JSONEncoder().encode(item)
          }
        }
      }
    }
  }
  @MainActor public func trashItems(now: Date = Date()) throws -> [TrashItem] {
    guard supportsV4 else { return [] }
    return try context.fetch(
      FetchDescriptor<TrashEntity>(sortBy: [
        SortDescriptor(\.deletedAt, order: .reverse), SortDescriptor(\.id),
      ])
    )
    .filter { $0.expiresAt.map { $0 > now } ?? true }.map {
      try JSONDecoder().decode(TrashItem.self, from: $0.payload)
    }
  }
  @MainActor public func purgeExpiredTrash(now: Date = Date()) throws {
    guard supportsV4, !isTemporaryStore else { return }
    let expired = try context.fetch(FetchDescriptor<TrashEntity>()).filter {
      $0.expiresAt.map { $0 <= now } ?? false
    }
    guard !expired.isEmpty else { return }
    try commit(metadataOnly: true) { for entity in expired { context.delete(entity) } }
  }
  @MainActor public func moveToTrash(_ keys: [String], now: Date = Date()) throws -> [String] {
    guard supportsV4, !isTemporaryStore else { throw BackupError.temporaryStore }
    let library = try personalLibrary(includeLinks: false)
    let days = try preferences().retentionDays
    var ids: [String] = []
    var deletedLogs: [String] = []
    try commit {
      for key in Set(keys) {
        let id = String(key.split(separator: ":", maxSplits: 1).last ?? "")
        let draft = try tagDraft(for: key)
        let tags = draft.catalog.filter { draft.selected.contains($0.id) }
        var item: TrashItem?
        if key.hasPrefix("log:"), let e = try fetchLog(id: id) {
          item = TrashItem(
            log: e.toModel(), tags: tags, reminder: library.reminders.first { $0.id == id },
            days: days, now: now)
          context.delete(e)
          deletedLogs.append(id)
        } else if key.hasPrefix("emotion:"), let e = try fetchEmotion(id: id) {
          item = TrashItem(emotion: e.toModel(), tags: tags, days: days, now: now)
          context.delete(e)
        } else if key.hasPrefix("task:"), let e = try fetchTask(id: id) {
          item = TrashItem(task: e.toModel(), tags: tags, days: days, now: now)
          context.delete(e)
        }
        if var item {
          item.automaticTagIDs = draft.automatic
          context.insert(try TrashEntity(item))
          ids.append(item.id)
          try removeLibraryRecord(key)
        }
      }
    }
    if !deletedLogs.isEmpty { onLogChange?(.deleted(deletedLogs)) }
    return ids
  }
  @MainActor public func restoreTrash(_ ids: [String], asCopy: Bool = false, now: Date = Date())
    throws
  {
    guard supportsV4, !isTemporaryStore else { throw BackupError.temporaryStore }
    let entries = try context.fetch(FetchDescriptor<TrashEntity>()).filter { ids.contains($0.id) }
    var restoredLogs: [LogItem] = []
    try commit {
      for entity in entries {
        let item = try JSONDecoder().decode(TrashItem.self, from: entity.payload)
        guard !item.expired(at: now) else { throw BackupError.contract("/trash/expired") }
        let newID = asCopy ? UUID().uuidString : nil
        var key = item.key
        if var log = item.log {
          guard try asCopy || fetchLog(id: log.id) == nil else {
            throw BackupError.contract(L("原记录仍存在，请恢复为副本"))
          }
          if let newID {
            log = LogItem(
              id: newID, content: log.content, colorTag: log.colorTag, category: log.category,
              importance: log.importance, isFavorite: log.isFavorite, createdAt: log.createdAt,
              recordDate: log.recordDate)
          }
          upsertLogEntity(log)
          restoredLogs.append(log)
          key = "log:" + log.id
        } else if var emotion = item.emotion {
          guard try asCopy || fetchEmotion(id: emotion.id) == nil else {
            throw BackupError.contract(L("原记录仍存在，请恢复为副本"))
          }
          if let newID {
            emotion = EmotionRecord(
              id: newID, level: emotion.level, subEmotion: emotion.subEmotion,
              status: emotion.status, note: emotion.note, intensity: emotion.intensity,
              isFavorite: emotion.isFavorite, recordDate: emotion.recordDate,
              createdAt: emotion.createdAt)
          }
          upsertEmotionEntity(emotion)
          key = "emotion:" + emotion.id
        } else if var task = item.task {
          guard try asCopy || fetchTask(id: task.id) == nil else {
            throw BackupError.contract(L("原记录仍存在，请恢复为副本"))
          }
          if let newID {
            task = TaskItem(
              id: newID, title: task.title, notes: task.notes, colorTag: task.colorTag,
              importance: task.importance, dueKind: task.dueKind, dueDate: task.dueDate,
              dueAt: task.dueAt, timeZone: task.timeZone, reminderAt: task.reminderAt,
              completedAt: task.completedAt, sourceLogId: task.sourceLogId,
              isFavorite: task.isFavorite, createdAt: task.createdAt, updatedAt: task.updatedAt)
          }
          context.insert(TaskEntity(task))
          key = "task:" + task.id
        }
        var draft = TagDraft()
        let catalog = try tagCatalog()
        for tag in item.tags {
          let target = catalog.first { $0.normalized == tag.normalized } ?? tag
          draft.catalog.append(target)
          draft.selected.append(target.id)
          if item.automaticTagIDs.contains(tag.id) { draft.automatic.append(target.id) }
        }
        try writeTagDraft(draft, key: key)
        if var rule = item.reminder, !asCopy {
          rule.enabled = false
          var library = try personalLibrary()
          library.reminders.removeAll { $0.id == rule.id }
          library.reminders.append(rule)
          try writeLibrary(library)
        }
        context.delete(entity)
      }
    }
    if !restoredLogs.isEmpty { onLogChange?(.upserted(restoredLogs)) }
  }
  @MainActor public func permanentlyDeleteTrash(_ ids: [String]) throws {
    guard !isTemporaryStore else { throw BackupError.temporaryStore }
    try commit(metadataOnly: true) {
      for e in try context.fetch(FetchDescriptor<TrashEntity>()) where ids.contains(e.id) {
        context.delete(e)
      }
    }
  }
  @MainActor func writeTrash(_ items: [TrashItem], merge: Bool) throws {
    guard supportsV4 else {
      if !items.isEmpty { throw BackupError.contract("/trash") }
      return
    }
    let existing = try context.fetch(FetchDescriptor<TrashEntity>())
    let ids = Set(existing.map(\.id))
    if !merge { for e in existing { context.delete(e) } }
    for item in items where !item.isExpired && (!merge || !ids.contains(item.id)) {
      context.insert(try TrashEntity(item))
    }
  }
  @MainActor public func automaticTagLinks() throws -> [String: [String]] {
    guard supportsV4 else { return [:] }
    return Dictionary(
      grouping: try context.fetch(FetchDescriptor<LibraryTagLinkEntity>()).filter(\.automatic),
      by: \.recordKey
    ).mapValues { $0.map(\.tagID).sorted() }
  }
}

extension FlashRepository {
  @MainActor func writeAutomaticOrigins(_ links: [String: [String]]) throws {
    guard supportsV4 else { return }
    for row in try context.fetch(FetchDescriptor<LibraryTagLinkEntity>())
    where links[row.recordKey]?.contains(row.tagID) == true { row.automatic = true }
  }
}

extension FlashRepository {
  @MainActor public func deleteLogFromUI(id: String) throws {
    #if os(iOS)
      _ = try moveToTrash(["log:" + id])
    #else
      try deleteLog(id: id)
    #endif
  }
  @MainActor public func deleteEmotionFromUI(id: String) throws {
    #if os(iOS)
      _ = try moveToTrash(["emotion:" + id])
    #else
      try deleteEmotion(id: id)
    #endif
  }
  @MainActor public func deleteTaskFromUI(id: String) throws {
    #if os(iOS)
      _ = try moveToTrash(["task:" + id])
    #else
      try deleteTask(id: id)
    #endif
  }
  @MainActor public func undoLogDeletion(_ log: LogItem) throws {
    #if os(iOS)
      guard let item = try trashItems().first(where: { $0.key == "log:" + log.id }) else {
        throw BackupError.contract(L("记录已过期，无法恢复"))
      }
      try restoreTrash([item.id])
    #else
      try updateLog(log)
    #endif
  }
}
