import Foundation

public enum LibraryBackup {
  public static let legacyVersion = "flash-backup-v3"
  public static let version = "flash-backup-v4"
  public static let supportedVersions = [legacyVersion, version]
  public static func export(_ snapshot: FlashSnapshot, appVersion: String) throws -> String {
    guard !snapshot.isFromTemporaryStore else { throw BackupError.temporaryStore }
    try snapshot.library.validated(records: LibraryRecord.records(snapshot))
    let base = try BackupService.exportStrictJSON(
      logs: snapshot.logs, emotions: snapshot.emotions, tasks: snapshot.tasks,
      appVersion: appVersion)
    var root = try JSONSerialization.jsonObject(with: Data(base.utf8)) as! [String: Any]
    root["version"] = version
    root["personalLibrary"] = try JSONSerialization.jsonObject(
      with: JSONEncoder().encode(snapshot.library))
    try validateV4(
      trash: snapshot.trash, preferences: snapshot.preferences, automatic: snapshot.automaticTags,
      library: snapshot.library)
    root["trash"] = try JSONSerialization.jsonObject(
      with: JSONEncoder().encode(snapshot.trash.filter { !$0.isExpired }))
    root["preferences"] = try JSONSerialization.jsonObject(
      with: JSONEncoder().encode(snapshot.preferences))
    root["automaticTags"] = snapshot.automaticTags
    let text = String(
      decoding: try JSONSerialization.data(
        withJSONObject: root, options: [.sortedKeys, .prettyPrinted]), as: UTF8.self)
    guard text.utf8.count <= BackupService.maxFileBytes else { throw BackupError.fileTooLarge }
    return text
  }
  static func validateV4(
    trash: [TrashItem], preferences: LibraryPreferences, automatic: [String: [String]],
    library: PersonalLibrary
  ) throws {
    guard (0...365).contains(preferences.retentionDays), trash.count <= 100_000,
      Set(trash.map(\.id)).count == trash.count,
      automatic.allSatisfy({
        !$0.value.isEmpty && Set($0.value).count == $0.value.count && library.links[$0.key] != nil
          && Set($0.value).isSubset(of: Set(library.links[$0.key] ?? []))
      })
    else { throw BackupError.contract("/v4") }
    for item in trash {
      guard UUID(uuidString: item.id) != nil,
        [item.log != nil, item.emotion != nil, item.task != nil].filter({ $0 }).count == 1,
        item.expiresAt.map({ $0 >= item.deletedAt }) ?? true,
        Set(item.automaticTagIDs).count == item.automaticTagIDs.count,
        Set(item.automaticTagIDs).isSubset(of: Set(item.tags.map(\.id)))
      else { throw BackupError.contract("/trash") }
      let snapshot = FlashSnapshot(
        logs: item.log.map { [$0] } ?? [], emotions: item.emotion.map { [$0] } ?? [],
        tasks: item.task.map { [$0] } ?? [])
      _ = try BackupService.exportStrictJSON(
        logs: snapshot.logs, emotions: snapshot.emotions, tasks: snapshot.tasks,
        appVersion: "archive-validation")
      var metadata = PersonalLibrary()
      metadata.tags = item.tags
      metadata.links[item.key] = item.tags.map(\.id)
      if let rule = item.reminder { metadata.reminders = [rule] }
      try metadata.validated(records: LibraryRecord.records(snapshot))
    }
  }
  static func parse(_ root: [String: Any]) throws -> ImportPreview {
    let isV4 = root["version"] as? String == version
    let expected = Set(
      ["version", "exportedAt", "appVersion", "notes", "schemas", "data", "personalLibrary"]
        + (isV4 ? ["trash", "preferences", "automaticTags"] : []))
    guard Set(root.keys) == expected, let object = root["personalLibrary"] as? [String: Any] else {
      throw BackupError.contract("/personalLibrary")
    }
    let bytes = try JSONSerialization.data(withJSONObject: object)
    let library: PersonalLibrary
    do { library = try JSONDecoder().decode(PersonalLibrary.self, from: bytes) } catch {
      throw BackupError.contract("/personalLibrary")
    }
    let canonical = try JSONSerialization.jsonObject(with: JSONEncoder().encode(library))
    // Codable validates value types; compare key shapes to also reject unknown fields.
    func check(_ input: Any, _ expected: Any) throws {
      if let a = input as? [String: Any], let b = expected as? [String: Any] {
        guard Set(a.keys) == Set(b.keys) else { throw BackupError.contract("/personalLibrary") }
        for (k, v) in a { try check(v, b[k]!) }
      } else if let a = input as? [Any], let b = expected as? [Any] {
        guard a.count == b.count else { throw BackupError.contract("/personalLibrary") }
        for (v, e) in zip(a, b) { try check(v, e) }
      }
    }
    try check(object, canonical)
    var trash: [TrashItem] = []
    var preferences = LibraryPreferences()
    var automatic: [String: [String]] = [:]
    if isV4 {
      func decode<T: Codable>(_ name: String, as type: T.Type) throws -> T {
        guard let object = root[name] else { throw BackupError.contract("/" + name) }
        do {
          let value = try JSONDecoder().decode(
            T.self, from: JSONSerialization.data(withJSONObject: object))
          try check(object, JSONSerialization.jsonObject(with: JSONEncoder().encode(value)))
          return value
        } catch { throw BackupError.contract("/" + name) }
      }
      trash = try decode("trash", as: [TrashItem].self)
      preferences = try decode("preferences", as: LibraryPreferences.self)
      automatic = try decode("automaticTags", as: [String: [String]].self)
      try validateV4(trash: trash, preferences: preferences, automatic: automatic, library: library)
    }
    var legacy = root
    for field in ["personalLibrary", "trash", "preferences", "automaticTags"] {
      legacy.removeValue(forKey: field)
    }
    legacy["version"] = BackupService.backupVersion
    var preview = try BackupService.parseStrict(
      String(decoding: JSONSerialization.data(withJSONObject: legacy), as: UTF8.self))
    try library.validated(
      records: LibraryRecord.records(
        .init(logs: preview.logs, emotions: preview.emotions, tasks: preview.tasks)))
    preview.sourceVersion = isV4 ? version : legacyVersion
    preview.library = library
    preview.trash = trash.filter { !$0.isExpired }
    preview.preferences = isV4 ? preferences : nil
    preview.automaticTags = automatic
    return preview
  }
}
