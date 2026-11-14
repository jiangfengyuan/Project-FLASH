import Foundation

public enum LibraryKind: String, Codable, CaseIterable, Sendable { case log, idea, emotion, task }
public struct LibraryRecord: Identifiable, Sendable {
    public var id: String { key }
    public let key: String
    public let kind: LibraryKind
    public let title: String
    public let day: String
    public let createdAt: String
    public let color: String
    public let favorite: Bool
    public let completed: Bool
    public var recordID: String { String(key.dropFirst(key.firstIndex(of: ":").map { key.distance(from: key.startIndex, to: $0) + 1 } ?? 0)) }
    public static func records(_ snapshot: FlashSnapshot) -> [Self] {
        snapshot.logs.map { Self(key: "log:\($0.id)", kind: $0.category == .idea ? .idea : .log, title: $0.content, day: $0.recordDate, createdAt: $0.createdAt, color: $0.colorTag.rawValue, favorite: $0.isFavorite == true, completed: false) } +
        snapshot.emotions.map { Self(key: "emotion:\($0.id)", kind: .emotion, title: [$0.level.emoji, $0.note ?? $0.status ?? ""].joined(separator: " "), day: $0.recordDate, createdAt: $0.createdAt, color: "", favorite: $0.isFavorite == true, completed: false) } +
        snapshot.tasks.map { Self(key: "task:\($0.id)", kind: .task, title: $0.title + ($0.notes.map { "\n" + $0 } ?? ""), day: $0.calendarDate ?? "", createdAt: $0.createdAt, color: $0.colorTag.rawValue, favorite: $0.isFavorite == true, completed: $0.isCompleted) }
    }
}
public struct PersonalTag: Codable, Equatable, Identifiable, Sendable {
    public var id: String = UUID().uuidString
    public var name: String
    public init(name: String) { self.name = name.trimmingCharacters(in: .whitespacesAndNewlines).precomposedStringWithCanonicalMapping }
    public var normalized: String { name.lowercased() }
}
public struct LibraryFilter: Codable, Equatable, Identifiable, Sendable {
    public var id = UUID().uuidString
    public var name = ""
    public var kinds: [LibraryKind] = []
    public var query = ""
    public var tagIDs: [String] = []
    public var matchAll = false
    public var colors: [String] = []
    public var favoritesOnly = false
    public var startDay = ""
    public var endDay = ""
    /// all / open / completed; only applies to tasks
    public var taskStatus = "all"
    public var oldestFirst = false
    public init() {}
    public func apply(_ records: [LibraryRecord], library: PersonalLibrary) -> [LibraryRecord] {
        guard !records.isEmpty else { return [] }
        // Match the catalog once per query; do not scan all tags for every record.
        let matchingTagIDs = query.isEmpty ? Set<String>() : Set(library.tags.filter {
            $0.name.localizedCaseInsensitiveContains(query)
        }.map(\.id))
        let requiredTagIDs = Set(tagIDs)
        return records.filter { r in
            let linked = Set(library.links[r.key] ?? [])
            return (kinds.isEmpty || kinds.contains(r.kind)) &&
            (query.isEmpty || r.title.localizedCaseInsensitiveContains(query) || !matchingTagIDs.isDisjoint(with: linked)) &&
            (tagIDs.isEmpty || (matchAll ? requiredTagIDs.isSubset(of: linked) : !requiredTagIDs.isDisjoint(with: linked))) &&
            (colors.isEmpty || colors.contains(r.color)) && (!favoritesOnly || r.favorite) &&
            (startDay.isEmpty || r.day >= startDay) && (endDay.isEmpty || r.day <= endDay) &&
            (r.kind != .task || taskStatus == "all" || (taskStatus == "completed") == r.completed)
        }.sorted { oldestFirst ? $0.createdAt < $1.createdAt : $0.createdAt > $1.createdAt }
    }
}
public struct PersonalReminder: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var enabled = true
    public var intervalDays = 1
    public var hour = 20
    public var minute = 0
    public var anchorDay: String
    public init(ideaID: String, anchorDay: String = DateFormatting.today()) { id = ideaID; self.anchorDay = anchorDay }
}
public struct PersonalLibrary: Codable, Equatable, Sendable {
    public var tags: [PersonalTag] = []
    public var links: [String: [String]] = [:]
    public var filters: [LibraryFilter] = []
    public var reminders: [PersonalReminder] = []
    public var showEmotions = true
    public var summaryHour = 20
    public var summaryMinute = 0
    public var summaryEnabled = true
    public var summaryIntervalDays = 1
    public var remindersNeedConfirmation = false
    public init() {}
    public mutating func deleteTag(_ id: String) {
        tags.removeAll { $0.id == id }
        links = links.mapValues { $0.filter { $0 != id } }
        filters.removeAll { $0.tagIDs.contains(id) }
    }
    public func validated(records: [LibraryRecord]) throws {
        try validated(recordKeys:Set(records.map(\.key)), ideaIDs:Set(records.filter { $0.kind == .idea }.map(\.recordID)))
    }
    func validated(recordKeys: Set<String>, ideaIDs: Set<String>) throws {
        func require(_ value: Bool) throws { if !value { throw BackupError.contract("/personalLibrary") } }
        try require(tags.count <= 1000 && filters.count <= 100 && reminders.count <= 100_000)
        try require(Set(tags.map(\.id)).count == tags.count && Set(tags.map(\.normalized)).count == tags.count)
        try require(tags.allSatisfy { UUID(uuidString: $0.id) != nil && !$0.name.isEmpty && $0.name.unicodeScalars.count <= 80 && PersonalTag(name: $0.name).name == $0.name })
        let tagSet = Set(tags.map(\.id)), keys = recordKeys, ideas = ideaIDs
        try require(links.allSatisfy { keys.contains($0.key) && $0.value.count <= 20 && Set($0.value).count == $0.value.count && Set($0.value).isSubset(of: tagSet) })
        try require(Set(filters.map(\.id)).count == filters.count)
        try require(filters.allSatisfy { UUID(uuidString: $0.id) != nil && !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && $0.name.unicodeScalars.count <= 80 && ["all", "open", "completed"].contains($0.taskStatus) && $0.tagIDs.count <= 1000 && $0.kinds.count <= 4 && $0.colors.count <= 6 && $0.query.utf16.count <= 100_000 && Set($0.tagIDs).isSubset(of: tagSet) && ($0.startDay.isEmpty || DateFormatting.parseDay($0.startDay) != nil) && ($0.endDay.isEmpty || DateFormatting.parseDay($0.endDay) != nil) && ($0.startDay.isEmpty || $0.endDay.isEmpty || $0.startDay <= $0.endDay) && $0.colors.allSatisfy { ColorTag(rawValue: $0) != nil } })
        try require(Set(reminders.map(\.id)).count == reminders.count)
        try require(reminders.allSatisfy { ideas.contains($0.id) && [1,3,7].contains($0.intervalDays) && (9...21).contains($0.hour) && (0...59).contains($0.minute) && DateFormatting.parseDay($0.anchorDay) != nil })
        try require((9...21).contains(summaryHour) && (0...59).contains(summaryMinute) && [1,3,7].contains(summaryIntervalDays))
    }
    public func merging(_ incoming: Self) -> Self {
        var result = self
        var mapping: [String: String] = [:]
        for tag in incoming.tags {
            if let existing = result.tags.first(where: { $0.normalized == tag.normalized }) { mapping[tag.id] = existing.id }
            else { result.tags.removeAll { $0.id == tag.id }; result.tags.append(tag); mapping[tag.id] = tag.id }
        }
        for (key, tags) in incoming.links { result.links[key] = Array(Set((result.links[key] ?? []) + tags.compactMap { mapping[$0] })).sorted() }
        for var filter in incoming.filters { filter.tagIDs = filter.tagIDs.compactMap { mapping[$0] }; result.filters.removeAll { $0.id == filter.id }; result.filters.append(filter) }
        for rule in incoming.reminders { result.reminders.removeAll { $0.id == rule.id }; result.reminders.append(rule) }
        result.showEmotions = incoming.showEmotions
        result.summaryHour = incoming.summaryHour; result.summaryMinute = incoming.summaryMinute
        result.summaryEnabled = incoming.summaryEnabled; result.summaryIntervalDays = incoming.summaryIntervalDays
        result.remindersNeedConfirmation = incoming != PersonalLibrary() || remindersNeedConfirmation
        return result
    }
}
public enum HistoricalRecall {
    public static func day(before now: Date, months: Int = 0, years: Int = 0, calendar: Calendar = .current) -> String {
        let date = calendar.date(byAdding: DateComponents(year: -years, month: -months), to: now) ?? now
        let c = calendar.dateComponents([.year,.month,.day], from: date)
        return String(format: "%04d-%02d-%02d", c.year!, c.month!, c.day!)
    }
    public static func records(_ records: [LibraryRecord], on day: String, showEmotions: Bool) -> [LibraryRecord] {
        records.filter { $0.kind != .task && $0.day == day && (showEmotions || $0.kind != .emotion) }.sorted { $0.createdAt < $1.createdAt }
    }
}
