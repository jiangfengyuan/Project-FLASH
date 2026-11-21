import FlashCore
import Foundation

struct ProbeError: Error, CustomStringConvertible {
    let description: String
    init(_ description: String) { self.description = description }
}

func check(_ condition: Bool, _ message: String) throws {
    guard condition else { throw ProbeError(message) }
}

// Only the public synthetic fixtures are used. The repository is always opened
// with an explicit store URL under a newly created, marked probe directory.
let passphrase = "flash-interop-20261121"
let localID = "fd970000-0000-4000-a000-000000000001"
let marker = "flash-paper-synthetic-interop-v1"
let files: [(String, BackupExportFormat, String?)] = [
    ("full-v4.json", .fullLibrary, nil), ("full-v4-encrypted.json", .fullLibrary, passphrase),
    ("records-v2.json", .compatibleRecords, nil), ("records-v2-encrypted.json", .compatibleRecords, passphrase),
]

func seedSnapshot() throws -> FlashSnapshot {
    let fixtures = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        .appendingPathComponent("../../../../docs/contracts/fixtures").standardizedFileURL
    func read(_ name: String) throws -> ImportPreview {
        try BackupService.parseStrict(String(contentsOf: fixtures.appendingPathComponent(name), encoding: .utf8))
    }
    let records = try read("valid-schema2.json"), metadata = try read("valid-library-v4.json")
    guard var library = metadata.library, let preferences = metadata.preferences,
          let tag = library.tags.first, let idea = records.logs.first(where: { $0.category == .idea }) else {
        throw ProbeError("invalid fixture")
    }
    var filter = LibraryFilter()
    filter.id = "50000000-0000-4000-8000-000000000001"
    filter.name = "Saved reading"
    filter.tagIDs = [tag.id]
    library.filters = [filter]
    var reminder = PersonalReminder(ideaID: idea.id, anchorDay: "2026-09-04")
    reminder.intervalDays = 3
    reminder.hour = 18
    reminder.minute = 15
    library.reminders = [reminder]
    return FlashSnapshot(logs: records.logs + metadata.logs, emotions: records.emotions, tasks: records.tasks,
                         library: library, trash: metadata.trash, preferences: preferences,
                         automaticTags: metadata.automaticTags)
}

@MainActor
func repository(_ url: URL, reopen: Bool = false, beforeSave: @escaping () throws -> Void = {}) throws -> FlashRepository {
    try check(FileManager.default.fileExists(atPath: url.path) == reopen, "unexpected probe store state")
    let container = FlashDatabase.makeContainerWithFallback(storeURL: url)
    try check(!container.didFallbackToMemory, "synthetic store fell back to memory")
    return FlashRepository(container: container.container, beforeSave: beforeSave)
}

@MainActor
func exportFiles(_ output: URL, work: URL, seed: FlashSnapshot) async throws {
    let repo = try repository(work.appendingPathComponent("source.store"))
    try repo.replaceAll(logs: seed.logs, emotions: seed.emotions, tasks: seed.tasks, library: seed.library,
                        trash: seed.trash, preferences: seed.preferences, automaticTags: seed.automaticTags)
    let snapshot = try repo.snapshot()
    for (name, format, password) in files {
        let text = try await BackupImportCoordinator.exportJSON(snapshot: snapshot, appVersion: "Apple-interop-probe",
                                                                format: format, passphrase: password)
        try BackupTransfer.writeExportFile(json: text, to: output.appendingPathComponent(name))
        print("exported \(name)")
    }
}

func verify(_ actual: FlashSnapshot, seed: FlashSnapshot, format: BackupExportFormat, overwrite: Bool) throws {
    let local = actual.logs.filter { $0.id == localID }
    try check(local.count == (overwrite ? 0 : 1) && local.allSatisfy { $0.content == "Synthetic local record" },
              "local-only record policy")
    let logs = actual.logs.filter { $0.id != localID }
    try check(logs.sorted { $0.id < $1.id } == seed.logs.sorted { $0.id < $1.id }, "persisted logs")
    try check(actual.emotions.sorted { $0.id < $1.id } == seed.emotions.sorted { $0.id < $1.id }, "persisted emotions")
    try check(actual.tasks.sorted { $0.id < $1.id } == seed.tasks.sorted { $0.id < $1.id }, "persisted tasks")
    let retainsMetadata = format == .fullLibrary || !overwrite
    var library = retainsMetadata ? seed.library : PersonalLibrary()
    if format == .fullLibrary { library.remindersNeedConfirmation = true }
    try check(actual.library == library, "persisted personal library")
    try check(actual.preferences == (retainsMetadata ? seed.preferences : LibraryPreferences()), "persisted preferences")
    try check(actual.automaticTags == (retainsMetadata ? seed.automaticTags : [:]), "persisted automatic tags")
    try check(actual.trash.sorted { $0.id < $1.id } == (retainsMetadata ? seed.trash.sorted { $0.id < $1.id } : []),
              "persisted trash")
}

