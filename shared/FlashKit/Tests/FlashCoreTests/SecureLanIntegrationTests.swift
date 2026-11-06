// Copyright (c) 2026 Fengyuan Jiang · MPL-2.0
import Foundation
@preconcurrency import Network
import Testing
@testable import FlashCore

@MainActor private final class SecureLanHarness {
    var sender: SecureLanConnection?
    var receiver: SecureLanConnection?
    var senderCode: [UInt16] = []
    var receiverCode: [UInt16] = []
    var snapshots = 0
    var sent = false
    var received: String?
    var failures = 0
    let listener: NWListener
    let json: String
    init(json: String) throws { self.json = json; listener = try NWListener(using: .tcp, on: .any) }
    func start() async throws {
        listener.newConnectionHandler = { [weak self] connection in Task { @MainActor in
            guard let self else { connection.cancel(); return }
            do {
                let channel = try SecureLanConnection(connection: connection, sender: true, remaining: 120_000,
                    snapshot: { [weak self] in
                        guard let self else { throw CancellationError() }
                        self.snapshots += 1; return self.json
                    }) { [weak self] event in
                        guard let self else { return }
                        switch event {
                        case .code(let code): self.senderCode = code
                        case .sent: self.sent = true
                        case .failed: self.failures += 1
                        default: break
                        }
                    }
                self.sender = channel; channel.start()
            } catch { self.failures += 1; connection.cancel() }
        } }
        listener.start(queue: .main)
        try await wait { (self.listener.port?.rawValue ?? 0) > 0 }
        let port = try #require(listener.port)
        receiver = try SecureLanConnection(connection: NWConnection(host: .ipv4(.loopback), port: port, using: .tcp),
            sender: false, remaining: 120_000, snapshot: nil) { [weak self] event in
                guard let self else { return }
                switch event {
                case .code(let code): self.receiverCode = code
                case .received(let json): self.received = json
                case .failed: self.failures += 1
                default: break
                }
            }
        receiver?.start()
        try await wait { !self.senderCode.isEmpty && !self.receiverCode.isEmpty }
    }
    func wait(_ condition: () -> Bool) async throws {
        let end = DispatchTime.now().uptimeNanoseconds + 8_000_000_000
        while !condition() {
            guard DispatchTime.now().uptimeNanoseconds < end else { throw SecureLanError.expired }
            try await Task.sleep(for: .milliseconds(10))
        }
    }
    func stop() { sender?.cancel(); receiver?.cancel(); listener.cancel() }
}

@Suite("Secure LAN v2 native Apple integration", .serialized)
struct SecureLanIntegrationTests {
    private static let backup = """
    {"version":"flash-backup-v2","exportedAt":"2026-11-01T00:00:00.000Z","appVersion":"test","notes":"","schemas":{"logs":2,"emotions":2,"tasks":2},"data":{"logs":[],"emotions":[],"tasks":[]}}
    """
    @Test(.enabled(if: SecureLanSession.available)) @MainActor
    func bothConfirmBeforeSnapshotAndStrictReceipt() async throws {
        let h = try SecureLanHarness(json: Self.backup); defer { h.stop() }
        try await h.start()
        #expect(h.senderCode == h.receiverCode && h.senderCode.count == 3)
        #expect(h.snapshots == 0 && h.received == nil && !h.sent)
        h.sender?.confirm()
        try await Task.sleep(for: .milliseconds(300))
        #expect(h.snapshots == 0 && h.received == nil && !h.sent)
        h.receiver?.confirm()
        try await h.wait { h.sent && h.received != nil }
        #expect(h.snapshots == 1 && h.received == Self.backup && h.failures == 0)
    }
    @Test(.enabled(if: SecureLanSession.available)) @MainActor
    func strictParserRejectsWithoutReceiptOrPreview() async throws {
        let h = try SecureLanHarness(json: "{}"); defer { h.stop() }
        try await h.start(); h.sender?.confirm(); h.receiver?.confirm()
        try await h.wait { h.failures >= 2 }
        #expect(h.snapshots == 1 && h.received == nil && !h.sent)
    }
    @Test(.enabled(if: SecureLanSession.available)) @MainActor
    func cancelDuringComparisonDoesNotSnapshot() async throws {
        let h = try SecureLanHarness(json: Self.backup); defer { h.stop() }
        try await h.start(); h.receiver?.cancel()
        try await h.wait { h.failures > 0 }
        #expect(h.snapshots == 0 && h.received == nil && !h.sent)
    }
}
