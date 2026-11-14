// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Testing
import Foundation
@testable import FlashCore

@Suite("FlashStoreLocation")
struct FlashStoreLocationTests {
    private func makeDirs() throws -> (root: URL, legacy: URL, destination: URL) {
        let root = FileManager.default.temporaryDirectory.appending(path: "store-location-\(UUID().uuidString)")
        let group = root.appending(path: "group/Library/Application Support")
        let app = root.appending(path: "app/Library/Application Support")
        try FileManager.default.createDirectory(at: group, withIntermediateDirectories: true)
        return (root, group.appending(path: "default.store"), app.appending(path: "default.store"))
    }

    private func write(_ text: String, to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(text.utf8).write(to: url)
    }

    private func read(_ url: URL) throws -> String { String(decoding: try Data(contentsOf: url), as: UTF8.self) }

    @Test func movesStoreAndCompanionsOutOfGroupContainer() throws {
        let (root, legacy, destination) = try makeDirs()
        defer { try? FileManager.default.removeItem(at: root) }
        try write("main", to: legacy)
        try write("wal", to: URL(filePath: legacy.path + "-wal"))
        try write("shm", to: URL(filePath: legacy.path + "-shm"))
        try write("blob", to: legacy.deletingLastPathComponent().appending(path: ".default_SUPPORT/_EXTERNAL_DATA/a"))

        #expect(FlashStoreLocation.resolve(legacy: legacy, destination: destination) == destination)

        let appDir = destination.deletingLastPathComponent()
        #expect(try read(destination) == "main")
        #expect(try read(appDir.appending(path: "default.store-wal")) == "wal")
        #expect(try read(appDir.appending(path: "default.store-shm")) == "shm")
        #expect(try read(appDir.appending(path: ".default_SUPPORT/_EXTERNAL_DATA/a")) == "blob")
        let leftovers = try FileManager.default.contentsOfDirectory(atPath: legacy.deletingLastPathComponent().path)
        #expect(leftovers.isEmpty, "nothing readable stays in the group container")
    }

    @Test func neverOverwritesAnExistingPrivateStore() throws {
        let (root, legacy, destination) = try makeDirs()
        defer { try? FileManager.default.removeItem(at: root) }
        try write("group", to: legacy)
        try write("private", to: destination)

        #expect(try !FlashStoreLocation.migrateIfNeeded(from: legacy, to: destination))
        #expect(try read(destination) == "private")
        #expect(try read(legacy) == "group", "the group copy is left alone, not deleted")
    }

    @Test func finishesAnInterruptedMigration() throws {
        let (root, legacy, destination) = try makeDirs()
        defer { try? FileManager.default.removeItem(at: root) }
        // A previous launch moved the WAL, then stopped before the main file.
        try write("main", to: legacy)
        try write("wal", to: URL(filePath: destination.path + "-wal"))

        #expect(try FlashStoreLocation.migrateIfNeeded(from: legacy, to: destination))
        #expect(try read(destination) == "main")
        #expect(try read(URL(filePath: destination.path + "-wal")) == "wal")
    }

    @Test func noLegacyStoreMeansNoMove() throws {
        let (root, legacy, destination) = try makeDirs()
        defer { try? FileManager.default.removeItem(at: root) }
        #expect(try !FlashStoreLocation.migrateIfNeeded(from: legacy, to: destination))
        #expect(try !FlashStoreLocation.migrateIfNeeded(from: nil, to: destination))
        #expect(FlashStoreLocation.resolve(legacy: nil, destination: destination) == destination)
        #expect(FileManager.default.fileExists(atPath: destination.deletingLastPathComponent().path))
    }

    @Test func failedMigrationKeepsUsingTheLegacyStore() throws {
        let (root, legacy, destination) = try makeDirs()
        defer { try? FileManager.default.removeItem(at: root) }
        try write("main", to: legacy)
        // The destination's parent is a file, so the move cannot happen.
        try write("not a directory", to: destination.deletingLastPathComponent())

        #expect(FlashStoreLocation.resolve(legacy: legacy, destination: destination) == legacy)
        #expect(try read(legacy) == "main")
    }

    #if os(macOS)
    @Test func failedMainMoveLeavesLegacyCompanionsAvailableForFallback() throws {
        let (root, legacy, destination) = try makeDirs()
        let manager = FileManager.default
        defer {
            try? manager.setAttributes([.immutable: false], ofItemAtPath: legacy.path)
            try? manager.removeItem(at: root)
        }
        try write("main", to: legacy)
        let wal = URL(filePath: legacy.path + "-wal")
        let shm = URL(filePath: legacy.path + "-shm")
        try write("committed WAL", to: wal)
        try write("shared memory", to: shm)
        // Sidecars can move/copy; the main-file rename fails after those steps.
        try manager.setAttributes([.immutable: true], ofItemAtPath: legacy.path)

        #expect(FlashStoreLocation.resolve(legacy: legacy, destination: destination) == legacy)
        #expect(try read(wal) == "committed WAL")
        #expect(try read(shm) == "shared memory")
        #expect(!manager.fileExists(atPath: destination.path))

        try manager.setAttributes([.immutable: false], ofItemAtPath: legacy.path)
        #expect(FlashStoreLocation.resolve(legacy: legacy, destination: destination) == destination)
        #expect(try read(URL(filePath: destination.path + "-wal")) == "committed WAL")
        #expect(try read(URL(filePath: destination.path + "-shm")) == "shared memory")
        #expect(try manager.contentsOfDirectory(atPath: legacy.deletingLastPathComponent().path).isEmpty)
    }
    #endif

    @Test func productionStoreIsAppPrivate() {
        #expect(FlashStoreLocation.privateStoreURL.lastPathComponent == "default.store")
        #expect(!FlashStoreLocation.privateStoreURL.path.contains("Group Containers"))
        #expect(!FlashStoreLocation.privateStoreURL.path.contains("AppGroup"))
    }
}
