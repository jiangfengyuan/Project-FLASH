// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import CoreFoundation

enum BackupError: Error, Equatable {
    case invalidJSON
    case missingVersion
    case incompatibleVersion(String)
    case invalidArray(String)
    case invalidObject(String)
    case contract(String)
    case fileTooLarge

    var userMessage: String {
        switch self {
        case .invalidJSON: "备份文件不是有效的 JSON 对象"
        case .missingVersion: "备份版本不兼容：缺少 version 字段"
        case .incompatibleVersion(let v): "备份版本不兼容：期望 flash-backup-v2 或 v1，实际 \(v)"
        case .invalidArray(let name): "\(name) 必须是数组"
        case .invalidObject(let name): "\(name) 必须是对象"
        case .contract(let path): "\(path)：不符合备份契约，请检查文件或使用恢复入口"
        case .fileTooLarge: "文件过大，不是有效的备份"
        }
    }
}

struct ImportPreview {
    let logCount: Int
    let emotionCount: Int
    let skippedLogs: Int
    let skippedEmotions: Int
    let taskCount: Int
    let skippedTasks: Int
    let logs: [LogItem]
    let emotions: [EmotionRecord]
    let tasks: [TaskItem]
    let sourceVersion: String
    var difference: BackupDifference? = nil
}

/// JSONSerialization keeps only one value for duplicate object keys. Scan the
/// original text first so the strict importer can reject that ambiguity.
private struct StrictJSONScanner {
    private let scalars: [Unicode.Scalar]
    private var index = 0

    init(_ text: String) { scalars = Array(text.unicodeScalars) }

    mutating func validate() throws {
        try value(depth: 0)
        whitespace()
        guard index == scalars.count else { throw BackupError.invalidJSON }
    }

    private mutating func value(depth: Int) throws {
        whitespace()
        guard depth <= 128, index < scalars.count else { throw BackupError.invalidJSON }
        switch scalars[index].value {
        case 0x7B: // {
            index += 1
            if take(0x7D) { return }
            var keys = Set<[UInt16]>()
            repeat {
                whitespace()
                let key = try string()
                guard keys.insert(key).inserted else { throw BackupError.contract("/：JSON 对象包含重复键") }
                try expect(0x3A)
                try value(depth: depth + 1)
            } while take(0x2C)
            try expect(0x7D)
        case 0x5B: // [
            index += 1
            if take(0x5D) { return }
            repeat { try value(depth: depth + 1) } while take(0x2C)
            try expect(0x5D)
        case 0x22: _ = try string()
        case 0x74: try literal("true")
        case 0x66: try literal("false")
        case 0x6E: try literal("null")
        default: try number()
        }
    }

    private mutating func string() throws -> [UInt16] {
        guard index < scalars.count, scalars[index].value == 0x22 else { throw BackupError.invalidJSON }
        index += 1
        var result: [UInt16] = []
        while index < scalars.count {
            let scalar = scalars[index]
            index += 1
            if scalar.value == 0x22 { return result }
            guard scalar.value >= 0x20 else { throw BackupError.invalidJSON }
            if scalar.value != 0x5C {
                result.append(contentsOf: String(scalar).utf16)
                continue
            }
            guard index < scalars.count else { throw BackupError.invalidJSON }
            let escape = scalars[index].value
            index += 1
            switch escape {
            case 0x22, 0x5C, 0x2F: result.append(UInt16(escape))
            case 0x62: result.append(0x08)
            case 0x66: result.append(0x0C)
            case 0x6E: result.append(0x0A)
            case 0x72: result.append(0x0D)
            case 0x74: result.append(0x09)
            case 0x75:
                var codeUnit: UInt16 = 0
                for _ in 0..<4 {
                    guard index < scalars.count, let digit = hex(scalars[index].value) else {
                        throw BackupError.invalidJSON
                    }
                    codeUnit = codeUnit &* 16 &+ digit
                    index += 1
                }
                result.append(codeUnit)
            default: throw BackupError.invalidJSON
            }
        }
        throw BackupError.invalidJSON
    }

