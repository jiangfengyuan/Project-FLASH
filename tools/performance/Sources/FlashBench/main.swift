import Foundation
import FlashCore
import CryptoKit
import os

#if DEBUG
#error("Run FlashBench with -c release; Debug timings are not accepted")
#endif

// Fixed reference date/seed, fictional records only. Generation is outside timing.
let count = Int(CommandLine.arguments.dropFirst().first ?? "1000") ?? 1000
precondition([1_000, 10_000, 100_000].contains(count))
var calendar = Calendar(identifier: .gregorian)
calendar.timeZone = TimeZone(secondsFromGMT: 0)!
let reference = calendar.date(from: DateComponents(year: 2026, month: 10, day: 24))!
let formatter = DateFormatter()
formatter.calendar = calendar
formatter.timeZone = calendar.timeZone
formatter.locale = Locale(identifier: "en_US_POSIX")
formatter.dateFormat = "yyyy-MM-dd"
let span = count == 1000 ? 365 : count == 10000 ? 1825 : 3650
let days = (0..<span).map { formatter.string(from: reference.addingTimeInterval(-Double($0) * 86400)) }
func id(_ section: Int, _ i: Int) -> String {
    String(format: "%08x-0000-4000-8000-%012x", section, i)
}
func day(_ i: Int) -> String { days[(i * 7919 + 17) % span] }
func instant(_ i: Int) -> String { day(i) + "T08:00:00.000Z" }
let logs = (0..<count).map { i in
    LogItem(id: id(1, i), content: (i % 3 == 0 ? "设计 study 🙂 " : "记录 moment ") +
            String(repeating: "fictional文 ", count: i % 97 == 0 ? 80 : 2) + "#\(i)",
            colorTag: ColorTag.allCases[i % ColorTag.allCases.count],
            category: i % 4 == 0 ? .idea : .log, importance: i % 5,
            isFavorite: i % 11 == 0, createdAt: instant(i), recordDate: day(i))
}
let emotions = (0..<(count / 2)).map { i in
    EmotionRecord(id: id(2, i), level: EmotionLevel.allCases[i % EmotionLevel.allCases.count],
                  note: i % 3 == 0 ? "设计 reflection \(i)" : nil,
                  recordDate: day(i), createdAt: instant(i))
}
let tasks = (0..<(count / 5)).map { i in
    TaskItem(id: id(3, i), title: "设计 task \(i)", colorTag: .daily, importance: i % 5,
             dueKind: .allDay, dueDate: day(i),
             completedAt: i % 2 == 0 ? instant(i) : nil,
             createdAt: instant(i), updatedAt: instant(i))
}
// Fingerprint a canonical deterministic model projection; export metadata contains wall time.
let material = logs.map { "\($0.id)|\($0.content)|\($0.createdAt)" }.joined(separator: "\n") +
    emotions.map { "\($0.id)|\($0.level.rawValue)|\($0.note ?? "")|\($0.createdAt)" }.joined(separator: "\n") +
    tasks.map { "\($0.id)|\($0.title)|\($0.completedAt ?? "")|\($0.createdAt)" }.joined(separator: "\n")
let digest = SHA256.hash(data: Data(material.utf8)).map { String(format: "%02x", $0) }.joined()
let clock = ContinuousClock()
let signposter = OSSignposter(subsystem: "com.flash.benchmark", category: "Release")
var sink = 0
@MainActor func measure(_ name: String, _ body: () throws -> Int) rethrows {
    for _ in 0..<2 { sink &+= try body() }
    var samples: [Double] = []
    for _ in 0..<7 {
        let state = signposter.beginInterval("Pipeline")
        let start = clock.now
        sink &+= try body()
        let duration = start.duration(to: clock.now)
        signposter.endInterval("Pipeline", state)
        samples.append(Double(duration.components.seconds) * 1000 + Double(duration.components.attoseconds) / 1e15)
    }
    let sorted = samples.sorted()
    let row: [String: Any] = ["metric": name, "samples_ms": samples,
        "median_ms": sorted[3], "min_ms": sorted[0], "max_ms": sorted[6],
        "logs": logs.count, "emotions": emotions.count, "tasks": tasks.count,
        "span_days": span, "dataset_sha256": digest, "reference_date": "2026-10-24",
        "build": "Release", "kind": "macOS host microbenchmark", "locale": Locale.current.identifier,
        "os": ProcessInfo.processInfo.operatingSystemVersionString, "result_sink": sink]
    print(String(decoding: try! JSONSerialization.data(withJSONObject: row, options: [.sortedKeys]), as: UTF8.self))
}
measure("globalSearch/common") {
    GlobalSearch.search(logs: logs, emotions: emotions, tasks: tasks, query: "设计").count
}
measure("globalSearch/noMatch") {
    GlobalSearch.search(logs: logs, emotions: emotions, tasks: tasks, query: "absent-zqxv").count
}
measure("calendar/aggregateDay") { aggregateDay(logs: logs, emotions: emotions, tasks: tasks).count }
// Compact serialization keeps the long-term fixture within the unchanged50MiB
// contract. This measures strict import, not the pretty-printed export pipeline.
let exported = BackupService.exportJSON(logs: logs, emotions: emotions, tasks: tasks, appVersion: "benchmark")
let root = try JSONSerialization.jsonObject(with: Data(exported.utf8))
let json = String(decoding: try JSONSerialization.data(withJSONObject: root, options: [.sortedKeys]), as: UTF8.self)
precondition(json.utf8.count <= BackupService.maxFileBytes)
try measure("backup/parseStrict/bytes=\(json.utf8.count)") {
    let result = try BackupService.parseStrict(json)
    precondition(result.logs.count == logs.count && result.emotions.count == emotions.count && result.tasks.count == tasks.count)
    return result.logCount + result.emotionCount + result.taskCount
}
