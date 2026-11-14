import Foundation

public enum TaggingMode: String, Codable, CaseIterable, Sendable {
  case suggest, existing, organize
  public var title: String {
    switch self {
    case .suggest: L("推荐后点选采用")
    case .existing: L("自动应用已有标签")
    case .organize: L("保存后自动整理")
    }
  }
}
public struct LibraryPreferences: Codable, Equatable, Sendable {
  public var taggingMode: TaggingMode = .suggest
  /// Zero means explicit never-expire.
  public var retentionDays = 30
  public init() {}
}
public struct TagDraft: Equatable, Sendable {
  public var catalog: [PersonalTag] = []
  public var selected: [String] = []
  public var automatic: [String] = []
  public init() {}
  public func applying(
    _ suggestions: [TagSuggestion], mode: TaggingMode, excluding: Set<String> = []
  ) -> TagDraft {
    guard mode != .suggest else { return self }
    var result = self
    if mode == .organize {
      result.selected.removeAll { automatic.contains($0) }
      result.automatic = []
    }
    for suggestion in suggestions where mode == .organize || suggestion.existingID != nil {
      let candidate = PersonalTag(name: suggestion.name)
      guard !candidate.name.isEmpty, !excluding.contains(candidate.normalized) else { continue }
      let tag = result.catalog.first { $0.normalized == candidate.normalized } ?? candidate
      guard result.selected.count < 20 else { break }
      if !result.catalog.contains(where: { $0.id == tag.id }) { result.catalog.append(tag) }
      if !result.selected.contains(tag.id) {
        result.selected.append(tag.id)
        result.automatic.append(tag.id)
      }
    }
    return result
  }
}
public struct TrashItem: Codable, Equatable, Identifiable, Sendable {
  public var id = UUID().uuidString
  public var deletedAt: Date
  public var expiresAt: Date?
  public var log: LogItem?
  public var emotion: EmotionRecord?
  public var task: TaskItem?
  public var tags: [PersonalTag]
  public var automaticTagIDs: [String] = []
  public var reminder: PersonalReminder?
  public var key: String {
    if let log { return "log:" + log.id }
    if let emotion { return "emotion:" + emotion.id }
    return "task:" + (task?.id ?? "")
  }
  public var title: String {
    log?.content ?? emotion?.note ?? emotion?.level.emoji ?? task?.title ?? ""
  }
  public var isExpired: Bool { expired(at: Date()) }
  public func expired(at now: Date) -> Bool { expiresAt.map { $0 <= now } ?? false }
  public init(
    log: LogItem? = nil, emotion: EmotionRecord? = nil, task: TaskItem? = nil,
    tags: [PersonalTag] = [], reminder: PersonalReminder? = nil, days: Int, now: Date = Date()
  ) {
    self.log = log
    self.emotion = emotion
    self.task = task
    self.tags = tags
    self.reminder = reminder
    deletedAt = now
    expiresAt = days == 0 ? nil : Calendar.current.date(byAdding: .day, value: days, to: now)
  }
}
public enum RecordTemplate: String, CaseIterable, Identifiable, Sendable {
  case daily, reading, idea, emotion
  public var id: String { rawValue }
  public var title: String {
    switch self {
    case .daily: L("每日三句话")
    case .reading: L("读书摘记")
    case .idea: L("灵感整理")
    case .emotion: L("情绪复盘")
    }
  }
  public var body: String {
    switch self {
    case .daily: L("今天发生了什么：\n\n有什么感受：\n\n明天想做什么：\n")
    case .reading: L("书名与作者：\n\n摘录：\n\n我的理解：\n")
    case .idea: L("想到什么：\n\n为什么有用：\n\n下一步可以做什么：\n")
    case .emotion: L("发生了什么：\n\n我怎么理解：\n\n现在需要什么：\n")
    }
  }
  public var category: Category { self == .idea ? .idea : .log }
  public static func containsOnlyPrompts(_ text: String) -> Bool {
    let normalized = text.filter { !$0.isWhitespace }
    return allCases.contains { $0.body.filter { !$0.isWhitespace } == normalized }
  }
}
public struct TagSuggestion: Equatable, Sendable {
  public let name: String
  public let existingID: String?
  public init(name: String, existingID: String? = nil) {
    self.name = name
    self.existingID = existingID
  }
}
public protocol TagSuggestionProvider: Sendable {
  func suggestions(for text: String, catalog: [PersonalTag], locale: String) async
    -> [TagSuggestion]
}
/// No network or model dependency; preserves the user's language and tag names.
public struct KeywordTagProvider: TagSuggestionProvider {
  public init() {}
  public func suggestions(for text: String, catalog: [PersonalTag], locale: String) async
    -> [TagSuggestion]
  {
    let lower = text.lowercased()
    func contains(_ word: String) -> Bool {
      if word.unicodeScalars.allSatisfy({ $0.isASCII }) {
        let pattern =
          "(?<![\\p{L}\\p{N}])" + NSRegularExpression.escapedPattern(for: word)
          + "(?![\\p{L}\\p{N}])"
        return lower.range(of: pattern, options: .regularExpression) != nil
      }
      return lower.contains(word)
    }
    var names = catalog.filter { contains($0.normalized) }.map(\.name)
    let zh = locale.hasPrefix("zh")
    for (name, en, words) in [
      ("阅读", "Reading", ["读书", "阅读", "书籍", "摘录", "book", "reading"]),
      ("工作", "Work", ["工作", "会议", "项目", "work", "meeting", "project"]),
      ("旅行", "Travel", ["旅行", "出游", "酒店", "机票", "travel", "flight", "hotel"]),
      ("饮食", "Food", ["美食", "餐厅", "早餐", "午餐", "晚餐", "food", "restaurant", "meal"]),
      ("学习", "Learning", ["学习", "课程", "笔记", "study", "learn", "course"]),
      ("运动", "Exercise", ["运动", "跑步", "健身", "run", "gym", "exercise"]),
    ] {
      if words.contains(where: contains) { names.append(zh ? name : en) }
    }
    return Self.resolve(names, catalog: catalog)
  }
  public static func resolve(_ names: [String], catalog: [PersonalTag]) -> [TagSuggestion] {
    var seen = Set<String>()
    return names.compactMap { raw in
      let tag = PersonalTag(name: raw)
      guard !tag.name.isEmpty, tag.name.unicodeScalars.count <= 80,
        seen.insert(tag.normalized).inserted
      else { return nil }
      let existing = catalog.first { $0.normalized == tag.normalized }
      return TagSuggestion(name: existing?.name ?? tag.name, existingID: existing?.id)
    }.prefix(3).map { $0 }
  }
}
