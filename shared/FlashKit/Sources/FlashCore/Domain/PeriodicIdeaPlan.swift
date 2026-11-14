import Foundation

public struct IdeaCycle: Equatable, Sendable {
    public let key: String
    public let ideaID: String
    public let day: String
    public let date: Date
    public let ordinal: Int
    public init(key: String, ideaID: String, day: String, date: Date, ordinal: Int) { self.key = key; self.ideaID = ideaID; self.day = day; self.date = date; self.ordinal = ordinal }
}
public enum PeriodicIdeaPlan {
    public static func cycles(rule: PersonalReminder, now: Date, calendar: Calendar = .current) -> [IdeaCycle] {
        guard rule.enabled, let anchor = DateFormatting.parseDay(rule.anchorDay), [1,3,7].contains(rule.intervalDays), (9...21).contains(rule.hour), (0...59).contains(rule.minute) else { return [] }
        let start = calendar.startOfDay(for: now)
        let anchorStart = calendar.startOfDay(for: anchor)
        var output: [IdeaCycle] = []
        for offset in 0..<14 {
            guard let day = calendar.date(byAdding: .day, value: offset, to: start),
                  let delta = calendar.dateComponents([.day], from: anchorStart, to: day).day,
                  delta >= 0, delta % rule.intervalDays == 0,
                  let first = calendar.date(bySettingHour: rule.hour, minute: rule.minute, second: 0, of: day) else { continue }
            let c = calendar.dateComponents([.year,.month,.day], from: day)
            let dayID = String(format:"%04d-%02d-%02d",c.year!,c.month!,c.day!)
            for ordinal in 0...1 {
                let date = first.addingTimeInterval(Double(ordinal * 1800))
                guard date > now, (9...21).contains(calendar.component(.hour, from: date)) else { continue }
                output.append(IdeaCycle(key: rule.id + ":" + dayID, ideaID: rule.id, day: dayID, date: date, ordinal: ordinal))
            }
        }
        return output
    }
}
