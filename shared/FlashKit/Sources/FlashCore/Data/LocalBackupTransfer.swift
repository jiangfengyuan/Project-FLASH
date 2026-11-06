// Copyright (c) 2026 Fengyuan Jiang · MPL-2.0
import Foundation
import Observation
@preconcurrency import Network
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

private final class LanBackgroundObserver: @unchecked Sendable {
    let token: NSObjectProtocol
    init(_ token: NSObjectProtocol) { self.token = token }
    deinit { NotificationCenter.default.removeObserver(token) }
}

public enum LocalBackupAvailability {
    // Flip only after the documented four-platform physical-device gates.
    public static let isEnabled = false
    public static let message = "局域网传输暂时停用：安全 LAN v2 正在验收。请使用‘导出备份’或‘系统分享’传输 JSON 文件；旧版 LAN 不再支持。"
}
public struct LocalTransferDevice: Identifiable, Hashable, @unchecked Sendable {
    public let id: String
    public let name: String
    public let endpoint: NWEndpoint
    public init(id: String, name: String, endpoint: NWEndpoint) {
        self.id = id; self.name = name; self.endpoint = endpoint
    }
}
public enum LocalTransferMode: Sendable { case idle, sending, receiving, connecting }
public enum LocalTransferPhase: Sendable {
    case idle, discovering, waiting, handshake, confirming, waitingForPeer, transferring, verifying, completed, failed
}

/// Discovery/lifecycle owner. Each connection gets fresh native keys and its own
/// callback generation. Public entry points stay closed until physical acceptance.
@MainActor @Observable
public final class LocalBackupTransferController {
    public static let shared = LocalBackupTransferController()
    public private(set) var mode: LocalTransferMode = .idle
    public private(set) var phase: LocalTransferPhase = .idle
    public private(set) var shortCode: [UInt16] = []
    public private(set) var devices: [LocalTransferDevice] = []
    public var selectedDevice: LocalTransferDevice?
    public var receivedJSON: String?
    public var errorMessage: String?
    public var sendCompleted = false
    @ObservationIgnored private let allowed: Bool
    @ObservationIgnored private var listener: NWListener?
    @ObservationIgnored private var browser: NWBrowser?
    @ObservationIgnored private var active: SecureLanConnection?
    @ObservationIgnored private var opening: Task<Void, Never>?
    @ObservationIgnored private var background: LanBackgroundObserver?
    @ObservationIgnored private var snapshot: SecureLanConnection.Snapshot?
    @ObservationIgnored private var generation: UInt64 = 0
    @ObservationIgnored private var connectionGeneration: UInt64 = 0
    @ObservationIgnored private var end: UInt64 = 0
    @ObservationIgnored private var retryAfter: UInt64 = 0
    @ObservationIgnored private var failures = 0
    @ObservationIgnored private var sending = false

