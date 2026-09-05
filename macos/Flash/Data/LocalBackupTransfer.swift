// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import Observation
@preconcurrency import Network

struct LocalTransferDevice: Identifiable, Hashable, @unchecked Sendable {
    let id: String
    let name: String
    let endpoint: NWEndpoint
}

enum LocalTransferError: Error, LocalizedError {
    case invalidPIN, invalidResponse, invalidSize, interrupted, timedOut

    var errorDescription: String? {
        switch self {
        case .invalidPIN: "PIN 不正确"
        case .invalidResponse: "发送方返回了无效响应"
        case .invalidSize: "接收的备份文件大小异常"
        case .interrupted: "连接中断，备份未接收完整"
        case .timedOut: "配对已超时"
        }
    }
}

/// 局域网发送结果：confirmed 表示对端收完并正常关闭连接；unconfirmed 表示数据已发出
/// 但未能确认对方收完（对端异常断开或超时未关闭）；failed 表示未发送成功。
enum LocalBackupSendResult: Sendable {
    case confirmed, unconfirmed, failed
}

/// 空闲超时计时：每次收到数据 reset 续期，超过 timeout 无数据才判超时。
/// 与调度解耦（注入 now），可直接单测。
struct IdleDeadline: Equatable, Sendable {
    let timeout: TimeInterval
    private(set) var deadline: Date

    init(timeout: TimeInterval, now: Date = Date()) {
        self.timeout = timeout
        deadline = now.addingTimeInterval(timeout)
    }

    mutating func reset(now: Date = Date()) {
        deadline = now.addingTimeInterval(timeout)
    }

    func isExpired(now: Date = Date()) -> Bool { now >= deadline }

    /// 距超时剩余秒数（已过期为 0），用于安排下一次检查
    func remaining(now: Date = Date()) -> TimeInterval {
        max(0, deadline.timeIntervalSince(now))
    }
}

/// Android/macOS 共用协议：Bonjour 发现 + 单次 TCP 传输；PIN 60 秒有效，最多尝试五次。
final class LocalBackupSender: @unchecked Sendable {
    static let serviceType = "_flashbackup._tcp"
    static let sessionDuration: TimeInterval = 60
    private static let protocolLine = "FLASH-AERO/1"
    /// 已连接但未完成握手的空闲上限：无数据到达超过该值即断开，
    /// 防止占住唯一连接槽饿死合法配对（有数据到达即续期）
    private static let handshakeIdleTimeout: TimeInterval = 10
    /// 发送完成后等待对端正常关闭连接（收完即关 socket）的确认窗口
    private static let closeConfirmTimeout: TimeInterval = 5

    let pin = LocalBackupSender.generatePIN()
    private let listener: NWListener
    private let payload: Data
    private let queue = DispatchQueue(label: "com.flash.app.local-transfer.sender")
    private let onFinish: @Sendable (LocalBackupSendResult) -> Void
    private var attempts = 0
    private var finished = false
    private var activeConnection: NWConnection?
    /// 当前连接的握手空闲计时（仅 queue 上访问；单连接槽保证不会跨连接串扰）
    private var handshakeIdle = IdleDeadline(timeout: handshakeIdleTimeout)

    static func generatePIN() -> String {
        String(format: "%04d", Int.random(in: 0...9_999))
    }

    init(json: String, onFinish: @escaping @Sendable (LocalBackupSendResult) -> Void) throws {
        payload = Data(json.utf8)
        self.onFinish = onFinish
        listener = try NWListener(using: .tcp, on: .any)
        let deviceName = Host.current().localizedName ?? "Mac"
        listener.service = .init(name: "Flash Aero (\(deviceName.prefix(24)))",
                                 type: Self.serviceType)
        listener.newConnectionHandler = { [weak self] connection in self?.accept(connection) }
        listener.stateUpdateHandler = { [weak self] state in
            if case .failed = state { self?.finish(.failed) }
        }
    }

    func start() {
        listener.start(queue: queue)
        queue.asyncAfter(deadline: .now() + Self.sessionDuration) { [weak self] in
            self?.finish(.failed)
        }
    }

    func cancel() { queue.async { [weak self] in self?.finish(.failed) } }