    private func hex(_ value: UInt32) -> UInt16? {
        switch value {
        case 0x30...0x39: UInt16(value - 0x30)
        case 0x41...0x46: UInt16(value - 0x41 + 10)
        case 0x61...0x66: UInt16(value - 0x61 + 10)
        default: nil
        }
    }

    private mutating func number() throws {
        if current == 0x2D { index += 1 }
        guard index < scalars.count else { throw BackupError.invalidJSON }
        if current == 0x30 { index += 1 } else { try digits() }
        if current == 0x2E { index += 1; try digits() }
        if current == 0x65 || current == 0x45 {
            index += 1
            if current == 0x2B || current == 0x2D { index += 1 }
            try digits()
        }
    }

    private mutating func digits() throws {
        let start = index
        while let value = current, (0x30...0x39).contains(value) { index += 1 }
        guard index > start else { throw BackupError.invalidJSON }
    }

    private mutating func literal(_ text: String) throws {
        for scalar in text.unicodeScalars {
            guard index < scalars.count, scalars[index] == scalar else { throw BackupError.invalidJSON }
            index += 1
        }
    }

    private var current: UInt32? { index < scalars.count ? scalars[index].value : nil }
    private mutating func whitespace() {
        while let value = current, value == 0x20 || value == 0x09 || value == 0x0A || value == 0x0D { index += 1 }
    }
    private mutating func take(_ value: UInt32) -> Bool {
        whitespace()
        guard current == value else { return false }
        index += 1
        return true
    }
    private mutating func expect(_ value: UInt32) throws {
        guard take(value) else { throw BackupError.invalidJSON }
    }
}

/// JSON 备份导出/导入，格式与 Android Backup.kt 完全一致。
/// v2 使用 schemas + data 分区 envelope，读取端继续兼容 v1（v1 没有任务）。
/// 非法条目跳过而非整体失败。
enum BackupService {
    static let backupVersion = "flash-backup-v2"
    static let legacyBackupVersion = "flash-backup-v1"
    private static let sectionSchemaVersion = 1
    static let maxFileBytes = 50 * 1024 * 1024
    private static let maxEntryCount = 100_000
    private static let maxTextLength = 100_000

    private static let uuidRegex = try! NSRegularExpression(
        pattern: "^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$")
    private static let dayRegex = try! NSRegularExpression(pattern: "^\\d{4}-\\d{2}-\\d{2}$")

    // ISO8601DateFormatter 文档保证线程安全，提取共享实例避免逐条 new（对齐 DateFormatting 的 nonisolated(unsafe) 模式）
    nonisolated(unsafe) private static let isoFractionFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    nonisolated(unsafe) private static let isoWholeSecondFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    // MARK: - Export

    static func exportJSON(logs: [LogItem], emotions: [EmotionRecord], tasks: [TaskItem] = [],
                           notes: String = "", appVersion: String) -> String {
        let logDicts: [[String: Any]] = logs.map { log in
            ["id": log.id, "content": log.content, "colorTag": log.colorTag.rawValue,
             "category": log.category.rawValue, "importance": log.importance,
             "createdAt": normalizeISODate(log.createdAt) ?? log.createdAt, "recordDate": log.recordDate]
        }
        let emotionDicts: [[String: Any]] = emotions.map { e in
            ["id": e.id, "level": e.level.rawValue,
             "subEmotion": e.subEmotion?.rawValue ?? NSNull(),
             "status": e.status ?? NSNull(), "note": e.note ?? NSNull(),
             "recordDate": e.recordDate, "createdAt": normalizeISODate(e.createdAt) ?? e.createdAt]
        }
        let taskDicts: [[String: Any]] = tasks.map { task in
            let due: [String: Any]
            switch task.dueKind {
            case .allDay:
                due = ["kind": task.dueKind.rawValue, "date": task.dueDate ?? NSNull()]
            case .dateTime:
                due = ["kind": task.dueKind.rawValue,
                       "at": normalizedForExport(task.dueAt),
                       "timeZone": task.timeZone ?? NSNull()]
            }
            return [
                "id": task.id, "title": task.title, "notes": task.notes ?? NSNull(),
                "colorTag": task.colorTag.rawValue, "importance": task.importance,
                "due": due,
                "reminderAt": normalizedForExport(task.reminderAt),
                "completedAt": normalizedForExport(task.completedAt),
                "createdAt": normalizeISODate(task.createdAt) ?? task.createdAt,
                "updatedAt": normalizeISODate(task.updatedAt) ?? task.updatedAt,
            ]
        }
        let root: [String: Any] = [
            "version": backupVersion,
            "exportedAt": DateFormatting.isoNow(),
            "appVersion": appVersion,
            "notes": notes,
            "schemas": ["logs": sectionSchemaVersion,
                        "emotions": sectionSchemaVersion,
                        "tasks": sectionSchemaVersion],
            "data": ["logs": logDicts, "emotions": emotionDicts, "tasks": taskDicts],
        ]
        let data = try! JSONSerialization.data(withJSONObject: root,
                                               options: [.prettyPrinted, .sortedKeys])
        return String(decoding: data, as: UTF8.self)
    }

