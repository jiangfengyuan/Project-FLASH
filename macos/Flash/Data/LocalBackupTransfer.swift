// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import Observation
import CryptoKit
import Security
@preconcurrency import Network

/// 局域网握手 v1.1（docs/contracts/lan-handshake-v1.1.md，三端逐字一致）：
/// 接收方先发 `CHALLENGE <nonce>`，发送方以 `FLASH-AERO/1 <proof>` 证明 PIN 知识，
/// 通过后发送 `OK <size> <mac>` + payload，mac 校验失败整体丢弃。
enum LanHandshake {
    static let protocolLine = "FLASH-AERO/1"
    static let challengePrefix = "CHALLENGE"
    static let okPrefix = "OK"
    static let errPINLine = "ERR PIN"
    /// CHALLENGE/proof 行的缓冲上限：规格「头行 ≤ 64 字节」，两者实际 41/45 字节
    static let maxLineBytes = 64
    /// OK 行上限 = "OK "(3) + 8 位十进制 size（size ≤ 50MB）+ " "(1) + 64 位 hex mac。
    /// 规格 §3 的 OK 行携带 64 字符 mac（共 76 字节），超出旧 64 字节头限，
    /// 以 §3 线格式为准收紧到合法发送方的最大行长（详见审计报告）。
    static let maxOKHeaderBytes = 76
    /// proof 消息前缀：msg = "flash-aero-handshake:" || nonce
    static let proofMessagePrefix = "flash-aero-handshake:"
    static let proofByteCount = 16   // proof 取 HMAC 前 16 字节（32 个 hex 字符）
    static let macByteCount = 32     // payload mac 取 HMAC 前 32 字节（64 个 hex 字符）

    /// 16 字节密码学安全随机数的 lowercase hex（每连接独立 nonce）
    static func makeNonce() -> String {
        var bytes = [UInt8](repeating: 0, count: 16)
        let status = bytes.withUnsafeMutableBytes {
            SecRandomCopyBytes(kSecRandomDefault, 16, $0.baseAddress!)
        }
        precondition(status == errSecSuccess)
        return hexString(bytes)
    }

    /// proof = hex(HMAC-SHA256(key = PIN ASCII, msg = "flash-aero-handshake:" || nonce))[0:32]
    static func proof(pin: String, nonce: String) -> String {
        let message = Array(proofMessagePrefix.utf8) + Array(nonce.utf8)
        return hexString(hmacSHA256(key: Array(pin.utf8), message: message).prefix(proofByteCount))
    }

    /// payload mac = hex(HMAC-SHA256(key = PIN ASCII, msg = payload))[0:64]
    static func payloadMAC(pin: String, payload: Data) -> String {
        hexString(hmacSHA256(key: Array(pin.utf8), message: Array(payload)).prefix(macByteCount))
    }

    /// 校验接收的 payload mac；不等即整体丢弃（常数时间比较）
    static func verifyPayloadMAC(pin: String, macHex: String, payload: Data) -> Bool {
        guard let received = hexBytes(macHex), received.count == macByteCount else { return false }
        let expected = Array(hmacSHA256(key: Array(pin.utf8), message: Array(payload)).prefix(macByteCount))
        return constantTimeEqual(received, expected)
    }

    static func hmacSHA256(key: [UInt8], message: [UInt8]) -> [UInt8] {
        let symmetricKey = SymmetricKey(data: Data(key))
        return Array(HMAC<SHA256>.authenticationCode(for: Data(message), using: symmetricKey))
    }

    /// CryptoKit 无内建常数时间比较，手写逐字节异或（与 Android MessageDigest.isEqual 对齐）
    static func constantTimeEqual(_ lhs: [UInt8], _ rhs: [UInt8]) -> Bool {
        guard lhs.count == rhs.count else { return false }
        var difference: UInt8 = 0
        for index in lhs.indices {
            difference |= lhs[index] ^ rhs[index]
        }
        return difference == 0
    }

