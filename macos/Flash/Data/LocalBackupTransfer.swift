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

/// Android/macOS 共用协议：Bonjour 发现 + 单次 TCP 传输；PIN 60 秒有效，最多尝试五次。
final class LocalBackupSender: @unchecked Sendable {
    static let serviceType = "_flashbackup._tcp"
    static let sessionDuration: TimeInterval = 60
    private static let protocolLine = "FLASH-AERO/1"

    let pin = LocalBackupSender.generatePIN()
    private let listener: NWListener
    private let payload: Data
    private let queue = DispatchQueue(label: "com.flash.app.local-transfer.sender")
    private let onFinish: @Sendable (Bool) -> Void
    private var attempts = 0
    private var finished = false

    static func generatePIN() -> String {
        String(format: "%04d", Int.random(in: 0...9_999))
    }

    init(json: String, onFinish: @escaping @Sendable (Bool) -> Void) throws {
        payload = Data(json.utf8)
        self.onFinish = onFinish
        listener = try NWListener(using: .tcp, on: .any)
        let deviceName = Host.current().localizedName ?? "Mac"
        listener.service = .init(name: "Flash Aero (\(deviceName.prefix(24)))",
                                 type: Self.serviceType)
        listener.newConnectionHandler = { [weak self] connection in self?.accept(connection) }
        listener.stateUpdateHandler = { [weak self] state in
            if case .failed = state { self?.finish(sent: false) }
        }
    }

    func start() {
        listener.start(queue: queue)
        queue.asyncAfter(deadline: .now() + Self.sessionDuration) { [weak self] in
            self?.finish(sent: false)
        }
    }

    func cancel() { queue.async { [weak self] in self?.finish(sent: false) } }

    private func accept(_ connection: NWConnection) {
        connection.start(queue: queue)
        receiveLine(from: connection, buffer: Data()) { [weak self] line in
            guard let self else { connection.cancel(); return }
            guard line == "\(Self.protocolLine) \(pin)" else {
                attempts += 1
                connection.send(content: Data("ERR PIN\n".utf8), completion: .contentProcessed { _ in
                    connection.cancel()
                })
                if attempts >= 5 { finish(sent: false) }
                return
            }
            var response = Data("OK \(payload.count)\n".utf8)
            response.append(payload)
            connection.send(content: response, completion: .contentProcessed { [weak self] error in
                connection.cancel()
                self?.finish(sent: error == nil)
            })
        }
    }

    private func receiveLine(from connection: NWConnection, buffer: Data,
                             completion: @escaping @Sendable (String?) -> Void) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 64) { [weak self] data, _, complete, error in
            var next = buffer
            if let data { next.append(data) }
            if let newline = next.firstIndex(of: 0x0A) {
                completion(String(decoding: next[..<newline], as: UTF8.self).trimmingCharacters(in: .newlines))
            } else if error != nil || complete || next.count >= 64 {
                completion(nil)
            } else {
                self?.receiveLine(from: connection, buffer: next, completion: completion)
            }
        }
    }

    private func finish(sent: Bool) {
        guard !finished else { return }
        finished = true
        listener.cancel()
        onFinish(sent)
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
    private let connection: NWConnection
    private let queue = DispatchQueue(label: "com.flash.app.local-transfer.receiver")
    private let completion: @Sendable (Result<String, Error>) -> Void
    private var finished = false
    private var buffer = Data()
    private var expectedSize: Int?

    init(device: LocalTransferDevice, pin: String,
         completion: @escaping @Sendable (Result<String, Error>) -> Void) {
        connection = NWConnection(to: device.endpoint, using: .tcp)
        self.completion = completion
        connection.stateUpdateHandler = { [weak self] state in
            guard let self else { return }
            switch state {
            case .ready:
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
        connection.start(queue: queue)
        queue.asyncAfter(deadline: .now() + 15) { [weak self] in
            self?.complete(.failure(LocalTransferError.timedOut))
        }
    }

    func cancel() { queue.async { [weak self] in self?.complete(.failure(LocalTransferError.interrupted)) } }

    private func receiveMore() {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { [weak self] data, _, isComplete, error in
            guard let self else { return }
            if let data { buffer.append(data) }
            if expectedSize == nil, let newline = buffer.firstIndex(of: 0x0A) {
                let header = String(decoding: buffer[..<newline], as: UTF8.self)
                buffer.removeSubrange(...newline)
                if header == "ERR PIN" { self.complete(.failure(LocalTransferError.invalidPIN)); return }
                guard header.hasPrefix("OK "), let size = Int(header.dropFirst(3)),
                      size > 0, size <= BackupService.maxFileBytes else {
                    self.complete(.failure(LocalTransferError.invalidResponse)); return
                }
                expectedSize = size
            }
            if let expectedSize, buffer.count >= expectedSize {
                let json = String(decoding: buffer.prefix(expectedSize), as: UTF8.self)
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

    func startSending(json: String) {
        cancel()
        do {
            let sender = try LocalBackupSender(json: json) { [weak self] sent in
                Task { @MainActor in
                    guard let self, self.mode == .sending else { return }
                    self.sender = nil
                    self.mode = .idle
                    if sent { self.sendCompleted = true }
                    else { self.errorMessage = "配对已结束，请重新发起" }
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
        let receiver = LocalBackupReceiver(device: selectedDevice, pin: enteredPIN) { [weak self] result in
            Task { @MainActor in
                guard let self, self.mode == .connecting else { return }
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
        sender?.cancel(); sender = nil
        browser?.cancel(); browser = nil
        receiver?.cancel(); receiver = nil
        mode = .idle
        pin = ""; devices = []; selectedDevice = nil; enteredPIN = ""
    }
}