    static func exportStrictJSON(logs: [LogItem], emotions: [EmotionRecord], tasks: [TaskItem] = [],
                                 notes: String = "", appVersion: String) throws -> String {
        let json = exportJSON(logs: logs, emotions: emotions, tasks: tasks, notes: notes, appVersion: appVersion)
        _ = try parseStrict(json)
        return json
    }

    // MARK: - Import

    /// 对用户选择的文件执行流式限额读取，防止文件大小元数据缺失或读取期间被替换时占满内存。
    static func readJSON(from url: URL, maxBytes: Int = maxFileBytes) throws -> String {
        precondition(maxBytes > 0)
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var data = Data()
        data.reserveCapacity(min(maxBytes, 64 * 1024))
        while let chunk = try handle.read(upToCount: 64 * 1024), !chunk.isEmpty {
            guard chunk.count <= maxBytes - data.count else { throw BackupError.fileTooLarge }
            data.append(chunk)
        }
        guard let json = String(data: data, encoding: .utf8) else { throw BackupError.invalidJSON }
        return json
    }

    static func parse(_ json: String) throws -> ImportPreview {
        if json.utf8.count > maxFileBytes { throw BackupError.fileTooLarge }
        let object = try? JSONSerialization.jsonObject(with: Data(json.utf8))
        guard let root = object as? [String: Any] else { throw BackupError.invalidJSON }

        guard let versionValue = root["version"], !(versionValue is NSNull) else {
            throw BackupError.missingVersion
        }
        guard let version = versionValue as? String else { throw BackupError.missingVersion }
        guard version == backupVersion || version == legacyBackupVersion else {
            throw BackupError.incompatibleVersion(version)
        }
        let sectionRoot: [String: Any]
        if version == legacyBackupVersion {
            sectionRoot = root
        } else {
            guard let schemas = root["schemas"] as? [String: Any] else {
                throw BackupError.invalidObject("schemas")
            }
            for section in ["logs", "emotions", "tasks"] {
                guard let schema = integer(schemas[section]), schema == sectionSchemaVersion else {
                    throw BackupError.incompatibleVersion("\(section) schema")
                }
            }
            guard let data = root["data"] as? [String: Any] else {
                throw BackupError.invalidObject("data")
            }
            sectionRoot = data
        }
        guard let logsArray = sectionRoot["logs"] as? [Any] else {
            throw BackupError.invalidArray("logs")
        }
        guard let emotionsArray = sectionRoot["emotions"] as? [Any] else {
            throw BackupError.invalidArray("emotions")
        }
        let tasksArray: [Any]
        if version == legacyBackupVersion {
            tasksArray = []
        } else {
            guard let value = sectionRoot["tasks"] as? [Any] else {
                throw BackupError.invalidArray("tasks")
            }
            tasksArray = value
        }

        var logs: [LogItem] = []
        var logIDs = Set<String>()
        var skippedLogs = max(0, logsArray.count - maxEntryCount)
        for element in logsArray.prefix(maxEntryCount) {
            if let entry = element as? [String: Any], let log = parseLog(entry),
               logIDs.insert(log.id).inserted {
                logs.append(log)
            } else {
                skippedLogs += 1
            }
        }

        var emotions: [EmotionRecord] = []
        var emotionIDs = Set<String>()
        var skippedEmotions = max(0, emotionsArray.count - maxEntryCount)
        for element in emotionsArray.prefix(maxEntryCount) {
            if let entry = element as? [String: Any], let emotion = parseEmotion(entry),
               emotionIDs.insert(emotion.id).inserted {
                emotions.append(emotion)
            } else {
                skippedEmotions += 1
            }
        }

        var tasks: [TaskItem] = []
        var taskIDs = Set<String>()
        var skippedTasks = max(0, tasksArray.count - maxEntryCount)
        for element in tasksArray.prefix(maxEntryCount) {
            if let entry = element as? [String: Any], let task = parseTask(entry),
               taskIDs.insert(task.id).inserted {
                tasks.append(task)
            } else {
                skippedTasks += 1
            }
        }

        return ImportPreview(logCount: logs.count, emotionCount: emotions.count,
                             skippedLogs: skippedLogs, skippedEmotions: skippedEmotions,
                             taskCount: tasks.count, skippedTasks: skippedTasks,
                             logs: logs, emotions: emotions, tasks: tasks,
                             sourceVersion: version)
    }

