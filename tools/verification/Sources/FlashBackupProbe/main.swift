import Foundation
import FlashCore
import CryptoKit

// Execute only with fictional inputs in an isolated output directory. This
// invokes the real shared Apple exporter; it does not touch SwiftData or UI.
guard CommandLine.arguments.count == 3 else {
    fatalError("Usage: FlashBackupProbe synthetic-input.json NEW-output.json")
}
let inputURL = URL(fileURLWithPath: CommandLine.arguments[1])
let outputURL = URL(fileURLWithPath: CommandLine.arguments[2])
let inputBytes = try Data(contentsOf: inputURL)
precondition(inputBytes.count <= BackupService.maxFileBytes)
let parsed = try BackupService.parseStrict(String(decoding: inputBytes, as: UTF8.self))
let exported = BackupService.exportJSON(logs: parsed.logs, emotions: parsed.emotions,
    tasks: parsed.tasks, notes: "Fictional verification data", appVersion: "synthetic-compatibility-probe")
let roundtrip = try BackupService.parseStrict(exported)
precondition(roundtrip.logs == parsed.logs && roundtrip.emotions == parsed.emotions && roundtrip.tasks == parsed.tasks,
    "Apple export/reimport must preserve all model fields")
let outputBytes = Data(exported.utf8)
let document = try JSONSerialization.jsonObject(with: outputBytes) as! [String: Any]
let inputDocument = try JSONSerialization.jsonObject(with: inputBytes) as! [String: Any]
let inputData = inputDocument["data"] as! [String: Any]
let outputData = document["data"] as! [String: Any]
// Verify schema2 metadata against the actual incoming bytes, not only against
// an already-parsed model that could have silently discarded those fields.
for section in ["logs", "emotions", "tasks"] {
    let incoming = inputData[section] as! [[String: Any]]
    let outgoing = outputData[section] as! [[String: Any]]
    for record in incoming {
        let output = outgoing.first { ($0["id"] as? String) == (record["id"] as? String) }!
        for field in ["isFavorite", "intensity", "sourceLogId"] {
            let left = record[field] is NSNull ? nil : record[field] as? NSObject
            let right = output[field] is NSNull ? nil : output[field] as? NSObject
            precondition(left == right, "Incoming schema2 metadata was lost or changed")
        }
    }
}
try outputBytes.write(to: outputURL, options: .withoutOverwriting)
var zones: [[String: Any]] = []
for name in ["Europe/Kyiv", "Europe/Kiev", "Asia/Kolkata", "Asia/Calcutta", "UTC", "Invalid/Unknown"] {
    var row: [String: Any] = ["input": name, "foundationAccepted": TimeZone(identifier: name) != nil]
    row["foundationIdentifier"] = (TimeZone(identifier: name)?.identifier as Any?) ?? NSNull()
    row["contractListContains"] = CanonicalTimeZones.all.contains(name)
    zones.append(row)
}
let manifest: [String: Any] = ["kind": "Apple production codec export and self-import",
    "realDeviceOrUI": false, "incomingMetadataCompared": true,
    "os": ProcessInfo.processInfo.operatingSystemVersionString,
    "inputSHA256": SHA256.hash(data: inputBytes).map { String(format: "%02x", $0) }.joined(),
    "exportSHA256": SHA256.hash(data: outputBytes).map { String(format: "%02x", $0) }.joined(),
    "bytes": outputBytes.count, "schemas": document["schemas"]!,
    "counts": ["logs": parsed.logs.count, "emotions": parsed.emotions.count, "tasks": parsed.tasks.count],
    "timezoneProbes": zones]
print(String(decoding: try JSONSerialization.data(withJSONObject: manifest, options: [.prettyPrinted, .sortedKeys]), as: UTF8.self))
