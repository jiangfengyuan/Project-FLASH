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

/// 局域网握手 v1.1（docs/contracts/lan-handshake-v1.1.md 修正版，三端逐字一致）：
/// 接收方（发起连接的一方）先发送 `CHALLENGE <nonceHex>`，发送方（监听方）以
/// `FLASH-AERO/1 <proof>` 证明 PIN 知识并流水线回出 `OK <size> <mac>` + payload，
/// 接收方验证 proof（每连接最多 5 次、1/2/4/8s 退避）并校验 payload mac。
enum LanHandshake {
    static let protocolLine = "FLASH-AERO/1"
    static let challengePrefix = "CHALLENGE"
    static let okPrefix = "OK"
    static let errPINLine = "ERR PIN"
    /// CHALLENGE/proof 行的缓冲上限：规格「≤ 64 字节」，两者实际 41/45 字节
    static let maxLineBytes = 64
    /// OK 行上限 = "OK "(3) + 8 位十进制 size（size ≤ 50MB）+ " "(1) + 64 位 hex mac。
    /// 规格允许统一取 128 字节缓冲；与 Android/HarmonyOS 保持一致。
    static let maxOKHeaderBytes = 128
    /// proof 消息前缀：msg = "flash-aero-handshake:" || nonceHex
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

    /// proof = hex(HMAC-SHA256(key = PIN ASCII, msg = "flash-aero-handshake:" || nonceHex))[0:32]
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

    /// 接收方校验 proof 行：形状须为 `FLASH-AERO/1 <32 位小写 hex>`，且与
    /// 本地 PIN + 刚发出的 nonceHex 重算的 proof 常数时间相等
    static func verifyProofLine(pin: String, nonce: String, line: String) -> Bool {
        guard let receivedProof = parseProofLine(line) else { return false }
        let message = Array(proofMessagePrefix.utf8) + Array(nonce.utf8)
        let expected = Array(hmacSHA256(key: Array(pin.utf8), message: message).prefix(proofByteCount))
        return constantTimeEqual(receivedProof, expected)
    }

    static func hmacSHA256(key: [UInt8], message: [UInt8]) -> [UInt8] {
        let symmetricKey = SymmetricKey(data: Data(key))
        return Array(HMAC<SHA256>.authenticationCode(for: Data(message), using: symmetricKey))
    }

    /// CryptoKit 无内建常数时间比较，手写逐字节异或（与 Android MessageDigest.isEqual / HarmonyOS 手写比较对齐）
    static func constantTimeEqual(_ lhs: [UInt8], _ rhs: [UInt8]) -> Bool {
        guard lhs.count == rhs.count else { return false }
        var difference: UInt8 = 0
        for index in lhs.indices {
            difference |= lhs[index] ^ rhs[index]
        }
        return difference == 0
    }

    /// 严格解析 CHALLENGE 行：`CHALLENGE <32 位小写 hex nonceHex>`；格式不符返回 nil
    static func parseChallengeLine(_ line: String) -> String? {
        let parts = line.split(separator: " ", omittingEmptySubsequences: false)
        guard parts.count == 2, parts[0] == challengePrefix else { return nil }
        let nonce = String(parts[1])
        guard nonce.count == 32, isLowerHex(nonce) else { return nil }
        return nonce
    }

    /// 严格解析 proof 行：`FLASH-AERO/1 <32 位小写 hex proof>`，返回解码后的 16 字节 proof
    static func parseProofLine(_ line: String) -> [UInt8]? {
        guard line.hasPrefix("\(protocolLine) ") else { return nil }
        let proofHex = line.dropFirst(protocolLine.count + 1)
        guard proofHex.count == 32, isLowerHex(proofHex), let bytes = hexBytes(proofHex),
              bytes.count == proofByteCount else { return nil }
        return bytes
    }