    static func parseStrict(_ json: String) throws -> ImportPreview {
        guard !json.hasPrefix("\u{FEFF}") else { throw BackupError.invalidJSON }
        if json.utf8.count > maxFileBytes { throw BackupError.fileTooLarge }
        var scanner = StrictJSONScanner(json)
        try scanner.validate()
        let result = try parse(json)
        guard result.sourceVersion == backupVersion else { throw BackupError.contract("/version") }
        let root = try JSONSerialization.jsonObject(with: Data(json.utf8)) as! [String: Any]
        try checkFields(root, required: ["version", "exportedAt", "appVersion", "notes", "schemas", "data"], path: "/")
        guard let exportedAt = root["exportedAt"] as? String, normalizeISODate(exportedAt) != nil,
              root["appVersion"] is String, let notes = root["notes"] as? String, notes.utf16.count <= maxTextLength else {
            throw BackupError.contract("/metadata")
        }
        let sections: Set<String> = ["logs", "emotions", "tasks"]
        try checkFields(root["schemas"] as! [String: Any], required: sections, path: "/schemas")
        let data = root["data"] as! [String: Any]
        try checkFields(data, required: sections, path: "/data")
        for section in sections {
            let array = data[section] as! [Any]
            guard array.count <= maxEntryCount else { throw BackupError.contract("/data/\(section)") }
            for (i, value) in array.enumerated() {
                let path = "/data/\(section)/\(i)"
                guard let item = value as? [String: Any] else { throw BackupError.contract(path) }
                let required: Set<String>
                let optional: Set<String>
                switch section {
                case "logs":
                    required = ["id", "content", "colorTag", "category", "importance", "createdAt", "recordDate"]
                    optional = []
                case "emotions":
                    required = ["id", "level", "createdAt", "recordDate"]
                    optional = ["subEmotion", "note", "status"]
                default:
                    required = ["id", "title", "colorTag", "importance", "due", "createdAt", "updatedAt"]
                    optional = ["notes", "reminderAt", "completedAt"]
                }
                try checkFields(item, required: required, optional: optional, path: path)
                if section == "tasks" {
                    guard let due = item["due"] as? [String: Any] else { throw BackupError.contract(path + "/due") }
                    try checkFields(due, required: due["kind"] as? String == "allDay" ? ["kind", "date"] : ["kind", "at", "timeZone"], path: path + "/due")
                }
            }
        }
        guard result.skippedLogs + result.skippedEmotions + result.skippedTasks == 0 else { throw BackupError.contract("/data") }
        return result
    }