@MainActor
func verifyFailurePaths(text: String, before: FlashSnapshot, store: URL, repo: FlashRepository) async throws {
    for (badText, password) in [(text, "wrong-test-password"), ("{", nil), ("{\"version\":\"flash-backup-v99\"}", nil)] {
        do {
            _ = try await BackupImportCoordinator.preview(text: badText, recovery: false, passphrase: password, against: before)
            throw ProbeError("accepted invalid backup or password")
        } catch is BackupError {}
    }
    let preview = try await BackupImportCoordinator.preview(text: text, recovery: false, passphrase: passphrase, against: before)
    let cancelled = Task { @MainActor in
        withUnsafeCurrentTask { $0?.cancel() }
        return try await BackupImportCoordinator.apply(preview, overwrite: true, previewSnapshot: before,
            repository: repo, rebuildReminders: { _ in throw ProbeError("cancelled import rebuilt reminders") })
    }
    do {
        _ = try await cancelled.value
        throw ProbeError("cancelled import committed")
    } catch is CancellationError {}
    enum SyntheticFailure: Error { case save }
    let failing = try repository(store, reopen: true, beforeSave: { throw SyntheticFailure.save })
    do {
        _ = try await BackupImportCoordinator.apply(preview, overwrite: true, previewSnapshot: before,
            repository: failing, rebuildReminders: { _ in throw ProbeError("failed import rebuilt reminders") })
        throw ProbeError("failed write reported success")
    } catch SyntheticFailure.save {}
    try check(try failing.snapshot() == before && repo.snapshot() == before, "failed operation changed store")
    print("verified wrong password, malformed and unknown version, cancellation and failed transaction rollback")
}

@MainActor
func importOrReopen(_ input: URL, work: URL, seed: FlashSnapshot, reopen: Bool) async throws {
    for (name, format, password) in files {
        for overwrite in [false, true] {
            let policy = overwrite ? "overwrite" : "merge"
            let store = work.appendingPathComponent("\(name)-\(policy).store")
            let repo = try repository(store, reopen: reopen)
            if !reopen {
                if format == .compatibleRecords {
                    let reminderIDs = Set(seed.library.reminders.map(\.id))
                    let libraryLogs = seed.logs.filter { seed.library.links["log:" + $0.id] != nil || reminderIDs.contains($0.id) }
                    try repo.replaceAll(logs: libraryLogs, emotions: [], library: seed.library, trash: seed.trash,
                                        preferences: seed.preferences, automaticTags: seed.automaticTags)
                }
                try repo.addLog(id: localID, content: "Synthetic local record", colorTag: .daily)
                let before = try repo.snapshot()
                let text = try await BackupImportCoordinator.readBackupText(fileAt: input.appendingPathComponent(name))
                try check(BackupEncryption.isEnvelope(text) == (password != nil), "encryption on \(name)")
                if format == .fullLibrary && password != nil && overwrite {
                    try await verifyFailurePaths(text: text, before: before, store: store, repo: repo)
                }
                let preview = try await BackupImportCoordinator.preview(text: text, recovery: false,
                                                                       passphrase: password, against: before)
                try check(preview.sourceVersion == (format == .fullLibrary ? LibraryBackup.version : BackupService.backupVersion),
                          "file version on \(name)")
                var rebuiltTasks: [TaskItem]?
                let outcome = try await BackupImportCoordinator.apply(preview, overwrite: overwrite,
                    previewSnapshot: before, repository: repo, rebuildReminders: { rebuiltTasks = $0 })
                guard case .imported(_, false) = outcome else { throw ProbeError("apply \(name)") }
                try check(rebuiltTasks?.sorted { $0.id < $1.id } == seed.tasks.sorted { $0.id < $1.id },
                          "task reminder rebuild input")
            }
            try verify(repo.snapshot(), seed: seed, format: format, overwrite: overwrite)
            print("verified \(reopen ? "separate-process reopen" : "import") \(name) \(policy)")
        }
    }
}

guard CommandLine.arguments.count == 4, ["export", "import", "reopen"].contains(CommandLine.arguments[1]) else {
    throw ProbeError("Usage: PaperBackupInterop export|import|reopen exchange-directory isolated-store-directory")
}
let operation = CommandLine.arguments[1]
let exchange = URL(fileURLWithPath: CommandLine.arguments[2], isDirectory: true)
let work = URL(fileURLWithPath: CommandLine.arguments[3], isDirectory: true)
let fileManager = FileManager.default
let markerFile = work.appendingPathComponent("probe.marker")
if operation == "reopen" {
    try check(try String(contentsOf: markerFile, encoding: .utf8) == marker, "expected synthetic store marker")
} else {
    try check(!fileManager.fileExists(atPath: work.path), "use a new store directory")
    try fileManager.createDirectory(at: work, withIntermediateDirectories: true)
    try Data(marker.utf8).write(to: markerFile, options: .withoutOverwriting)
}
let seed = try seedSnapshot()
if operation == "export" {
    try check(!fileManager.fileExists(atPath: exchange.path), "use a new export directory")
    try fileManager.createDirectory(at: exchange, withIntermediateDirectories: true)
    try await exportFiles(exchange, work: work, seed: seed)
} else {
    try await importOrReopen(exchange, work: work, seed: seed, reopen: operation == "reopen")
}
