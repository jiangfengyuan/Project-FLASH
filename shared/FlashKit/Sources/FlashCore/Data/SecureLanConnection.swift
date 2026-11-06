// Copyright (c) 2026 Fengyuan Jiang. SPDX-License-Identifier: MPL-2.0
import Foundation
@preconcurrency import Network

/// One socket, one native session. The main actor serializes all callbacks;
/// expensive snapshot generation and strict parsing suspend without stopping
/// the monotonic watchdog. No database writes belong to this object.
@MainActor
final class SecureLanConnection {
    enum Event { case phase(LocalTransferPhase), code([UInt16]), sent, received(String), failed(SecureLanError) }
    typealias Snapshot = @MainActor @Sendable () async throws -> String
    static func now() -> UInt64 { DispatchTime.now().uptimeNanoseconds / 1_000_000 }
    private let connection: NWConnection
    private let native: SecureLanSession
    private let sender: Bool
    private let snapshot: Snapshot?
    private let event: @MainActor (Event) -> Void
    private var closed = false
    private var writing = false
    private var working = false
    private var presentedCode = false
    private var validatedJSON: String?
    private var watchdog: Task<Void, Never>?
    private var work: Task<Void, Never>?
    private let connectedBy: UInt64
    private var ready = false
    private var writeBegan: UInt64?

    init(connection: NWConnection, sender: Bool, remaining: UInt64,
         snapshot: Snapshot?, event: @escaping @MainActor (Event) -> Void) throws {
        self.connection = connection; self.sender = sender
        self.snapshot = snapshot; self.event = event
        let now = Self.now()
        native = try SecureLanSession(sender: sender, now: now, remaining: remaining)
        connectedBy = now + min(10_000, remaining)
    }
    func start() {
        connection.stateUpdateHandler = { [weak self] state in
            Task { @MainActor in
                guard let self, !self.closed else { return }
                switch state {
                case .ready:
                    guard !self.ready else { return }
                    self.ready = true; self.event(.phase(.handshake))
                    self.read(); self.advance()
                case .failed, .cancelled: self.fail(.network)
                default: break
                }
            }
        }
        connection.start(queue: .main)
        watchdog = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(250))
                guard !Task.isCancelled, let self, !self.closed else { return }
                do {
                    let now = Self.now()
                    if !self.ready && now >= self.connectedBy { throw SecureLanError.expired }
                    if let began = self.writeBegan, now - began >= 10_000 { throw SecureLanError.expired }
                    try self.native.tick(now)
                } catch { self.fail(error as? SecureLanError ?? .network) }
            }
        }
    }
    func confirm() {
        guard !closed else { return }
        do { try native.accept(Self.now()); advance() }
        catch { fail(error as? SecureLanError ?? .network) }
    }
    func cancel() {
        guard !closed else { return }
        closed = true
        watchdog?.cancel(); work?.cancel()
        native.cancel(); validatedJSON = nil
        connection.stateUpdateHandler = nil; connection.cancel()
    }
    private func fail(_ error: SecureLanError) {
        guard !closed else { return }
        cancel(); event(.failed(error))
    }
    private func read() {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65_536) { [weak self] data, _, eof, error in
            Task { @MainActor in
                guard let self, !self.closed else { return }
                do {
                    if let data, !data.isEmpty { try self.native.receive(data, now: Self.now()) }
                    if error != nil || eof {
                        // A receipt already authenticated on the sender is final;
                        // all other EOFs, including a lost receipt, fail closed.
                        if self.sender, try self.native.state == 13 { self.advance(); return }
                        if !self.sender, self.writing, self.validatedJSON != nil,
                           try self.native.state == 13 { return }
                        throw SecureLanError.unconfirmed
                    }
                    self.advance()
                    if !self.closed { self.read() }
                } catch { self.fail(error as? SecureLanError ?? .network) }
            }
        }
    }
    private func advance() {
        guard !closed, ready else { return }
        do {
            let state = try native.state
            switch state {
            case 1...5: event(.phase(.handshake))
            case 6:
                event(.phase(.confirming))
                if !presentedCode { presentedCode = true; event(.code(try native.code())) }
            case 7: event(.phase(.waitingForPeer))
            case 8 where !working:
                // Both authenticated confirmations are present. This is the
                // only place the deferred snapshot provider is invoked.
                working = true; event(.phase(.transferring))
                work = Task { [weak self] in
                    guard let self, let provider = self.snapshot else { return }
                    do {
                        let json = try await provider()
                        guard !self.closed, !Task.isCancelled else { return }
                        try self.native.provide(Data(json.utf8), now: Self.now())
                        self.working = false; self.advance()
                    } catch { self.fail(error as? SecureLanError ?? .invalidBackup) }
                }
            case 9, 10, 12: event(.phase(.transferring))
            case 11 where !working:
                working = true; event(.phase(.verifying))
                let bytes = try native.received()
                work = Task { [weak self] in
                    do {
                        let json = try await Task.detached(priority: .userInitiated) {
                            guard let json = String(data: bytes, encoding: .utf8) else { throw SecureLanError.invalidBackup }
                            _ = try BackupService.parseStrict(json)
                            return json
                        }.value
                        guard let self, !self.closed, !Task.isCancelled else { return }
                        try self.native.validated(true, now: Self.now())
                        self.validatedJSON = json; self.working = false; self.advance()
                    } catch { self?.fail(.invalidBackup) }
                }
            default: break
            }
            guard !writing else { return }
            if let packet = try native.output(Self.now()) {
                writing = true; writeBegan = Self.now()
                connection.send(content: packet, completion: .contentProcessed { [weak self] error in
                    Task { @MainActor in
                        guard let self, !self.closed else { return }
                        guard error == nil else { self.fail(.unconfirmed); return }
                        do {
                            try self.native.wrote(Self.now())
                            self.writing = false; self.writeBegan = nil; self.advance()
                        } catch { self.fail(error as? SecureLanError ?? .network) }
                    }
                })
            } else if state == 13 {
                let json = validatedJSON
                cancel()
                if sender { event(.sent) }
                else if let json { event(.received(json)) }
                else { event(.failed(.invalidBackup)) }
            }
        } catch { fail(error as? SecureLanError ?? .network) }
    }
}