    /// 握手行分类（对齐 Android serveSession）：协议头合法但 PIN 错误才计入尝试次数；
    /// 非协议流量（nil/格式非法，如端口扫描）直接断开，不消耗配对机会。
    enum HandshakeVerdict: Equatable, Sendable { case ok, wrongPIN, notProtocol }

    static func classifyHandshake(_ line: String?, pin: String) -> HandshakeVerdict {
        guard let line, line.hasPrefix("\(protocolLine) ") else { return .notProtocol }
        return line == "\(protocolLine) \(pin)" ? .ok : .wrongPIN
    }

    private func accept(_ connection: NWConnection) {
        // 同一时间只处理一个配对请求，避免攻击者预先并发建立大量连接绕过五次 PIN 限制。
        guard !finished, activeConnection == nil else {
            connection.cancel()
            return
        }
        activeConnection = connection
        handshakeIdle = IdleDeadline(timeout: Self.handshakeIdleTimeout)
        connection.start(queue: queue)
        scheduleHandshakeIdleCheck(for: connection)
        receiveLine(from: connection, buffer: Data()) { [weak self] line in
            guard let self else { connection.cancel(); return }
            guard !finished else { connection.cancel(); return }
            switch Self.classifyHandshake(line, pin: pin) {
            case .ok:
                var response = Data("OK \(payload.count)\n".utf8)
                response.append(payload)
                connection.send(content: response, completion: .contentProcessed { [weak self] error in
                    guard let self, error == nil else {
                        connection.cancel()
                        self?.finish(.failed)
                        return
                    }
                    self.awaitPeerClose(connection)
                })
            case .wrongPIN:
                attempts += 1
                connection.send(content: Data("ERR PIN\n".utf8), completion: .contentProcessed { [weak self] _ in
                    connection.cancel()
                    self?.activeConnection = nil
                })
                if attempts >= 5 { finish(.failed) }
            case .notProtocol:
                // 非协议流量：不回复、不计数，直接断开（与 Android serveSession 一致）
                connection.cancel()
                activeConnection = nil
            }
        }
    }

    /// 握手空闲检查：连接建立后未完成握手且无数据到达超过 timeout 即断开，
    /// 防止占住唯一连接槽饿死合法配对；receiveLine 每收到一块数据即续期。
    private func scheduleHandshakeIdleCheck(for connection: NWConnection) {
        queue.asyncAfter(deadline: .now() + handshakeIdle.remaining()) { [weak self, weak connection] in
            guard let self, let connection,
                  !self.finished, self.activeConnection === connection else { return }
            if handshakeIdle.isExpired() {
                connection.cancel()
                self.activeConnection = nil
            } else {
                self.scheduleHandshakeIdleCheck(for: connection)
            }
        }
    }

    /// 发送完成后等待对端收完并正常关闭连接（接收方成功收完会关 socket）：
    /// 正常关闭确认送达；超时或异常断开只代表未能确认，降级提示而不判失败。
    /// 仅利用对端既有的关连接行为，不改协议线格式。
    private func awaitPeerClose(_ connection: NWConnection) {
        queue.asyncAfter(deadline: .now() + Self.closeConfirmTimeout) { [weak self, weak connection] in
            guard let self, let connection,
                  !self.finished, self.activeConnection === connection else { return }
            connection.cancel()
            self.finish(.unconfirmed)
        }
        connection.receive(minimumIncompleteLength: 1, maximumLength: 1) { [weak self, weak connection] _, _, isComplete, error in
            guard let self, let connection,
                  !self.finished, self.activeConnection === connection else { return }
            connection.cancel()
            // 对端正常关闭（FIN）才算确认收完；RST/异常断开降级为 unconfirmed
            self.finish(isComplete && error == nil ? .confirmed : .unconfirmed)
        }
    }