    /// 严格解析 CHALLENGE 行：`CHALLENGE <32 位 hex nonce>`；格式不符返回 nil
    static func parseChallengeLine(_ line: String) -> String? {
        let parts = line.split(separator: " ", omittingEmptySubsequences: false)
        guard parts.count == 2, parts[0] == challengePrefix else { return nil }
        let nonce = String(parts[1])
        guard nonce.count == 32, hexBytes(nonce) != nil else { return nil }
        return nonce
    }

    /// 严格解析 proof 行：`FLASH-AERO/1 <32 位 hex proof>`，返回解码后的 16 字节 proof
    static func parseProofLine(_ line: String) -> [UInt8]? {
        guard line.hasPrefix("\(protocolLine) ") else { return nil }
        let proofHex = line.dropFirst(protocolLine.count + 1)
        guard proofHex.count == 32, let bytes = hexBytes(proofHex), bytes.count == proofByteCount else {
            return nil
        }
        return bytes
    }

    /// 严格解析 OK 行：`OK <size> <mac>`；size 必须纯十进制（拒绝尾随/前导字符），
    /// mac 必须 64 位 hex；任一不符返回 nil
    static func parseOKHeader(_ line: String) -> (size: Int, macHex: String)? {
        let parts = line.split(separator: " ", omittingEmptySubsequences: false)
        guard parts.count == 3, parts[0] == okPrefix else { return nil }
        let sizeText = parts[1]
        guard !sizeText.isEmpty, sizeText.allSatisfy({ $0.isASCII && $0.isNumber }) else { return nil }
        guard let size = Int(sizeText), size > 0 else { return nil }
        let macHex = String(parts[2])
        guard macHex.count == macByteCount * 2, hexBytes(macHex) != nil else { return nil }
        return (size, macHex)
    }

    static func hexString<S: Sequence>(_ bytes: S) -> String where S.Element == UInt8 {
        bytes.map { String(format: "%02x", $0) }.joined()
    }

    static func hexBytes(_ text: some StringProtocol) -> [UInt8]? {
        let characters = Array(text)
        guard characters.count % 2 == 0 else { return nil }
        var bytes: [UInt8] = []
        bytes.reserveCapacity(characters.count / 2)
        var index = 0
        while index < characters.count {
            guard let high = hexValue(characters[index]),
                  let low = hexValue(characters[index + 1]) else { return nil }
            bytes.append(high << 4 | low)
            index += 2
        }
        return bytes
    }

    private static func hexValue(_ character: Character) -> UInt8? {
        guard let scalar = character.asciiValue else { return nil }
        switch scalar {
        case 0x30...0x39: return scalar - 0x30
        case 0x61...0x66: return scalar - 0x61 + 10
        case 0x41...0x46: return scalar - 0x41 + 10
        default: return nil
        }
    }
}

struct LocalTransferDevice: Identifiable, Hashable, @unchecked Sendable {
    /// 设备条目键：host:port（规格 v1.1 设备发现）；同名伪造服务不同主机并列显示、互不顶替
    let id: String
    let name: String
    let endpoint: NWEndpoint
}

enum LocalTransferError: Error, LocalizedError {
    case invalidPIN, invalidResponse, invalidSize, interrupted, timedOut, payloadTampered