    static func parseRecovery(_ json: String) throws -> ImportPreview {
        let result = try parse(json)
        let root = try JSONSerialization.jsonObject(with: Data(json.utf8)) as! [String: Any]
        let legacy = result.sourceVersion == legacyBackupVersion
        try checkFields(root, required: [], optional: legacy ? ["version", "exportedAt", "appVersion", "notes", "logs", "emotions"] : ["version", "exportedAt", "appVersion", "notes", "schemas", "data"], path: "/")
        let data = legacy ? root : root["data"] as! [String: Any]
        if !legacy {
            try checkFields(root["schemas"] as! [String: Any], required: ["logs", "emotions", "tasks"], path: "/schemas")
            try checkFields(data, required: ["logs", "emotions", "tasks"], path: "/data")
        }
        for section in legacy ? ["logs", "emotions"] : ["logs", "emotions", "tasks"] {
            let allowed: Set<String>
            switch section {
            case "logs": allowed = ["id", "content", "colorTag", "category", "importance", "createdAt", "recordDate"]
            case "emotions": allowed = ["id", "level", "createdAt", "recordDate", "note", "status", "subEmotion"]
            default: allowed = ["id", "title", "colorTag", "importance", "due", "createdAt", "updatedAt", "notes", "reminderAt", "completedAt"]
            }
            for (i, value) in (data[section] as! [Any]).enumerated() {
                guard let item = value as? [String: Any] else { continue }
                try checkFields(item, required: [], optional: allowed, path: "/data/\(section)/\(i)")
                if let due = item["due"] as? [String: Any] {
                    try checkFields(due, required: [], optional: due["kind"] as? String == "allDay" ? ["kind", "date"] : ["kind", "at", "timeZone"], path: "/data/\(section)/\(i)/due")
                }
            }
        }
        return result
    }

    private static func checkFields(_ object: [String: Any], required: Set<String>, optional: Set<String> = [], path: String) throws {
        let keys = Set(object.keys)
        guard required.isSubset(of: keys), keys.isSubset(of: required.union(optional)) else { throw BackupError.contract(path) }
    }

    private static func parseLog(_ dict: [String: Any]) -> LogItem? {
        guard let id = dict["id"] as? String, isUUID(id),
              let content = dict["content"] as? String, content.utf16.count <= maxTextLength,
              let colorTag = (dict["colorTag"] as? String).flatMap(ColorTag.init(rawValue:)),
              let category = (dict["category"] as? String).flatMap(Category.init(rawValue:)),
              let createdAt = dict["createdAt"] as? String, let normalizedCreatedAt = normalizeISODate(createdAt),
              let recordDate = dict["recordDate"] as? String, isDay(recordDate),
              let importance = integer(dict["importance"]), (0...4).contains(importance)
        else { return nil }
        return LogItem(id: id, content: content,
                       colorTag: colorTag, category: category,
                       importance: importance, createdAt: normalizedCreatedAt, recordDate: recordDate)
    }

    private static func parseEmotion(_ dict: [String: Any]) -> EmotionRecord? {
        guard let id = dict["id"] as? String, isUUID(id),
              let rawLevel = integer(dict["level"]),
              let level = EmotionLevel(rawValue: rawLevel),
              let createdAt = dict["createdAt"] as? String, let normalizedCreatedAt = normalizeISODate(createdAt),
              let recordDate = dict["recordDate"] as? String, isDay(recordDate)
        else { return nil }
        let subEmotion: SubEmotion?
        if let value = dict["subEmotion"], !(value is NSNull) {
            guard let raw = value as? String, let parsed = SubEmotion(rawValue: raw) else { return nil }
            subEmotion = parsed
        } else {
            subEmotion = nil
        }
        guard hasValidOptionalText(dict, key: "status"),
              hasValidOptionalText(dict, key: "note") else { return nil }
        let status = dict["status"] as? String
        let note = dict["note"] as? String
        return EmotionRecord(id: id, level: level, subEmotion: subEmotion,
                             status: status, note: note,
                             recordDate: recordDate, createdAt: normalizedCreatedAt)
    }