    public convenience init() { self.init(allowCandidate: LocalBackupAvailability.isEnabled) }
    // Internal test seam, never an application setting or persisted preference.
    init(allowCandidate: Bool) {
        allowed = allowCandidate && SecureLanSession.available
        #if os(iOS)
        let notification = UIApplication.didEnterBackgroundNotification
        #else
        let notification = NSApplication.didResignActiveNotification
        #endif
        background = LanBackgroundObserver(NotificationCenter.default.addObserver(forName: notification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.cancel() }
        })
    }

    public func startSending(snapshot: @escaping @MainActor @Sendable () async throws -> String) {
        guard begin(sender: true) else { return }
        self.snapshot = snapshot
        do {
            let listener = try NWListener(using: .tcp, on: .any)
            self.listener = listener
            let epoch = generation
            listener.service = .init(name: "Flash-" + UUID().uuidString.prefix(8), type: "_flashbackup2._tcp")
            listener.newConnectionHandler = { [weak self] connection in
                Task { @MainActor in
                    guard let self, self.generation == epoch, self.mode != .idle else { connection.cancel(); return }
                    self.attach(connection)
                }
            }
            listener.stateUpdateHandler = { [weak self] state in
                if case .failed = state { Task { @MainActor in
                    guard let self, self.generation == epoch else { return }; self.finishFailure(.network)
                } }
            }
            listener.start(queue: .main)
        } catch { finishFailure(.network) }
    }
    public func startReceiving() {
        guard begin(sender: false) else { return }
        let epoch = generation
        let browser = NWBrowser(for: .bonjour(type: "_flashbackup2._tcp", domain: nil), using: .tcp)
        self.browser = browser
        browser.browseResultsChangedHandler = { [weak self] results, _ in
            let found = results.map { result in
                let endpoint = result.endpoint
                let name: String
                if case .service(let service, _, _, _) = endpoint { name = String(service.prefix(80)) }
                else { name = "Flash" }
                return LocalTransferDevice(id: String(describing: endpoint), name: name, endpoint: endpoint)
            }.sorted { $0.id < $1.id }
            Task { @MainActor in
                guard let self, self.generation == epoch else { return }; self.devices = found
            }
        }
        browser.stateUpdateHandler = { [weak self] state in
            if case .failed = state { Task { @MainActor in
                guard let self, self.generation == epoch else { return }; self.finishFailure(.network)
            } }
        }
        browser.start(queue: .main)
    }
    public func connect() {
        guard allowed else { unavailable(); return }
        guard !sending, mode == .receiving, let selectedDevice, devices.contains(selectedDevice) else { return }
        attach(NWConnection(to: selectedDevice.endpoint, using: .tcp))
    }
    public func confirmMatch() { active?.confirm() }
    public func reject() { finishFailure(.unconfirmed) }
    private func begin(sender: Bool) -> Bool {
        cancel(); errorMessage = nil
        guard allowed else { unavailable(); return false }
        sending = sender; failures = 0; retryAfter = 0
        mode = sender ? .sending : .receiving; phase = sender ? .waiting : .discovering
        end = SecureLanConnection.now() + 120_000
        let epoch = generation
        opening = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(250))
                guard !Task.isCancelled, let self, self.generation == epoch else { return }
                // A connected session owns its separate transfer deadline.
                if self.active == nil, SecureLanConnection.now() >= self.end { self.finishFailure(.expired); return }
            }
        }
        return true
    }
    private func attach(_ connection: NWConnection) {
        let now = SecureLanConnection.now()
        guard active == nil, now < end, now >= retryAfter, failures < 3 else { connection.cancel(); return }
        connectionGeneration &+= 1
        let epoch = generation, attempt = connectionGeneration
        do {
            let channel = try SecureLanConnection(connection: connection, sender: sending, remaining: end - now,
                snapshot: snapshot) { [weak self] event in
                guard let self, self.generation == epoch, self.connectionGeneration == attempt else { return }
                switch event {
                case .phase(let phase): self.phase = phase
                case .code(let code): self.shortCode = code
                case .sent:
                    self.cleanup(); self.phase = .completed; self.sendCompleted = true
                case .received(let json):
                    self.cleanup(); self.phase = .completed; self.receivedJSON = json
                case .failed(let error): self.connectionFailed(error)
                }
            }
            active = channel; mode = .connecting; phase = .handshake; channel.start()
        } catch { connection.cancel(); connectionFailed(error as? SecureLanError ?? .network) }
    }
    private func connectionFailed(_ error: SecureLanError) {
        active?.cancel(); active = nil; shortCode = []; failures += 1
        if failures >= 3 || SecureLanConnection.now() >= end { finishFailure(error); return }
        retryAfter = SecureLanConnection.now() + UInt64(failures) * 1_000
        mode = sending ? .sending : .receiving; phase = sending ? .waiting : .discovering
        // Unauthenticated peer errors affect this connection only. The same
        // opening deadline and attempt budget apply to the next fresh session.
    }
    private func finishFailure(_ error: SecureLanError) {
        cleanup(); phase = .failed; errorMessage = error.userMessage
    }
    private func unavailable() { cancel(); phase = .failed; errorMessage = LocalBackupAvailability.message }
    private func cleanup() {
        generation &+= 1; connectionGeneration &+= 1
        opening?.cancel(); opening = nil
        active?.cancel(); active = nil
        listener?.cancel(); listener = nil; browser?.cancel(); browser = nil
        snapshot = nil; mode = .idle; shortCode = []; devices = []; selectedDevice = nil
    }
    public func cancel() {
        cleanup(); phase = .idle; receivedJSON = nil; sendCompleted = false
    }
}