    var errorDescription: String? {
        switch self {
        case .invalidPIN: "PIN 不正确"
        case .invalidResponse: "发送方返回了无效响应"
        case .invalidSize: "接收的备份文件大小异常"
        case .interrupted: "连接中断，备份未接收完整"
        case .timedOut: "配对已超时"
        case .payloadTampered: "备份内容校验失败（可能被篡改），已整体丢弃，请重新发送"
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

/// 握手计时配置（默认值即规格口径；测试可注入缩小以覆盖退避/超时路径）
struct LocalTransferTiming: Sendable {
    var sessionDuration: TimeInterval = 60
    /// 连接空闲超时 15s 不变：握手或传输中无数据到达超过该值即断开
    var idleTimeout: TimeInterval = 15
    /// 传输总时长硬顶 120s（防慢速滴流占用缓冲与连接槽），与空闲超时先到先触发
    var transferLimit: TimeInterval = 120
    /// 发送完成后等待对端正常关闭连接的确认窗口
    var closeConfirmTimeout: TimeInterval = 5
    /// proof 验证失败的响应延迟：第 1–4 次失败按 1s、2s、4s、8s 递增
    var failureBackoff: [TimeInterval] = [1, 2, 4, 8]
    /// 每连接 proof 验证最多尝试次数，第 5 次失败即断开该连接并计数
    var maxAttempts = 5
}

/// macOS 端为「发送方」角色（显示 PIN 的一端）：Bonjour 监听 + CHALLENGE 校验对端 proof，
/// 通过后发送带 HMAC 的 OK 行与负载。规格：PIN 6 位、会话 60s、每连接最多 5 次尝试。
final class LocalBackupSender: @unchecked Sendable {
    static let serviceType = "_flashbackup._tcp"
    static let sessionDuration: TimeInterval = 60
    private let timing: LocalTransferTiming

    let pin = LocalBackupSender.generatePIN()
    private let listener: NWListener
    private let payload: Data
    private let queue = DispatchQueue(label: "com.flash.app.local-transfer.sender")
    private let onFinish: @Sendable (LocalBackupSendResult) -> Void
    private var attempts = 0
    private var finished = false
    private var activeConnection: NWConnection?
    /// 当前连接的握手空闲计时（仅 queue 上访问；单连接槽保证不会跨连接串扰）
    private var handshakeIdle = IdleDeadline(timeout: 15)
    /// 当前连接建立时刻：总时长硬顶（120s）的起点
    private var transferStart = Date()
    /// proof 已通过：此后不再判握手空闲（大文件慢发不被误杀），只剩总时长硬顶
    private var handshakeComplete = false

    /// 监听端口（listener ready 后置位，ready 前为 0；供测试回环连接）
    var port: UInt16? {
        let raw = listener.port?.rawValue
        return (raw == nil || raw == 0) ? nil : raw
    }

    static func generatePIN() -> String {
        String(format: "%06d", Int.random(in: 0...999_999))
    }

    init(json: String, timing: LocalTransferTiming = LocalTransferTiming(),
         onFinish: @escaping @Sendable (LocalBackupSendResult) -> Void) throws {
        self.timing = timing
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
        queue.asyncAfter(deadline: .now() + timing.sessionDuration) { [weak self] in
            self?.finish(.failed)
        }
    }

    func cancel() { queue.async { [weak self] in self?.finish(.failed) } }

    /// 握手行分类（对齐规格）：proof 形状合法（协议头 + 32 位 hex）才与本地 proof 常数时间比较，
    /// 不等计为 wrongPIN；非协议流量（nil/格式非法，如端口扫描）直接断开，不消耗配对机会。
    enum HandshakeVerdict: Equatable, Sendable { case ok, wrongPIN, notProtocol }

    static func classifyHandshake(_ line: String?, pin: String, nonce: String) -> HandshakeVerdict {
        guard let line, let receivedProof = LanHandshake.parseProofLine(line) else { return .notProtocol }
        let message = Array(LanHandshake.proofMessagePrefix.utf8) + Array(nonce.utf8)
        let expected = Array(LanHandshake.hmacSHA256(key: Array(pin.utf8), message: message)
            .prefix(LanHandshake.proofByteCount))
        return LanHandshake.constantTimeEqual(receivedProof, expected) ? .ok : .wrongPIN
    }

    private func accept(_ connection: NWConnection) {
        // 同一时间只处理一个配对请求，避免攻击者预先并发建立大量连接绕过每连接五次限制。
        guard !finished, activeConnection == nil else {
            connection.cancel()
            return
        }
        activeConnection = connection
        attempts = 0 // 规格：proof 失败按连接计数，每连接最多 5 次
        handshakeComplete = false
        transferStart = Date()
        handshakeIdle = IdleDeadline(timeout: timing.idleTimeout)
        let nonce = LanHandshake.makeNonce()
        connection.start(queue: queue)
        scheduleConnectionCheck(for: connection)
        // 连接建立后立即发送挑战行（规格第一步）
        let challenge = Data("CHALLENGE \(nonce)\n".utf8)
        connection.send(content: challenge, completion: .contentProcessed { [weak self] error in
            guard let self else {
                connection.cancel()
                return
            }
            guard error == nil, !self.finished, self.activeConnection === connection else {
                connection.cancel()
                if self.activeConnection === connection { self.activeConnection = nil }
                return
            }
            self.receiveProof(from: connection, nonce: nonce, buffer: Data())
        })
    }

    private func handleProofLine(_ line: String, nonce: String, connection: NWConnection) {
        switch Self.classifyHandshake(line, pin: pin, nonce: nonce) {
        case .ok:
            handshakeComplete = true
            var response = Data("OK \(payload.count) \(LanHandshake.payloadMAC(pin: pin, payload: payload))\n".utf8)
            response.append(payload)
            connection.send(content: response, completion: .contentProcessed { [weak self] error in
                guard let self else {
                    connection.cancel()
                    return
                }
                guard error == nil else {
                    connection.cancel()
                    self.finish(.failed)
                    return
                }
                self.awaitPeerClose(connection)
            })
        case .wrongPIN:
            attempts += 1
            guard attempts < timing.maxAttempts else {
                // 第 5 次失败：断开该连接并计数；会话 60s 窗口不变，仍可重新配对
                connection.cancel()
                activeConnection = nil
                return
            }
            // 第 1–4 次失败：按 1s/2s/4s/8s 递增延迟后响应 ERR PIN；
            // 连接保持开放，等待同一连接上的下一次 proof 尝试（每连接最多 5 次）
            let delay = timing.failureBackoff[min(attempts - 1, timing.failureBackoff.count - 1)]
            queue.asyncAfter(deadline: .now() + delay) { [weak self, weak connection] in
                guard let self, let connection,
                      !self.finished, self.activeConnection === connection else { return }
                connection.send(content: Data("\(LanHandshake.errPINLine)\n".utf8),
                                completion: .contentProcessed { [weak self] _ in
                    guard let self, !self.finished, self.activeConnection === connection else {
                        connection.cancel()
                        return
                    }
                    self.receiveProof(from: connection, nonce: nonce, buffer: Data())
                })
            }
        case .notProtocol:
            // 非协议流量：不回复、不计数，直接断开（与规格一致）
            connection.cancel()
            activeConnection = nil
        }
    }

    /// 连接检查：握手阶段判空闲超时（有数据到达即续期）；任一阶段都受总时长硬顶约束，
    /// 两者先到先触发。
    private func scheduleConnectionCheck(for connection: NWConnection) {
        let elapsed = Date().timeIntervalSince(transferStart)
        let totalRemaining = max(0, timing.transferLimit - elapsed)
        let wait = handshakeComplete ? totalRemaining : min(handshakeIdle.remaining(), totalRemaining)
        queue.asyncAfter(deadline: .now() + wait) { [weak self, weak connection] in
            guard let self, let connection,
                  !self.finished, self.activeConnection === connection else { return }
            if Date().timeIntervalSince(self.transferStart) >= self.timing.transferLimit {
                connection.cancel()
                self.activeConnection = nil
                return
            }
            if !self.handshakeComplete && self.handshakeIdle.isExpired() {
                connection.cancel()
                self.activeConnection = nil
                return
            }
            self.scheduleConnectionCheck(for: connection)
        }
    }

    /// 发送完成后等待对端收完并正常关闭连接（接收方成功收完会关 socket）：
    /// 正常关闭确认送达；超时或异常断开只代表未能确认，降级提示而不判失败。
    private func awaitPeerClose(_ connection: NWConnection) {
        queue.asyncAfter(deadline: .now() + timing.closeConfirmTimeout) { [weak self, weak connection] in
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

    private func receiveProof(from connection: NWConnection, nonce: String,
                              buffer: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: LanHandshake.maxLineBytes) { [weak self] data, _, complete, error in
            var next = buffer
            if let data {
                next.append(data)
                self?.handshakeIdle.reset()
            }
            if let newline = next.firstIndex(of: 0x0A) {
                let line = String(decoding: next[..<newline], as: UTF8.self)
                    .trimmingCharacters(in: .newlines)
                self?.handleProofLine(line, nonce: nonce, connection: connection)
            } else if error != nil || complete || next.count >= LanHandshake.maxLineBytes {
                // 超长/异常且无换行：非协议流量，直接断开不计数
                connection.cancel()
                self?.activeConnection = nil
            } else {
                self?.receiveProof(from: connection, nonce: nonce, buffer: next)
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
    /// endpoint 描述 → 已解析设备（id = host:port）；同名服务在不同主机解析出不同键，并列显示
    private var devicesByEndpoint: [String: LocalTransferDevice] = [:]
    /// endpoint 描述 → 解析中的 NetService 盒（NetService 依赖 RunLoop，须在主线程启动解析）
    private var resolvers: [String: ServiceResolver] = [:]
    private var stopped = false

    init(onChange: @escaping @Sendable ([LocalTransferDevice]) -> Void) {
        self.onChange = onChange
        browser.browseResultsChangedHandler = { [weak self] results, _ in
            self?.handleResults(results)
        }
    }

    func start() { browser.start(queue: queue) }

    func cancel() {
        browser.cancel()
        queue.async { [weak self] in
            guard let self else { return }
            self.stopped = true
            for resolver in self.resolvers.values {
                resolver.stopOnMain()
            }
            self.resolvers.removeAll()
            self.devicesByEndpoint.removeAll()
        }
    }

    private func handleResults(_ results: Set<NWBrowser.Result>) {
        var seen = Set<String>()
        for result in results {
            guard case let .service(name, type, domain, _) = result.endpoint else { continue }
            let key = String(describing: result.endpoint)
            seen.insert(key)
            guard devicesByEndpoint[key] == nil, resolvers[key] == nil else { continue }
            let delegate = ServiceResolverDelegate { [weak self] resolved in
                // 回调在主线程：切回浏览队列装配，保证设备表的单线程访问
                guard let browser = self else { return }
                browser.queue.async {
                    guard !browser.stopped, browser.resolvers[key] != nil else { return }
                    browser.resolvers.removeValue(forKey: key)
                    if case let .resolved(host, port) = resolved {
                        // 规格 v1.1：设备条目键改为 host:port（同名伪造服务不得互相顶替）
                        let id = "\(host):\(port)"
                        guard !browser.devicesByEndpoint.values.contains(where: { $0.id == id }) else { return }
                        browser.devicesByEndpoint[key] = LocalTransferDevice(
                            id: id, name: name,
                            endpoint: .hostPort(host: .name(host, nil),
                                                port: NWEndpoint.Port(rawValue: port)!))
                    }
                    browser.emitDevices()
                }
            }
            let service = NetService(domain: domain, type: type, name: name)
            service.delegate = delegate
            resolvers[key] = ServiceResolver(service: service, delegate: delegate)
            // NetService 的异步解析依赖 RunLoop，主线程创建并启动
            DispatchQueue.main.async {
                service.resolve(withTimeout: 5)
            }
        }
        // 消失的服务：移除已解析条目并取消进行中的解析
        for key in devicesByEndpoint.keys where !seen.contains(key) {
            devicesByEndpoint.removeValue(forKey: key)
        }
        for key in resolvers.keys where !seen.contains(key) {
            if let resolver = resolvers.removeValue(forKey: key) {
                resolver.stopOnMain()
            }
        }
        emitDevices()
    }

    private func emitDevices() {
        let devices = devicesByEndpoint.values.sorted {
            $0.name == $1.name ? $0.id < $1.id : $0.name < $1.name
        }
        onChange(devices)
    }
}

/// NetService 解析回调结果
private enum ServiceResolution {
    case resolved(host: String, port: UInt16)
    case failed
}

/// 解析中的服务盒：NetService 创建后跨队列仅做 start/stop（线程安全），
/// 结果经 delegate 闭包回浏览器队列装配
private final class ServiceResolver: @unchecked Sendable {
    let service: NetService
    let delegate: ServiceResolverDelegate

    init(service: NetService, delegate: ServiceResolverDelegate) {
        self.service = service
        self.delegate = delegate
    }

    func stopOnMain() {
        let service = self.service
        DispatchQueue.main.async { service.stop() }
    }
}

/// NetService 解析回调桥：把主 RunLoop 上的解析结果转成交付闭包
private final class ServiceResolverDelegate: NSObject, NetServiceDelegate, @unchecked Sendable {
    private let onResolved: @Sendable (ServiceResolution) -> Void
    private var delivered = false

    init(onResolved: @escaping @Sendable (ServiceResolution) -> Void) {
        self.onResolved = onResolved
    }

    func netServiceDidResolveAddress(_ sender: NetService) {
        defer { sender.stop() }
        guard let host = sender.hostName, !host.isEmpty,
              sender.port > 0, sender.port <= 65535 else {
            deliver(.failed)
            return
        }
        deliver(.resolved(host: host, port: UInt16(sender.port)))
    }

    func netService(_ sender: NetService, didNotResolve errorDict: [String: NSNumber]) {
        deliver(.failed)
        sender.stop()
    }

    private func deliver(_ result: ServiceResolution) {
        guard !delivered else { return }
        delivered = true
        onResolved(result)
    }
}

/// macOS 端为「接收方」角色（输入 PIN 的一端）：连接后等待 CHALLENGE，
/// 用 PIN 计算 proof 回证，收满 payload 后校验 mac，篡改整体丢弃。
final class LocalBackupReceiver: @unchecked Sendable {
    /// 空闲上限：无数据到达超过该值才判超时（握手或传输中有数据到达即续期）
    private static let idleTimeout: TimeInterval = 15
    /// 传输总时长硬顶：与空闲超时先到先触发
    private static let transferLimit: TimeInterval = 120
    private let connection: NWConnection
    private let queue = DispatchQueue(label: "com.flash.app.local-transfer.receiver")
    private let completion: @Sendable (Result<String, Error>) -> Void
    private let pin: String
    private let idleTimeout: TimeInterval
    private let transferLimit: TimeInterval
    private var finished = false
    private var buffer = Data()
    private var challenge: String?
    private var expectedSize: Int?
    private var expectedMACHex: String?
    /// 连接建立时刻：总时长硬顶的起点
    private let startedAt = Date()
    /// 空闲计时（仅 queue 上访问）：区分握手与传输，大文件慢速传输不被误杀
    private var idle: IdleDeadline?

    init(device: LocalTransferDevice, pin: String,
         idleTimeout: TimeInterval = LocalBackupReceiver.idleTimeout,
         transferLimit: TimeInterval = LocalBackupReceiver.transferLimit,
         completion: @escaping @Sendable (Result<String, Error>) -> Void) {
        self.pin = pin
        self.idleTimeout = idleTimeout
        self.transferLimit = transferLimit
        self.connection = NWConnection(to: device.endpoint, using: .tcp)
        self.completion = completion
        connection.stateUpdateHandler = { [weak self] state in
            guard let self else { return }
            switch state {
            case .ready:
                idle?.reset()
                receiveMore() // v1.1：先等待对端 CHALLENGE 行
            case .failed(let error): complete(.failure(error))
            default: break
            }
        }
    }

    func start() {
        idle = IdleDeadline(timeout: idleTimeout)
        connection.start(queue: queue)
        scheduleIdleCheck()
    }

    func cancel() { queue.async { [weak self] in self?.complete(.failure(LocalTransferError.interrupted)) } }

    /// 空闲检查随接收进度续期：到点时若期间有数据到达则按新 deadline 重新安排；
    /// 同时受总时长硬顶约束，按先到者安排下一次检查，两者先到先触发。
    private func scheduleIdleCheck() {
        let idleRemaining = idle?.remaining() ?? idleTimeout
        let totalRemaining = max(0, transferLimit - Date().timeIntervalSince(startedAt))
        queue.asyncAfter(deadline: .now() + min(idleRemaining, totalRemaining)) { [weak self] in
            guard let self, !self.finished, let idle = self.idle else { return }
            if Date().timeIntervalSince(self.startedAt) >= self.transferLimit || idle.isExpired() {
                self.complete(.failure(LocalTransferError.timedOut))
            } else {
                self.scheduleIdleCheck()
            }
        }
    }

    /// 收到 CHALLENGE 后用本地 PIN 计算 proof 回证
    private func sendProof(forNonce nonce: String) {
        let line = Data("\(LanHandshake.protocolLine) \(LanHandshake.proof(pin: pin, nonce: nonce))\n".utf8)
        connection.send(content: line, completion: .contentProcessed { [weak self] error in
            guard let self else { return }
            if let error {
                self.complete(.failure(error))
            } else {
                self.receiveMore()
            }
        })
    }

    private func receiveMore() {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { [weak self] data, _, isComplete, error in
            guard let self else { return }
            if let data {
                buffer.append(data)
                idle?.reset()
            }
            // 头行（CHALLENGE / OK）在收到换行前检查缓冲上限
            if challenge == nil || expectedSize == nil, let newline = buffer.firstIndex(of: 0x0A) {
                let limit = challenge == nil ? LanHandshake.maxLineBytes : LanHandshake.maxOKHeaderBytes
                guard newline <= limit else {
                    self.complete(.failure(LocalTransferError.invalidResponse)); return
                }
                let header = String(decoding: buffer[..<newline], as: UTF8.self)
                buffer.removeSubrange(...newline)
                if challenge == nil {
                    guard let nonce = LanHandshake.parseChallengeLine(header) else {
                        self.complete(.failure(LocalTransferError.invalidResponse)); return
                    }
                    challenge = nonce
                    sendProof(forNonce: nonce)
                    return // proof 发送完成后再继续读 OK 行
                }
                if header == LanHandshake.errPINLine {
                    self.complete(.failure(LocalTransferError.invalidPIN)); return
                }
                guard let ok = LanHandshake.parseOKHeader(header),
                      ok.size <= BackupService.maxFileBytes else {
                    self.complete(.failure(LocalTransferError.invalidResponse)); return
                }
                expectedSize = ok.size
                expectedMACHex = ok.macHex
            } else if challenge == nil || expectedSize == nil {
                let limit = challenge == nil ? LanHandshake.maxLineBytes : LanHandshake.maxOKHeaderBytes
                guard buffer.count <= limit else {
                    self.complete(.failure(LocalTransferError.invalidResponse)); return
                }
            }
            if let expectedSize {
                if buffer.count >= expectedSize {
                    let payload = Data(buffer.prefix(expectedSize))
                    // mac 不等即整体丢弃并报错，不得进入解析/预览
                    guard LanHandshake.verifyPayloadMAC(pin: pin, macHex: expectedMACHex ?? "", payload: payload) else {
                        self.complete(.failure(LocalTransferError.payloadTampered)); return
                    }
                    guard let json = String(data: payload, encoding: .utf8) else {
                        self.complete(.failure(LocalTransferError.invalidResponse)); return
                    }
                    self.complete(.success(json))
                } else if error != nil || isComplete {
                    self.complete(.failure(error ?? LocalTransferError.interrupted))
                } else {
                    receiveMore()
                }
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
        guard let selectedDevice, enteredPIN.range(of: "^\\d{6}$", options: .regularExpression) != nil else {
            errorMessage = "请输入六位数字 PIN"
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