    private func receiveLine(from connection: NWConnection, buffer: Data,
                             completion: @escaping @Sendable (String?) -> Void) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 64) { [weak self] data, _, complete, error in
            var next = buffer
            if let data {
                next.append(data)
                self?.handshakeIdle.reset()
            }
            if let newline = next.firstIndex(of: 0x0A) {
                completion(String(decoding: next[..<newline], as: UTF8.self).trimmingCharacters(in: .newlines))
            } else if error != nil || complete || next.count >= 64 {
                completion(nil)
            } else {
                self?.receiveLine(from: connection, buffer: next, completion: completion)
            }
        }
    }

    private func finish(_ result: LocalBackupSendResult) {
        guard !finished else { return }
        finished = true
        activeConnection?.cancel()
        activeConnection = nil
        listener.cancel()
        onFinish(result)
    }
}

final class LocalBackupBrowser: @unchecked Sendable {
    private let browser = NWBrowser(for: .bonjour(type: LocalBackupSender.serviceType, domain: nil), using: .tcp)
    private let queue = DispatchQueue(label: "com.flash.app.local-transfer.browser")
    private let onChange: @Sendable ([LocalTransferDevice]) -> Void

    init(onChange: @escaping @Sendable ([LocalTransferDevice]) -> Void) {
        self.onChange = onChange
        browser.browseResultsChangedHandler = { results, _ in
            let devices = results.compactMap { result -> LocalTransferDevice? in
                guard case let .service(name, _, _, _) = result.endpoint else { return nil }
                return LocalTransferDevice(id: String(describing: result.endpoint),
                                           name: name, endpoint: result.endpoint)
            }.sorted { $0.name < $1.name }
            onChange(devices)
        }
    }

    func start() { browser.start(queue: queue) }
    func cancel() { browser.cancel() }
}

final class LocalBackupReceiver: @unchecked Sendable {
    private static let maxHeaderBytes = 64
    /// 空闲上限：无数据到达超过该值才判超时（握手或传输中有数据到达即续期）
    private static let idleTimeout: TimeInterval = 15
    private let connection: NWConnection
    private let queue = DispatchQueue(label: "com.flash.app.local-transfer.receiver")
    private let completion: @Sendable (Result<String, Error>) -> Void
    private var finished = false
    private var buffer = Data()
    private var expectedSize: Int?
    /// 空闲计时（仅 queue 上访问）：区分握手与传输，大文件慢速传输不被误杀
    private var idle: IdleDeadline?

    init(device: LocalTransferDevice, pin: String,
         completion: @escaping @Sendable (Result<String, Error>) -> Void) {
        connection = NWConnection(to: device.endpoint, using: .tcp)
        self.completion = completion
        connection.stateUpdateHandler = { [weak self] state in
            guard let self else { return }
            switch state {
            case .ready:
                idle?.reset()
                connection.send(content: Data("FLASH-AERO/1 \(pin)\n".utf8),
                                completion: .contentProcessed { [weak self] error in
                    if let error { self?.complete(.failure(error)) }
                    else { self?.receiveMore() }
                })
            case .failed(let error): complete(.failure(error))
            default: break
            }
        }
    }

    func start() {
        idle = IdleDeadline(timeout: Self.idleTimeout)
        connection.start(queue: queue)
        scheduleIdleCheck()
    }

    func cancel() { queue.async { [weak self] in self?.complete(.failure(LocalTransferError.interrupted)) } }

    /// 空闲检查随接收进度续期：到点时若期间有数据到达则按新 deadline 重新安排
    private func scheduleIdleCheck() {
        queue.asyncAfter(deadline: .now() + (idle?.remaining() ?? Self.idleTimeout)) { [weak self] in
            guard let self, !self.finished, let idle = self.idle else { return }
            if idle.isExpired() {
                self.complete(.failure(LocalTransferError.timedOut))
            } else {
                self.scheduleIdleCheck()
            }
        }
    }

