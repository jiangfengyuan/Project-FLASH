import Foundation

enum DateFormatting {
    // Swift 6 并发检查：formatter 实例仅在各方法内短时使用，标记 nonisolated(unsafe)
    nonisolated(unsafe) private static let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    nonisolated(unsafe) private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    /// ISO-8601（与 JS Date#toISOString / Android ISO_INSTANT 同格式）
    static func isoNow() -> String { isoFormatter.string(from: Date()) }

    /// yyyy-MM-dd 本地日期
    static func today() -> String { dayFormatter.string(from: Date()) }

    static func dayString(_ date: Date) -> String { dayFormatter.string(from: date) }

    static func parseDay(_ string: String) -> Date? { dayFormatter.date(from: string) }
}