    private static func parseTask(_ dict: [String: Any]) -> TaskItem? {
        guard let id = dict["id"] as? String, isUUID(id),
              let rawTitle = dict["title"] as? String,
              !rawTitle.trimmingCharacters(in: contractWhitespace).isEmpty,
              rawTitle.utf16.count <= 200,
              hasValidOptionalText(dict, key: "notes"),
              let colorTag = (dict["colorTag"] as? String).flatMap(ColorTag.init(rawValue:)),
              let importance = integer(dict["importance"]), (0...4).contains(importance),
              let due = dict["due"] as? [String: Any],
              let dueKind = (due["kind"] as? String).flatMap(TaskDueKind.init(rawValue:)),
              let rawCreatedAt = dict["createdAt"] as? String,
              let createdAt = normalizeISODate(rawCreatedAt),
              let rawUpdatedAt = dict["updatedAt"] as? String,
              let updatedAt = normalizeISODate(rawUpdatedAt),
              updatedAt >= createdAt,
              let reminderAt = optionalNormalizedISO(dict, key: "reminderAt"),
              let completedAt = optionalNormalizedISO(dict, key: "completedAt")
        else { return nil }

        let dueDate: String?
        let dueAt: String?
        let timeZone: String?
        switch dueKind {
        case .allDay:
            guard let date = due["date"] as? String, isDay(date) else { return nil }
            dueDate = date
            dueAt = nil
            timeZone = nil
        case .dateTime:
            guard let rawDueAt = due["at"] as? String,
                  let normalizedDueAt = normalizeISODate(rawDueAt),
                  let zone = due["timeZone"] as? String,
                  isSupportedTimeZone(zone) else { return nil }
            dueDate = nil
            dueAt = normalizedDueAt
            timeZone = zone
        }

        return TaskItem(
            id: id,
            title: rawTitle.trimmingCharacters(in: contractWhitespace),
            notes: dict["notes"] as? String,
            colorTag: colorTag,
            importance: importance,
            dueKind: dueKind,
            dueDate: dueDate,
            dueAt: dueAt,
            timeZone: timeZone,
            reminderAt: reminderAt,
            completedAt: completedAt,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    /// 返回双层 Optional：外层 nil 表示字段非法，内层 nil 表示字段缺失或 JSON null。
    private static func optionalNormalizedISO(
        _ dict: [String: Any], key: String
    ) -> String?? {
        guard let value = dict[key], !(value is NSNull) else { return .some(nil) }
        guard let raw = value as? String, let normalized = normalizeISODate(raw) else { return nil }
        return .some(normalized)
    }

    private static func hasValidOptionalText(_ dict: [String: Any], key: String) -> Bool {
        guard let value = dict[key], !(value is NSNull) else { return true }
        guard let text = value as? String else { return false }
        return text.utf16.count <= maxTextLength
    }

    /// 命名时区校验，对齐 Android `zone == "UTC" || zone in ZoneId.getAvailableZoneIds()`。
    /// macOS 的 knownTimeZoneIdentifiers 在部分 ICU 版本下缺少 Etc/GMT±N 等合法 IANA 名称
    /// （共享契约样例 valid-time-zones 覆盖此情形），因此用「形如 Area/Name、可解析且
    /// 标识原样回读」兜底；缩写（PST）与偏移写法（GMT+8）不满足该形态，仍被拒绝。
    private static func isSupportedTimeZone(_ zone: String) -> Bool {
        if zone == "UTC" { return true }
        if TimeZone.knownTimeZoneIdentifiers.contains(zone) { return true }
        guard zone.contains("/"),
              let timeZone = TimeZone(identifier: zone),
              timeZone.identifier == zone else { return false }
        return true
    }

    private static func isUUID(_ value: String) -> Bool {
        uuidRegex.firstMatch(in: value, range: NSRange(value.startIndex..., in: value)) != nil
    }

    private static func isDay(_ value: String) -> Bool {
        guard dayRegex.firstMatch(in: value, range: NSRange(value.startIndex..., in: value)) != nil else {
            return false
        }
        let parts = value.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return false }
        let (y, m, d) = (parts[0], parts[1], parts[2])
        let leap = y % 4 == 0 && (y % 100 != 0 || y % 400 == 0)
        let days = [31, leap ? 29 : 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
        return (1...9999).contains(y) && (1...12).contains(m) && d >= 1 && d <= days[m - 1]
    }

    private static let contractWhitespace = CharacterSet(charactersIn: "\u{9}\u{A}\u{B}\u{C}\u{D} \u{A0}\u{1680}\u{2000}\u{2001}\u{2002}\u{2003}\u{2004}\u{2005}\u{2006}\u{2007}\u{2008}\u{2009}\u{200A}\u{2028}\u{2029}\u{202F}\u{205F}\u{3000}\u{FEFF}")

    private static func integer(_ value: Any?) -> Int? {
        guard let number = value as? NSNumber, CFGetTypeID(number) != CFBooleanGetTypeID() else { return nil }
        let d = number.doubleValue
        guard d.isFinite, d >= Double(Int32.min), d <= Double(Int32.max), d.rounded(.towardZero) == d else { return nil }
        return Int(d)
    }

    private static func isNamedTimeZone(_ value: String) -> Bool {
        // Foundation's knownTimeZoneIdentifiers omits valid IANA links such as Etc/GMT+1.
        guard value.range(of: #"^(?:[+-]|GMT[+-]|UTC[+-])"#, options: .regularExpression) == nil else { return false }
        return TimeZone(identifier: value) != nil
    }

    private static let minimumInstant = isoWholeSecondFormatter.date(from: "0001-01-01T00:00:00Z")!
    private static let maximumInstant = isoWholeSecondFormatter.date(from: "9999-12-31T23:59:59Z")!

    private static func normalizeISODate(_ value: String) -> String? {
        let pattern = #"^([0-9]{4}-[0-9]{2}-[0-9]{2})T([0-9]{2}):([0-9]{2}):([0-9]{2})(?:\.([0-9]{1,9}))?(Z|[+-][0-9]{2}:[0-9]{2})$"#
        guard let match = value.range(of: pattern, options: .regularExpression), match == value.startIndex..<value.endIndex else { return nil }
        let chars = Array(value)
        let day = String(chars[0..<10])
        guard isDay(day), let h = Int(String(chars[11..<13])), h <= 23,
              let m = Int(String(chars[14..<16])), m <= 59,
              let s = Int(String(chars[17..<19])), s <= 59 else { return nil }
        let zone = value.hasSuffix("Z") ? "Z" : String(value.suffix(6))
        guard zone != "-00:00" else { return nil }
        var offset = 0
        if zone != "Z" {
            let z = Array(zone)
            guard let zh = Int(String(z[1..<3])), zh <= 23,
                  let zm = Int(String(z[4..<6])), zm <= 59 else { return nil }
            offset = (zh * 60 + zm) * 60 * (z[0] == "-" ? -1 : 1)
        }
        // Parse whole UTC seconds, then append the original truncated millisecond digits.
        // This avoids floating-point rounding of submillisecond input on Foundation.
        guard let base = isoWholeSecondFormatter.date(from: "\(day)T\(String(chars[11..<19]))Z") else { return nil }
        let instant = base.addingTimeInterval(Double(-offset))
        guard instant >= minimumInstant, instant <= maximumInstant else { return nil }
        let utc = isoWholeSecondFormatter.string(from: instant)
        guard utc.count == 20, let year = Int(utc.prefix(4)), (1...9999).contains(year) else { return nil }
        let fraction = chars.count > 19 && chars[19] == "." ? String(chars[20..<(chars.count - zone.count)]) : ""
        let milliseconds = String((fraction + "000").prefix(3))
        return String(utc.dropLast()) + "." + milliseconds + "Z"
    }

    static func normalizedTimestamp(_ value: String) throws -> String {
        guard let normalized = normalizeISODate(value) else { throw BackupError.contract("/updatedAt") }
        return normalized
    }

    private static func normalizedForExport(_ value: String?) -> Any {
        guard let value else { return NSNull() }
        return normalizeISODate(value) ?? value
    }
}