    private func receiveMore() {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { [weak self] data, _, isComplete, error in
            guard let self else { return }
            if let data {
                buffer.append(data)
                idle?.reset()
            }
            if expectedSize == nil, let newline = buffer.firstIndex(of: 0x0A) {
                guard newline < Self.maxHeaderBytes else {
                    self.complete(.failure(LocalTransferError.invalidResponse)); return
                }
                let header = String(decoding: buffer[..<newline], as: UTF8.self)
                buffer.removeSubrange(...newline)
                if header == "ERR PIN" { self.complete(.failure(LocalTransferError.invalidPIN)); return }
                guard header.hasPrefix("OK "), let size = Int(header.dropFirst(3)),
                      size > 0, size <= BackupService.maxFileBytes else {
                    self.complete(.failure(LocalTransferError.invalidResponse)); return
                }
                expectedSize = size
            } else if expectedSize == nil, buffer.count >= Self.maxHeaderBytes {
                self.complete(.failure(LocalTransferError.invalidResponse)); return
            }
            if let expectedSize, buffer.count >= expectedSize {
                let payload = Data(buffer.prefix(expectedSize))
                guard let json = String(data: payload, encoding: .utf8) else {
                    self.complete(.failure(LocalTransferError.invalidResponse)); return
                }
                self.complete(.success(json))
            } else if error != nil || isComplete {
                self.complete(.failure(error ?? LocalTransferError.interrupted))
            } else {
                receiveMore()
            }
        }
    }

    private func complete(_ result: Result<String, Error>) {
        guard !finished else { return }
        finished = true
        connection.cancel()
        completion(result)
    }
}

enum LocalTransferMode { case idle, sending, receiving, connecting }

@MainActor @Observable
final class LocalBackupTransferController {
    /// 共享实例：设置页切走时视图与 @State 一并销毁，进行中的传输需跨视图
    /// 生命周期继续；回到设置页时由 SettingsView 补消费 receivedJSON 等结果。
    static let shared = LocalBackupTransferController()

    var mode: LocalTransferMode = .idle
    var pin = ""
    var devices: [LocalTransferDevice] = []
    var selectedDevice: LocalTransferDevice?
    var enteredPIN = ""
    var receivedJSON: String?
    var errorMessage: String?
    var sendCompleted = false

    @ObservationIgnored private var sender: LocalBackupSender?
    @ObservationIgnored private var browser: LocalBackupBrowser?
    @ObservationIgnored private var receiver: LocalBackupReceiver?
    @ObservationIgnored private var generation = 0

    func startSending(json: String) {
        cancel()
        let session = generation
        do {
            let sender = try LocalBackupSender(json: json) { [weak self] result in
                Task { @MainActor in
                    guard let self, self.generation == session, self.mode == .sending else { return }
                    self.sender = nil
                    self.mode = .idle
                    switch result {
                    case .confirmed:
                        self.sendCompleted = true
                    case .unconfirmed:
                        self.errorMessage = "备份已发出，但未能确认对方已收完，请在对端设备确认导入结果"
                    case .failed:
                        self.errorMessage = "配对已结束，请重新发起"
                    }
                }
            }
            self.sender = sender
            pin = sender.pin
            mode = .sending
            sender.start()
        } catch {
            errorMessage = "无法启动局域网发送：\(error.localizedDescription)"
        }
    }

    func startReceiving() {
        cancel()
        mode = .receiving
        let browser = LocalBackupBrowser { [weak self] devices in
            Task { @MainActor in
                guard let self, self.mode == .receiving else { return }
                self.devices = devices
                if let selectedDevice = self.selectedDevice, !devices.contains(selectedDevice) {
                    self.selectedDevice = nil
                }
            }
        }
        self.browser = browser
        browser.start()
    }

    func connect() {
        guard let selectedDevice, enteredPIN.range(of: "^\\d{4}$", options: .regularExpression) != nil else {
            errorMessage = "请输入四位数字 PIN"
            return
        }
        browser?.cancel()
        browser = nil
        mode = .connecting
        let session = generation
        let receiver = LocalBackupReceiver(device: selectedDevice, pin: enteredPIN) { [weak self] result in
            Task { @MainActor in
                guard let self, self.generation == session, self.mode == .connecting else { return }
                self.receiver = nil
                switch result {
                case .success(let json):
                    self.mode = .idle
                    self.receivedJSON = json
                case .failure(let error):
                    self.errorMessage = "局域网接收失败：\(error.localizedDescription)"
                    self.startReceiving()
                }
            }
        }
        self.receiver = receiver
        receiver.start()
    }

    func cancel() {
        generation += 1
        sender?.cancel(); sender = nil
        browser?.cancel(); browser = nil
        receiver?.cancel(); receiver = nil
        mode = .idle
        sendCompleted = false
        pin = ""; devices = []; selectedDevice = nil; enteredPIN = ""
    }
}
