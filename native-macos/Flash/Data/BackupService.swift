import Foundation

enum BackupError: Error, Equatable {
    case invalidJSON
    case missingVersion
    case incompatibleVersion(String)
    case invalidArray(String)
    case fileTooLarge

    var userMessage: String {
        switch self {
        case .invalidJSON: "备份文件不是有效的 JSON 对象"
        case .missingVersion: "备份版本不兼容：缺少 version 字段"
        case .incompatibleVersion(let v): "备份版本不兼容：期望 flash-backup-v1，实际 \(v)"
        case .invalidArray(let name): "\(name) 必须是数组"
        case .fileTooLarge: "文件过大，不是有效的备份"
        }
    }
}

struct ImportPreview {
    let logCount: Int
    let emotionCount: Int
    let skippedLogs: Int
    let skippedEmotions: Int
    let logs: [LogItem]
    let emotions: [EmotionRecord]
}

/// JSON 备份导出/导入，格式与 Android Backup.kt / Web backup.ts 完全一致：
/// { version, exportedAt, appVersion, notes, logs[], emotions[] }
/// 非法条目跳过而非整体失败。
enum BackupService {
    static let backupVersion = "flash-backup-v1"
    static let maxFileBytes = 50 * 1024 * 1024
    private static let maxEntryCount = 1_000_000
    private static let maxTextLength = 100_000

    private static let uuidRegex = try! NSRegularExpression(
        pattern: "^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$")
    private static let dayRegex = try! NSRegularExpression(pattern: "^\\d{4}-\\d{2}-\\d{2}$")

    // MARK: - Export

    static func exportJSON(logs: [LogItem], emotions: [EmotionRecord],
                           notes: String = "", appVersion: String) -> String {
        let logDicts: [[String: Any]] = logs.map { log in
            ["id": log.id, "content": log.content, "colorTag": log.colorTag.rawValue,
             "category": log.category.rawValue, "importance": log.importance,
             "createdAt": log.createdAt, "recordDate": log.recordDate]
        }
        let emotionDicts: [[String: Any]] = emotions.map { e in
            ["id": e.id, "level": e.level.rawValue,
             "subEmotion": e.subEmotion?.rawValue ?? NSNull(),
             "status": e.status ?? NSNull(), "note": e.note ?? NSNull(),
             "recordDate": e.recordDate, "createdAt": e.createdAt]
        }
        let root: [String: Any] = [
            "version": backupVersion,
            "exportedAt": DateFormatting.isoNow(),
            "appVersion": appVersion,
            "notes": notes,
            "logs": logDicts,
            "emotions": emotionDicts,
        ]
        let data = try! JSONSerialization.data(withJSONObject: root,
                                               options: [.prettyPrinted, .sortedKeys])
        return String(decoding: data, as: UTF8.self)
    }

    // MARK: - Import

    static func parse(_ json: String) throws -> ImportPreview {
        if json.utf8.count > maxFileBytes { throw BackupError.fileTooLarge }
        let object = try? JSONSerialization.jsonObject(with: Data(json.utf8))
        guard let root = object as? [String: Any] else { throw BackupError.invalidJSON }

        guard let versionValue = root["version"], !(versionValue is NSNull) else {
            throw BackupError.missingVersion
        }
        guard let version = versionValue as? String else { throw BackupError.missingVersion }
        guard version == backupVersion else {
            throw BackupError.incompatibleVersion(version)
        }
        guard let logsArray = root["logs"] as? [Any] else {
            throw BackupError.invalidArray("logs")
        }
        guard let emotionsArray = root["emotions"] as? [Any] else {
            throw BackupError.invalidArray("emotions")
        }

        var logs: [LogItem] = []
        var skippedLogs = 0
        for element in logsArray.prefix(maxEntryCount) {
            if let entry = element as? [String: Any], let log = parseLog(entry) {
                logs.append(log)
            } else {
                skippedLogs += 1
            }
        }

        var emotions: [EmotionRecord] = []
        var skippedEmotions = 0
        for element in emotionsArray.prefix(maxEntryCount) {
            if let entry = element as? [String: Any], let emotion = parseEmotion(entry) {
                emotions.append(emotion)
            } else {
                skippedEmotions += 1
            }
        }

        return ImportPreview(logCount: logs.count, emotionCount: emotions.count,
                             skippedLogs: skippedLogs, skippedEmotions: skippedEmotions,
                             logs: logs, emotions: emotions)
    }

    private static func parseLog(_ dict: [String: Any]) -> LogItem? {
        guard let id = dict["id"] as? String, isUUID(id),
              let content = dict["content"] as? String,
              let colorTag = (dict["colorTag"] as? String).flatMap(ColorTag.init(rawValue:)),
              let category = (dict["category"] as? String).flatMap(Category.init(rawValue:)),
              let createdAt = dict["createdAt"] as? String, isISODate(createdAt),
              let recordDate = dict["recordDate"] as? String, isDay(recordDate)
        else { return nil }
        let importance = min(max(dict["importance"] as? Int ?? 0, 0), 4)
        return LogItem(id: id, content: String(content.prefix(maxTextLength)),
                       colorTag: colorTag, category: category,
                       importance: importance, createdAt: createdAt, recordDate: recordDate)
    }

    private static func parseEmotion(_ dict: [String: Any]) -> EmotionRecord? {
        guard let id = dict["id"] as? String, isUUID(id),
              let rawLevel = dict["level"] as? Int,
              let level = EmotionLevel(rawValue: rawLevel),
              let createdAt = dict["createdAt"] as? String, isISODate(createdAt),
              let recordDate = dict["recordDate"] as? String, isDay(recordDate)
        else { return nil }
        let subEmotion = (dict["subEmotion"] as? String).flatMap(SubEmotion.init(rawValue:))
        let status = (dict["status"] as? String).map { String($0.prefix(maxTextLength)) }
        let note = (dict["note"] as? String).map { String($0.prefix(maxTextLength)) }
        return EmotionRecord(id: id, level: level, subEmotion: subEmotion,
                             status: status, note: note,
                             recordDate: recordDate, createdAt: createdAt)
    }

    private static func isUUID(_ value: String) -> Bool {
        uuidRegex.firstMatch(in: value, range: NSRange(value.startIndex..., in: value)) != nil
    }

    private static func isDay(_ value: String) -> Bool {
        dayRegex.firstMatch(in: value, range: NSRange(value.startIndex..., in: value)) != nil
    }

    /// 严格 ISO-8601（对齐 Android Instant.parse 口径）
    private static func isISODate(_ value: String) -> Bool {
        guard !value.isEmpty else { return false }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if formatter.date(from: value) != nil { return true }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: value) != nil
    }
}