    /// 严格解析 OK 行：`OK <size> <mac>`；size 必须纯十进制（拒绝前导零、尾随字符、科学计数），
    /// mac 必须 64 位小写 hex；任一不符返回 nil
    static func parseOKHeader(_ line: String) -> (size: Int, macHex: String)? {
        let parts = line.split(separator: " ", omittingEmptySubsequences: false)
        guard parts.count == 3, parts[0] == okPrefix else { return nil }
        let sizeText = parts[1]
        guard !sizeText.isEmpty, sizeText.allSatisfy({ $0.isASCII && $0.isNumber }) else { return nil }
        // 规格：size 拒绝前导零（"0" 本身也因 size 必须为正被下游拒绝）
        guard sizeText.count == 1 || sizeText.first != "0" else { return nil }
        guard let size = Int(sizeText), size > 0 else { return nil }
        let macHex = String(parts[2])
        guard macHex.count == macByteCount * 2, isLowerHex(macHex) else { return nil }
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

    static func isLowerHex(_ text: some StringProtocol) -> Bool {
        text.allSatisfy { character in
            guard let scalar = character.asciiValue else { return false }
            return (0x30...0x39).contains(scalar) || (0x61...0x66).contains(scalar)
        }
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
/// 但未能确认对方收完（对端异常断开或超时未关闭）；failed 表示未发送成功/配对被拒绝。
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
    /// 连接空闲超时 15s 不变：有数据到达即续期
    var idleTimeout: TimeInterval = 15
    /// 传输总时长硬顶 120s（防慢速滴流占用缓冲与连接槽），与空闲超时先到先触发
    var transferLimit: TimeInterval = 120
    /// 发送完成后等待对端正常关闭连接的确认窗口
    var closeConfirmTimeout: TimeInterval = 5
    /// proof 验证失败的响应延迟（接收方执行）：第 1–4 次失败按 1s、2s、4s、8s 递增
    var failureBackoff: [TimeInterval] = [1, 2, 4, 8]
    /// proof 验证最多尝试次数（每连接），第 5 次失败即断开；发送方同连接最多服务 5 次挑战
    var maxAttempts = 5
}

/// macOS 端「发送方」角色：Bonjour 监听 + 屏幕显示 PIN，被动回答接收方的 CHALLENGE——
/// 对每个合规挑战流水线回出 `FLASH-AERO/1 <proof>`、`OK <size> <mac>` 与 payload，
/// 以此证明它知道 PIN（抵御伪造 mDNS 服务注入）。规格：PIN 6 位、会话 60s。
final class LocalBackupSender: @unchecked Sendable {
    static let serviceType = "_flashbackup._tcp"
    static let sessionDuration: TimeInterval = 60
    private let timing: LocalTransferTiming

    let pin = LocalBackupSender.generatePIN()
    private let listener: NWListener
    private let payload: Data
    /// payload mac 只与 PIN/payload 有关，预热缓存避免逐次重算
    private let payloadMacHex: String
    private let queue = DispatchQueue(label: "com.flash.app.local-transfer.sender")
    private let onFinish: @Sendable (LocalBackupSendResult) -> Void
    private var finished = false
    private var activeConnection: NWConnection?
    /// 当前连接已回答过挑战（回答后不再判握手空闲，只剩总时长硬顶与关连接确认）
    private var answered = false
    /// 当前连接收到的挑战数（每连接最多服务 maxAttempts 次）
    private var challenges = 0
    /// 回答代次：新挑战到达即递增，使旧的关连接确认计时失效（验证方可能继续挑战）
    private var answerGeneration = 0
    /// 当前连接的握手空闲计时（仅 queue 上访问；单连接槽保证不会跨连接串扰）
    private var handshakeIdle = IdleDeadline(timeout: 15)
    /// 当前连接建立时刻：总时长硬顶（120s）的起点
    private var transferStart = Date()

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
        payloadMacHex = LanHandshake.payloadMAC(pin: pin, payload: payload)
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

    private func accept(_ connection: NWConnection) {
        // 同一时间只处理一个配对请求，避免攻击者预先并发建立大量连接占满载荷槽。
        guard !finished, activeConnection == nil else {
            connection.cancel()
            return
        }
        activeConnection = connection
        answered = false
        challenges = 0
        answerGeneration = 0
        transferStart = Date()
        handshakeIdle = IdleDeadline(timeout: timing.idleTimeout)
        connection.start(queue: queue)
        scheduleConnectionCheck(for: connection)
        receiveClientLines(from: connection, buffer: Data())
    }

    /// 接收方驱动的行协议：只有 `CHALLENGE <nonce>` 与 `ERR PIN` 两种合法输入。
    private func receiveClientLines(from connection: NWConnection, buffer: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: LanHandshake.maxLineBytes) { [weak self] data, _, complete, error in
            guard let self else { return }
            var next = buffer
            if let data {
                next.append(data)
                handshakeIdle.reset()
            }
            while let newline = next.firstIndex(of: 0x0A) {
                let line = String(decoding: next[..<newline], as: UTF8.self)
                    .trimmingCharacters(in: .newlines)
                next.removeSubrange(...newline)
                self.handleClientLine(line, connection: connection)
                // 行处理可能已关闭连接（第 6 次挑战/畸形行/ERR PIN 结束会话）
                guard self.activeConnection === connection, !self.finished else { return }
            }
            if next.count >= LanHandshake.maxLineBytes {
                // 头行超限且无换行：协议违规，断开但会话保留
                connection.cancel()
                activeConnection = nil
            } else if error != nil || complete {
                // 对端关闭：已回答过视为送达确认（FIN=confirmed，异常=unconfirmed）；
                // 未回答过则只是静默探测，释放连接槽、会话保留
                let wasAnswered = answered
                connection.cancel()
                activeConnection = nil
                if wasAnswered {
                    self.finish(error == nil && complete ? .confirmed : .unconfirmed)
                }
            } else {
                self.receiveClientLines(from: connection, buffer: next)
            }
        }
    }

    private func handleClientLine(_ line: String, connection: NWConnection) {
        if line == LanHandshake.errPINLine {
            // 验证方计满 5 次失败 proof，正在关闭：本次配对判失败
            finish(.failed)
            return
        }
        guard let nonce = LanHandshake.parseChallengeLine(line) else {
            // 非协议流量：不回答、不计数，直接断开（与规格一致），会话保留
            connection.cancel()
            activeConnection = nil
            return
        }
        challenges += 1
        answerGeneration += 1
        guard challenges <= timing.maxAttempts else {
            // 每连接最多服务 maxAttempts 次挑战；超出即断开（验证方同连接最多尝试 5 次）
            connection.cancel()
            activeConnection = nil
            return
        }
        answer(connection: connection, nonce: nonce, generation: answerGeneration)
    }

    /// 流水线回答：proof 行 + OK 头 + payload（对齐 HarmonyOS answer，一次写入按序到达）
    private func answer(connection: NWConnection, nonce: String, generation: Int) {
        answered = true
        var response = Data("\(LanHandshake.protocolLine) \(LanHandshake.proof(pin: pin, nonce: nonce))\n".utf8)
        response.append(Data("\(LanHandshake.okPrefix) \(payload.count) \(payloadMacHex)\n".utf8))
        response.append(payload)
        connection.send(content: response, completion: .contentProcessed { [weak self] error in
            guard let self else { return }
            guard error == nil else {
                self.finish(.failed)
                return
            }
            self.armCloseConfirm(for: connection, generation: generation)
        })
    }

    /// 回答后等待验证方消费完并关连接：验证方正常关闭视为送达确认；
    /// 期间收到新挑战会使本计时失效（代次不匹配）
    private func armCloseConfirm(for connection: NWConnection, generation: Int) {
        queue.asyncAfter(deadline: .now() + timing.closeConfirmTimeout) { [weak self, weak connection] in
            guard let self, let connection,
                  !self.finished, self.activeConnection === connection,
                  self.answerGeneration == generation else { return }
            self.finish(.unconfirmed)
        }
    }

    /// 连接检查：回答前判握手空闲（有数据到达即续期）；任一阶段都受总时长硬顶约束，
    /// 两者先到先触发。
    private func scheduleConnectionCheck(for connection: NWConnection) {
        let elapsed = Date().timeIntervalSince(transferStart)
        let totalRemaining = max(0, timing.transferLimit - elapsed)
        let wait = answered ? totalRemaining : min(handshakeIdle.remaining(), totalRemaining)
        queue.asyncAfter(deadline: .now() + wait) { [weak self, weak connection] in
            guard let self, let connection,
                  !self.finished, self.activeConnection === connection else { return }
            if Date().timeIntervalSince(self.transferStart) >= self.timing.transferLimit {
                connection.cancel()
                self.activeConnection = nil
                return
            }
            if !self.answered && self.handshakeIdle.isExpired() {
                connection.cancel()
                self.activeConnection = nil
                return
            }
            self.scheduleConnectionCheck(for: connection)
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

/// macOS 端「接收方」角色：浏览设备、输入 PIN、主动连接——连接建立后立即发送
/// `CHALLENGE <nonceHex>`，验证发送方回出的 proof（常数时间比较），通过后收满 payload
/// 并校验 mac。proof 失败按每连接计数（最多 5 次，1/2/4/8s 退避后重新挑战），
/// 发送方对每次挑战都流水线回出 proof+OK+payload，被拒的回答先整体排空再重挑战。
final class LocalBackupReceiver: @unchecked Sendable {
    /// 接收流阶段
    private enum Phase {
        case proof   // 等待 FLASH-AERO/1 <proof> 行
        case ok      // proof 已通过，等待 OK 头行
        case payload // 等待收满 payload
        case discard // proof 被拒：排空本次流水线回答（OK 行 + payload）后重新挑战
    }

    private let connection: NWConnection
    private let queue = DispatchQueue(label: "com.flash.app.local-transfer.receiver")
    private let completion: @Sendable (Result<String, Error>) -> Void
    /// proof 校验用 PIN 来源：每次 proof 到达时重读（退避窗口内用户可能已更正 PIN）；
    /// 默认取创建时传入的静态 PIN
    private let pinSource: @Sendable () -> String
    private let timing: LocalTransferTiming
    private var finished = false
    private var buffer = Data()
    private var phase: Phase = .proof
    /// 最近一次发出的挑战 nonce（proof 校验的消息输入）
    private var lastChallengeNonce = ""
    /// proof 通过时锁定的 PIN（payload mac 校验用它，而非最新输入）
    private var authenticatedPIN = ""
    private var failedProofs = 0
    private var expectedSize: Int?
    private var expectedMACHex: String?
    /// 被拒回答的排空进度
    private var discardRemaining = 0
    private var discardHeaderPending = true
    private var discardComplete = true
    /// 退避进度：第 1–4 次失败后按 1/2/4/8s 递增，期满且排空完成才重发挑战
    private var backoffElapsed = true
    /// 连接建立时刻：总时长硬顶的起点
    private let startedAt = Date()
    /// 空闲计时（仅 queue 上访问）：区分握手与传输，大文件慢速传输不被误杀
    private var idle: IdleDeadline?

    init(device: LocalTransferDevice, pin: String,
         timing: LocalTransferTiming = LocalTransferTiming(),
         pinSource: (@Sendable () -> String)? = nil,
         completion: @escaping @Sendable (Result<String, Error>) -> Void) {
        self.pinSource = pinSource ?? { pin }
        self.authenticatedPIN = pin
        self.timing = timing
        self.connection = NWConnection(to: device.endpoint, using: .tcp)
        self.completion = completion
        connection.stateUpdateHandler = { [weak self] state in
            guard let self else { return }
            switch state {
            case .ready:
                idle?.reset()
                sendChallenge() // v1.1 修正方向：接收方先发送挑战
            case .failed(let error): complete(.failure(error))
            default: break
            }
        }
    }

    func start() {
        idle = IdleDeadline(timeout: timing.idleTimeout)
        connection.start(queue: queue)
        scheduleIdleCheck()
    }

    func cancel() { queue.async { [weak self] in self?.complete(.failure(LocalTransferError.interrupted)) } }

    /// 空闲检查随接收进度续期：到点时若期间有数据到达则按新 deadline 重新安排；
    /// 同时受总时长硬顶约束，按先到者安排下一次检查，两者先到先触发。
    private func scheduleIdleCheck() {
        let idleRemaining = idle?.remaining() ?? timing.idleTimeout
        let totalRemaining = max(0, timing.transferLimit - Date().timeIntervalSince(startedAt))
        queue.asyncAfter(deadline: .now() + min(idleRemaining, totalRemaining)) { [weak self] in
            guard let self, !self.finished, let idle = self.idle else { return }
            if Date().timeIntervalSince(self.startedAt) >= self.timing.transferLimit || idle.isExpired() {
                self.complete(.failure(LocalTransferError.timedOut))
            } else {
                self.scheduleIdleCheck()
            }
        }
    }

    private func sendChallenge() {
        phase = .proof
        discardHeaderPending = true
        discardComplete = false
        backoffElapsed = false
        lastChallengeNonce = LanHandshake.makeNonce()
        let line = Data("\(LanHandshake.challengePrefix) \(lastChallengeNonce)\n".utf8)
        connection.send(content: line, completion: .contentProcessed { [weak self] error in
            guard let self else { return }
            if let error {
                self.complete(.failure(error))
            } else {
                self.receiveMore()
            }
        })
    }

    /// 退避计时：第 1–4 次失败按 1s/2s/4s/8s 递增，期满且排空完成即重发挑战
    private func armBackoff(afterFailureCount count: Int) {
        let delay = timing.failureBackoff[min(count - 1, timing.failureBackoff.count - 1)]
        queue.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self, !self.finished else { return }
            self.backoffElapsed = true
            self.tryRechallenge()
        }
    }

    private func tryRechallenge() {
        guard !finished, backoffElapsed, discardComplete, phase == .discard else { return }
        sendChallenge()
    }

    private func rejectCurrentProof() {
        failedProofs += 1
        guard failedProofs < timing.maxAttempts else {
            // 第 5 次失败：立即置终态（阶段机与定时器全部停止，避免 send 完成前
            // 继续消费缓冲而把 OK 行当 proof 误读）；ERR PIN 告知发送方「配对被拒」
            // （与「传输完成」区分），结果在其发送完成回调里交付——内容按 FIFO 先于
            // 随后的 cancel 刷出，不会丢行。
            finished = true
            connection.send(content: Data("\(LanHandshake.errPINLine)\n".utf8),
                            completion: .contentProcessed { [weak self] _ in
                guard let self else { return }
                self.connection.cancel()
                self.completion(.failure(LocalTransferError.invalidPIN))
            })
            return
        }
        // 第 1–4 次失败：排空发送方已流水线回出的回答，退避期满后重新挑战
        phase = .discard
        discardRemaining = 0
        discardHeaderPending = true
        discardComplete = false
        armBackoff(afterFailureCount: failedProofs)
    }

    private func receiveMore() {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { [weak self] data, _, isComplete, error in
            guard let self else { return }
            if let data {
                buffer.append(data)
                idle?.reset()
            }
            processBuffer()
            guard !self.finished else { return }
            if error != nil || isComplete {
                self.complete(.failure(error ?? LocalTransferError.interrupted))
            } else {
                self.receiveMore()
            }
        }
    }

    /// 阶段机消费缓冲：行级阶段在收到换行前按阶段上限检查 buffer.count
    private func processBuffer() {
        while !finished {
            if phase == .payload {
                guard let expectedSize else { return }
                guard buffer.count >= expectedSize else { return }
                guard buffer.count == expectedSize else {
                    complete(.failure(LocalTransferError.invalidResponse)); return
                }
                let payload = Data(buffer)
                // mac 不等即整体丢弃并报错，不得进入解析/预览
                guard LanHandshake.verifyPayloadMAC(pin: authenticatedPIN, macHex: expectedMACHex ?? "", payload: payload) else {
                    complete(.failure(LocalTransferError.payloadTampered)); return
                }
                guard let json = String(data: payload, encoding: .utf8) else {
                    complete(.failure(LocalTransferError.invalidResponse)); return
                }
                complete(.success(json))
                return
            }
            if phase == .discard && !discardHeaderPending {
                // 排空被拒回答的 payload 尾
                if discardRemaining > 0 && !buffer.isEmpty {
                    let take = min(discardRemaining, buffer.count)
                    buffer.removeFirst(take)
                    discardRemaining -= take
                }
                if discardRemaining == 0 {
                    discardComplete = true
                    tryRechallenge()
                }
                // 排空按协议精确消费整个回答尾部，缓冲应为空；防御性返回，
                // 避免重新挑战后本轮循环继续按新阶段解读残留字节
                return
            }
            // 行级阶段：.proof / .ok，或 .discard 待读 OK 头行。
            // 注意：Data 在 removeFirst/removeSubrange 后内部 startIndex 可能非零，
            // firstIndex(of:) 返回的是索引（偏移 + startIndex），必须换算成
            // startIndex 起点的真实偏移后再与 limit 比较，否则合规行会被误判超限。
            let limit = phase == .proof ? LanHandshake.maxLineBytes : LanHandshake.maxOKHeaderBytes
            guard let newlineIndex = buffer.firstIndex(of: 0x0A) else {
                if buffer.count > limit {
                    complete(.failure(LocalTransferError.invalidResponse))
                }
                return
            }
            let newlineOffset = buffer.distance(from: buffer.startIndex, to: newlineIndex)
            guard newlineOffset <= limit else {
                complete(.failure(LocalTransferError.invalidResponse)); return
            }
            let header = String(decoding: buffer[buffer.startIndex..<newlineIndex], as: UTF8.self)
            buffer.removeSubrange(buffer.startIndex...newlineIndex)
            if phase == .discard {
                // 发送方对每次挑战都流水线回出 proof+OK+payload，被拒回答的尾
                // 也必须按 OK 行严格解析出长度后精确跳过
                guard let ok = LanHandshake.parseOKHeader(header),
                      ok.size <= BackupService.maxFileBytes else {
                    complete(.failure(LocalTransferError.invalidResponse)); return
                }
                discardRemaining = ok.size
                discardHeaderPending = false
                continue
            }
            if phase == .proof {
                guard LanHandshake.parseProofLine(header) != nil else {
                    complete(.failure(LocalTransferError.invalidResponse)); return
                }
                if LanHandshake.verifyProofLine(pin: pinSource(), nonce: lastChallengeNonce, line: header) {
                    authenticatedPIN = pinSource()
                    phase = .ok
                } else {
                    rejectCurrentProof()
                }
                continue
            }
            // phase == .ok：proof 已通过，严格解析 OK 头行
            guard let ok = LanHandshake.parseOKHeader(header),
                  ok.size <= BackupService.maxFileBytes else {
                complete(.failure(LocalTransferError.invalidResponse)); return
            }
            expectedSize = ok.size
            expectedMACHex = ok.macHex
            phase = .payload
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
