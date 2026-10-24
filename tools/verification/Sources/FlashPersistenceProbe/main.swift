import Foundation
import SwiftData
import FlashCore

// Two separate processes exercise real on-disk save/reopen using the existing
// schema/plan and production repository. Never opens the default store/App Group.
precondition(CommandLine.arguments.count == 4,
    "Usage: FlashPersistenceProbe write|read NEW-scratch-directory fictional-schema2.json")
let mode = CommandLine.arguments[1]
precondition(mode == "write" || mode == "read")
let directory = URL(fileURLWithPath: CommandLine.arguments[2], isDirectory: true)
let marker = directory.appendingPathComponent("flash-synthetic-probe.marker")
let manager = FileManager.default
if mode == "write" {
    precondition(!manager.fileExists(atPath: directory.path), "Refuse to overwrite any existing directory")
    try manager.createDirectory(at: directory, withIntermediateDirectories: true,
        attributes: [.posixPermissions: 0o700])
    try Data("fictional-data-only".utf8).write(to: marker, options: .withoutOverwriting)
} else {
    let markerBytes = try Data(contentsOf: marker)
    precondition(markerBytes == Data("fictional-data-only".utf8))
}
let input = try String(contentsOfFile: CommandLine.arguments[3], encoding: .utf8)
let expected = try BackupService.parseStrict(input)
let schema = Schema(versionedSchema: FlashSchemaV2.self)
let container = try ModelContainer(for: schema, migrationPlan: FlashMigrationPlan.self,
    configurations: [ModelConfiguration(schema: schema, url: directory.appendingPathComponent("probe.store"))])
let repository = FlashRepository(container: container)
let readState = IdeaViewStateStore(directory: directory)
let ideaID = expected.logs.first(where: { $0.category == .idea })!.id
if mode == "write" {
    try repository.replaceAll(logs: expected.logs, emotions: expected.emotions, tasks: expected.tasks)
    readState.establishBaselineIfNeeded(existingIdeaIDs: [])
    readState.markViewed(ideaID)
}
let snapshot = try repository.snapshot()
let actual = FlashSnapshot(logs: snapshot.logs.sorted { $0.id < $1.id },
    emotions: snapshot.emotions.sorted { $0.id < $1.id }, tasks: snapshot.tasks.sorted { $0.id < $1.id })
let wanted = FlashSnapshot(logs: expected.logs.sorted { $0.id < $1.id },
    emotions: expected.emotions.sorted { $0.id < $1.id }, tasks: expected.tasks.sorted { $0.id < $1.id })
precondition(actual == wanted,
    "Persisted fields changed across save/reopen")
precondition(readState.hasBaseline && readState.viewedIDs == Set([ideaID]), "Read-state failed save/reopen")
print("{\"kind\":\"separate-process SwiftData/repository/read-state probe\",\"mode\":\"\(mode)\",\"verified\":true,\"realDeviceOrAppRelaunch\":false}")
