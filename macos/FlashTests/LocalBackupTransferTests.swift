// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import Network
import Testing
@testable import Flash

@Suite("LocalBackupTransfer")
struct LocalBackupTransferTests {
    // MARK: PIN 生成（规格：6 位十进制）

    @Test func generatedPINIsAlwaysSixDigits() {
        for _ in 0..<200 {
            let pin = LocalBackupSender.generatePIN()
            let onlyDigits = pin.allSatisfy { $0.isNumber }
            #expect(pin.count == 6)
            #expect(onlyDigits)
        }
    }

    // MARK: 规格测试向量（与 Android/HarmonyOS 同一 HMAC 口径）

    @Test func proofMatchesSpecVector() {
        // 独立核算向量（Python hmac/sha256）：
        // HMAC-SHA256(key=b"123456", msg=b"flash-aero-handshake:0123456789abcdef0123456789abcdef")[:16]
        let nonce = "0123456789abcdef0123456789abcdef"
        #expect(LanHandshake.proof(pin: "123456", nonce: nonce) == "eaf2db99644b07d9b250f86ce481647e")
    }

    @Test func payloadMACMatchesSpecVector() {
        // HMAC-SHA256(key=b"123456", msg=b'{"hello":"world"}')[:32]
        let payload = Data("{\"hello\":\"world\"}".utf8)
        #expect(LanHandshake.payloadMAC(pin: "123456", payload: payload) ==
                "af96906743949248f47e5cc5f5bab43b9e59f624740c975d40733822b8b1452f")
        #expect(LanHandshake.verifyPayloadMAC(pin: "123456",
                                              macHex: "af96906743949248f47e5cc5f5bab43b9e59f624740c975d40733822b8b1452f",
                                              payload: payload))
    }

    @Test func tamperedPayloadMACIsRejected() {
        let payload = Data("{\"hello\":\"world\"}".utf8)
        let good = LanHandshake.payloadMAC(pin: "123456", payload: payload)
        var tampered = Array(good)
        tampered[0] = tampered[0] == "a" ? "b" : "a"
        #expect(!LanHandshake.verifyPayloadMAC(pin: "123456", macHex: String(tampered), payload: payload))
        #expect(!LanHandshake.verifyPayloadMAC(pin: "123456", macHex: "zzzz", payload: payload))
        #expect(!LanHandshake.verifyPayloadMAC(pin: "999999", macHex: good, payload: payload))
    }

    // MARK: 常数时间比较

    @Test func constantTimeCompare() {
        #expect(LanHandshake.constantTimeEqual([1, 2, 3], [1, 2, 3]))
        #expect(!LanHandshake.constantTimeEqual([1, 2, 3], [1, 2, 4]))
        #expect(!LanHandshake.constantTimeEqual([1, 2, 3], [1, 2]))
        #expect(!LanHandshake.constantTimeEqual([1, 2], [1, 2, 3]))
        #expect(LanHandshake.constantTimeEqual([], []))
    }

    // MARK: 行解析（严格口径，与 HarmonyOS 正则一致：小写 hex）

    @Test func parseChallengeLineStrict() {
        #expect(LanHandshake.parseChallengeLine("CHALLENGE 0123456789abcdef0123456789abcdef") == "0123456789abcdef0123456789abcdef")
        #expect(LanHandshake.parseChallengeLine("CHALLENGE 0123456789ABCDEF0123456789ABCDEF") == nil)  // 规格/HarmonyOS：仅小写 hex
        #expect(LanHandshake.parseChallengeLine("CHALLENGE 0123456789abcdef") == nil)          // nonce 过短
        #expect(LanHandshake.parseChallengeLine("CHALLENGE") == nil)
        #expect(LanHandshake.parseChallengeLine("CHALLENGE 0123456789abcdef0123456789abcdef x") == nil)
        #expect(LanHandshake.parseChallengeLine("OK 12") == nil)
    }

    @Test func parseProofLineStrict() {
        #expect(LanHandshake.parseProofLine("FLASH-AERO/1 eaf2db99644b07d9b250f86ce481647e") != nil)
        #expect(LanHandshake.parseProofLine("FLASH-AERO/1 EAF2DB99644B07D9B250F86CE481647E") == nil)  // 仅小写 hex
        #expect(LanHandshake.parseProofLine("FLASH-AERO/1 9999") == nil)       // 旧版明文 PIN 首包：形状非法
        #expect(LanHandshake.parseProofLine("FLASH-AERO/1 eaf2db99644b07d9b250f86ce481647") == nil)
        #expect(LanHandshake.parseProofLine("FLASH-AERO/1 eaf2db99644b07d9b250f86ce481647ee") == nil)
        #expect(LanHandshake.parseProofLine("FLASH-AERO/1 gaf2db99644b07d9b250f86ce481647e") == nil)
        #expect(LanHandshake.parseProofLine("GET / HTTP/1.1") == nil)
    }

    @Test func parseOKHeaderStrict() {
        let mac = String(repeating: "ab", count: 32)
        #expect(LanHandshake.parseOKHeader("OK 123 \(mac)")?.size == 123)
        #expect(LanHandshake.parseOKHeader("OK 123 \(mac)")?.macHex == mac)
        #expect(LanHandshake.parseOKHeader("OK 123abc \(mac)") == nil)   // 规格用例：尾随字符拒绝
        #expect(LanHandshake.parseOKHeader("OK +123 \(mac)") == nil)
        #expect(LanHandshake.parseOKHeader("OK 007 \(mac)") == nil)      // 规格：拒绝前导零
        #expect(LanHandshake.parseOKHeader("OK 123 \(mac) x") == nil)
        #expect(LanHandshake.parseOKHeader("OK  \(mac)") == nil)
        #expect(LanHandshake.parseOKHeader("OK 0 \(mac)") == nil)        // size 必须为正
        #expect(LanHandshake.parseOKHeader("OK 123 \(String(repeating: "ab", count: 31))") == nil)  // mac 不足 64 hex
        #expect(LanHandshake.parseOKHeader("OK 123 \(String(repeating: "AB", count: 32))") == nil)  // 仅小写 hex
        #expect(LanHandshake.parseOKHeader("ERR PIN") == nil)
    }

    // MARK: proof 验证（接收方角色：用本地 PIN + 发出的 nonceHex 常数时间比较）

    @Test func proofVerificationAcceptsCorrectProof() {
        let pin = "123456"
        let nonce = "0123456789abcdef0123456789abcdef"
        let line = "FLASH-AERO/1 \(LanHandshake.proof(pin: pin, nonce: nonce))"
        #expect(LanHandshake.verifyProofLine(pin: pin, nonce: nonce, line: line))
    }

    @Test func proofVerificationRejectsWrongProof() {
        let nonce = "0123456789abcdef0123456789abcdef"
        let line = "FLASH-AERO/1 \(LanHandshake.proof(pin: "999999", nonce: nonce))"
        #expect(!LanHandshake.verifyProofLine(pin: "123456", nonce: nonce, line: line))
    }

    @Test func proofVerificationRejectsMalformedLines() {
        let nonce = "0123456789abcdef0123456789abcdef"
        #expect(!LanHandshake.verifyProofLine(pin: "123456", nonce: nonce, line: ""))
        #expect(!LanHandshake.verifyProofLine(pin: "123456", nonce: nonce, line: "GET / HTTP/1.1"))
        #expect(!LanHandshake.verifyProofLine(pin: "123456", nonce: nonce, line: "FLASH-AERO/1"))
        // 旧版明文 PIN 首包（如 "FLASH-AERO/1 1234"）：形状非法
        #expect(!LanHandshake.verifyProofLine(pin: "123456", nonce: nonce, line: "FLASH-AERO/1 1234"))
    }

    // MARK: 空闲超时（有数据到达即续期）

    @Test func idleDeadlineExpiresAfterTimeout() {
        let start = Date(timeIntervalSince1970: 1000)
        let idle = IdleDeadline(timeout: 15, now: start)
        #expect(!idle.isExpired(now: start.addingTimeInterval(14.9)))
        #expect(idle.isExpired(now: start.addingTimeInterval(15)))
        #expect(idle.remaining(now: start.addingTimeInterval(20)) == 0)
    }

    @Test func idleDeadlineResetRenewsDeadline() {
        let start = Date(timeIntervalSince1970: 1000)
        var idle = IdleDeadline(timeout: 15, now: start)
        // 第 14 秒有数据到达 → 续期到第 29 秒，原第 15 秒点不再超时
        idle.reset(now: start.addingTimeInterval(14))
        #expect(!idle.isExpired(now: start.addingTimeInterval(20)))
        #expect(idle.remaining(now: start.addingTimeInterval(14)) == 15)
        #expect(idle.isExpired(now: start.addingTimeInterval(29)))
    }
}

// MARK: - 回环集成测试（真实 NWListener/NWConnection，127.0.0.1）

/// Swift 6：@Sendable 完成回调里不得捕获修改局部 var，统一用盒对象
private final class Box<Value>: @unchecked Sendable {
    var value: Value
    init(_ value: Value) { self.value = value }
}

/// 测试客户端连接读取器：按行读、按字节数读，行尾之后的数据保留给后续读取
private final class TestConnectionReader: @unchecked Sendable {
    let connection: NWConnection
    let queue: DispatchQueue
    private var buffer = Data()

    init(connection: NWConnection, queue: DispatchQueue) {
        self.connection = connection
        self.queue = queue
    }

    /// 读到换行为止；连接在换行前关闭返回 nil；超时抛错
    func readLine(timeout: TimeInterval = 5) throws -> String? {
        let semaphore = DispatchSemaphore(value: 0)
        let result = Box<String?>(nil)
        queue.async { [self] in
            receiveLine(semaphore: semaphore, result: result)
        }
        guard semaphore.wait(timeout: .now() + timeout) == .success else {
            connection.cancel()
            throw LocalTransferError.timedOut
        }
        return result.value
    }

    /// 读满 count 字节（先吃行读取遗留的缓冲）；连接提前关闭或超时抛错
    func readExact(_ count: Int, timeout: TimeInterval = 5) throws -> Data {
        let semaphore = DispatchSemaphore(value: 0)
        let result = Box<Data?>(nil)
        queue.async { [self] in
            receiveExact(count, accumulated: Data(), semaphore: semaphore, result: result)
        }
        guard semaphore.wait(timeout: .now() + timeout) == .success else {
            connection.cancel()
            throw LocalTransferError.timedOut
        }
        guard let data = result.value, data.count == count else {
            throw LocalTransferError.interrupted
        }
        return data
    }

    private func receiveLine(semaphore: DispatchSemaphore, result: Box<String?>) {
        if let newline = buffer.firstIndex(of: 0x0A) {
            let line = String(decoding: buffer[..<newline], as: UTF8.self)
            buffer.removeSubrange(...newline)
            result.value = line
            semaphore.signal()
            return
        }
        connection.receive(minimumIncompleteLength: 1, maximumLength: 4096) { [weak self] data, _, complete, error in
            guard let self else { semaphore.signal(); return }
            if let data { buffer.append(data) }
            if buffer.firstIndex(of: 0x0A) != nil {
                receiveLine(semaphore: semaphore, result: result)
            } else if error != nil || complete {
                result.value = nil
                semaphore.signal()
            } else {
                receiveLine(semaphore: semaphore, result: result)
            }
        }
    }

    private func receiveExact(_ count: Int, accumulated: Data,
                              semaphore: DispatchSemaphore, result: Box<Data?>) {
        var pending = accumulated
        if !buffer.isEmpty {
            let take = min(count - pending.count, buffer.count)
            pending.append(buffer.prefix(take))
            buffer.removeSubrange(..<take)
        }
        receiveMore(count, pending: pending, semaphore: semaphore, result: result)
    }

    private func receiveMore(_ count: Int, pending: Data,
                             semaphore: DispatchSemaphore, result: Box<Data?>) {
        guard pending.count < count else {
            result.value = pending
            semaphore.signal()
            return
        }
        connection.receive(minimumIncompleteLength: 1, maximumLength: max(count - pending.count, 1)) { [weak self] data, _, _, error in
            guard let self else { semaphore.signal(); return }
            var next = pending
            if let data { next.append(data) }
            if next.count >= count || error != nil {
                result.value = next
                semaphore.signal()
            } else {
                receiveMore(count, pending: next, semaphore: semaphore, result: result)
            }
        }
    }
}

private func makeLoopbackDevice(port: UInt16) -> LocalTransferDevice {
    LocalTransferDevice(id: "127.0.0.1:\(port)", name: "loopback",
                        endpoint: .hostPort(host: .ipv4(.loopback),
                                            port: NWEndpoint.Port(rawValue: port)!))
}

private func waitForPort(_ provider: @Sendable () -> UInt16?, timeout: TimeInterval = 5) throws -> UInt16 {
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline {
        if let port = provider() { return port }
        Thread.sleep(forTimeInterval: 0.02)
    }
    throw LocalTransferError.timedOut
}

@Suite("LocalBackupTransfer 回环集成")
struct LocalBackupTransferIntegrationTests {
    private let payloadJSON = "{\"version\":\"flash-backup-v2\",\"data\":{}}"

    /// 注入的短计时：覆盖退避/超时时无需真实等待 1/2/4/8s
    private var fastTiming: LocalTransferTiming {
        var timing = LocalTransferTiming()
        timing.failureBackoff = [0, 0, 0, 0]
        timing.sessionDuration = 30
        return timing
    }

    private func runReceiver(device: LocalTransferDevice, pin: String,
                             timing: LocalTransferTiming = LocalTransferTiming(),
                             pinSource: (@Sendable () -> String)? = nil,
                             timeout: TimeInterval = 8) throws -> Result<String, Error> {
        let semaphore = DispatchSemaphore(value: 0)
        let box = Box<Result<String, Error>?>(nil)
        let receiver = LocalBackupReceiver(device: device, pin: pin, timing: timing,
                                           pinSource: pinSource) { result in
            box.value = result
            semaphore.signal()
        }
        receiver.start()
        guard semaphore.wait(timeout: .now() + timeout) == .success else {
            receiver.cancel()
            throw LocalTransferError.timedOut
        }
        return box.value!
    }

    // MARK: 正确方向：接收方发 CHALLENGE，发送方回答 proof + OK + payload

    @Test func roundTripOverLoopbackConfirmsDelivery() throws {
        let semaphore = DispatchSemaphore(value: 0)
        let senderResult = Box<LocalBackupSendResult?>(nil)
        let sender = try LocalBackupSender(json: payloadJSON, timing: fastTiming) { result in
            senderResult.value = result
            semaphore.signal()
        }
        sender.start()
        defer { sender.cancel() }
        let port = try waitForPort({ sender.port })

        let received = try runReceiver(device: makeLoopbackDevice(port: port), pin: sender.pin)
        #expect(try received.get() == payloadJSON)

        // 接收方收完即关连接：发送方应得到 confirmed
        #expect(semaphore.wait(timeout: .now() + 5) == .success)
        #expect(senderResult.value == .confirmed)
    }

    @Test func rejectedProofIsRetriedAfterBackoffAndPinCorrection() throws {
        // 前两次 proof 校验用错误 PIN（发送方照样回答，接收方验证失败并排空），
        // 退避（注入为 0）重挑战后 pinSource 改报正确 PIN：第三次挑战应成功。
        let sender = try LocalBackupSender(json: payloadJSON, timing: fastTiming) { _ in }
        sender.start()
        defer { sender.cancel() }
        let port = try waitForPort({ sender.port })

        let proofChecks = Box(0)
        let correctPin = sender.pin
        let received = try runReceiver(device: makeLoopbackDevice(port: port), pin: "000000",
                                       timing: fastTiming,
                                       pinSource: {
                                           proofChecks.value += 1
                                           return proofChecks.value <= 2 ? "000000" : correctPin
                                       })
        #expect(try received.get() == payloadJSON)
        #expect(proofChecks.value >= 3)  // 至少两次失败 + 一次成功校验
    }

    @Test func fiveRejectedProofsFailWithErrPINAndSenderFails() throws {
        let semaphore = DispatchSemaphore(value: 0)
        let senderResult = Box<LocalBackupSendResult?>(nil)
        let sender = try LocalBackupSender(json: payloadJSON, timing: fastTiming) { result in
            senderResult.value = result
            semaphore.signal()
        }
        sender.start()
        defer { sender.cancel() }
        let port = try waitForPort({ sender.port })

        // PIN 始终错误：5 次失败后接收方发 ERR PIN 并报 invalidPIN，发送方判 failed
        let result = try runReceiver(device: makeLoopbackDevice(port: port), pin: "000000",
                                     timing: fastTiming)
        #expect(throws: LocalTransferError.invalidPIN) { _ = try result.get() }
        #expect(semaphore.wait(timeout: .now() + 5) == .success)
        #expect(senderResult.value == .failed)
    }

    @Test func senderServesAtMostFiveChallengesPerConnection() throws {
        let sender = try LocalBackupSender(json: payloadJSON, timing: fastTiming) { _ in }
        sender.start()
        defer { sender.cancel() }
        let port = try waitForPort({ sender.port })

        // 同一连接连续挑战：前 5 次各得到 proof+OK+payload，第 6 次被断开
        let connection = NWConnection(to: .hostPort(host: .ipv4(.loopback),
                                                    port: NWEndpoint.Port(rawValue: port)!),
                                      using: .tcp)
        let reader = TestConnectionReader(connection: connection,
                                          queue: DispatchQueue(label: "test.client.challenges"))
        connection.start(queue: reader.queue)
        for _ in 1...5 {
            let nonce = LanHandshake.makeNonce()
            connection.send(content: Data("CHALLENGE \(nonce)\n".utf8), completion: .idempotent)
            let proofLine = try #require(try reader.readLine())
            #expect(LanHandshake.verifyProofLine(pin: sender.pin, nonce: nonce, line: proofLine))
            let okLine = try #require(try reader.readLine())
            let ok = try #require(LanHandshake.parseOKHeader(okLine))
            let payload = try reader.readExact(ok.size)
            #expect(String(data: payload, encoding: .utf8) == payloadJSON)
        }
        connection.send(content: Data("CHALLENGE \(LanHandshake.makeNonce())\n".utf8),
                        completion: .idempotent)
        #expect(try reader.readLine() == nil)  // 第 6 次挑战：连接被断开
        connection.cancel()

        // 会话仍有效：新连接正常完成传输
        let received = try runReceiver(device: makeLoopbackDevice(port: port), pin: sender.pin)
        #expect(try received.get() == payloadJSON)
    }

    @Test func senderDropsMalformedLineAndSessionSurvives() throws {
        let sender = try LocalBackupSender(json: payloadJSON, timing: fastTiming) { _ in }
        sender.start()
        defer { sender.cancel() }
        let port = try waitForPort({ sender.port })

        let connection = NWConnection(to: .hostPort(host: .ipv4(.loopback),
                                                    port: NWEndpoint.Port(rawValue: port)!),
                                      using: .tcp)
        let reader = TestConnectionReader(connection: connection,
                                          queue: DispatchQueue(label: "test.client.malformed"))
        connection.start(queue: reader.queue)
        connection.send(content: Data("GET / HTTP/1.1\n".utf8), completion: .idempotent)
        #expect(try reader.readLine() == nil)  // 非协议行：不回答、断开
        connection.cancel()

        let received = try runReceiver(device: makeLoopbackDevice(port: port), pin: sender.pin)
        #expect(try received.get() == payloadJSON)
    }

    @Test func senderDropsOversizedHeaderWithoutNewline() throws {
        let sender = try LocalBackupSender(json: payloadJSON, timing: fastTiming) { _ in }
        sender.start()
        defer { sender.cancel() }
        let port = try waitForPort({ sender.port })

        let connection = NWConnection(to: .hostPort(host: .ipv4(.loopback),
                                                    port: NWEndpoint.Port(rawValue: port)!),
                                      using: .tcp)
        let reader = TestConnectionReader(connection: connection,
                                          queue: DispatchQueue(label: "test.client.oversized"))
        connection.start(queue: reader.queue)
        // 收到换行前按 buffer.count 判限：65+ 字节无换行的头行直接断开
        connection.send(content: Data(repeating: 0x41, count: 70), completion: .idempotent)
        #expect(try reader.readLine() == nil)
        connection.cancel()

        let received = try runReceiver(device: makeLoopbackDevice(port: port), pin: sender.pin)
        #expect(try received.get() == payloadJSON)
    }

    @Test func silentClientHitsIdleTimeoutButSessionSurvives() throws {
        // 发送方（监听端）：客户端连接后不发 CHALLENGE → 握手空闲超时断开；
        // 随后新连接正常完成，证明连接槽已释放、会话未被拖死
        var timing = fastTiming
        timing.idleTimeout = 0.3
        let sender = try LocalBackupSender(json: payloadJSON, timing: timing) { _ in }
        sender.start()
        defer { sender.cancel() }
        let port = try waitForPort({ sender.port })

        let silent = NWConnection(to: .hostPort(host: .ipv4(.loopback),
                                                port: NWEndpoint.Port(rawValue: port)!),
                                  using: .tcp)
        let reader = TestConnectionReader(connection: silent,
                                          queue: DispatchQueue(label: "test.client.silent"))
        silent.start(queue: reader.queue)
        Thread.sleep(forTimeInterval: 1.0)                    // 超过 0.3s 空闲上限
        #expect(try reader.readLine(timeout: 2) == nil)  // 已被对端断开
        silent.cancel()

        let received = try runReceiver(device: makeLoopbackDevice(port: port), pin: sender.pin)
        #expect(try received.get() == payloadJSON)
    }

    // MARK: 伪造发送方：验证接收方在 proof 通过后的防线

    /// 伪造发送方（监听方）：按配置回答 CHALLENGE——proof 正确但后续负载做手脚
    private final class FakeServer: @unchecked Sendable {
        enum Behavior {
            case good(json: String)
            case badMAC(json: String)
            case malformedProof
            case badOKHeader(String)
            case oversizedHeaderNoNewline
            case drip(json: String, chunkDelay: TimeInterval)
        }

        let pin: String
        let behavior: Behavior
        let listener: NWListener
        private let queue = DispatchQueue(label: "test.fake-server")

        init(pin: String, behavior: Behavior) throws {
            self.pin = pin
            self.behavior = behavior
            listener = try NWListener(using: .tcp, on: .any)
            listener.newConnectionHandler = { [weak self] connection in self?.handle(connection) }
        }

        var port: UInt16? {
            let raw = listener.port?.rawValue
            return (raw == nil || raw == 0) ? nil : raw
        }

        func start() { listener.start(queue: queue) }
        func cancel() { listener.cancel() }

        private func handle(_ connection: NWConnection) {
            connection.start(queue: queue)
            readLines(on: connection, buffer: Data())
        }

        private func readLines(on connection: NWConnection, buffer: Data) {
            connection.receive(minimumIncompleteLength: 1, maximumLength: LanHandshake.maxLineBytes) { [weak self] data, _, complete, error in
                guard let self else { return }
                var next = buffer
                if let data { next.append(data) }
                while let newline = next.firstIndex(of: 0x0A) {
                    let line = String(decoding: next[..<newline], as: UTF8.self)
                        .trimmingCharacters(in: .newlines)
                    next.removeSubrange(...newline)
                    self.respond(to: line, on: connection)
                }
                if error != nil || complete {
                    connection.cancel()
                } else {
                    self.readLines(on: connection, buffer: next)
                }
            }
        }

        private func respond(to line: String, on connection: NWConnection) {
            guard let nonce = LanHandshake.parseChallengeLine(line) else { return }
            let proofLine = "\(LanHandshake.protocolLine) \(LanHandshake.proof(pin: pin, nonce: nonce))\n"
            switch behavior {
            case .good(let json), .badMAC(let json):
                let payload = Data(json.utf8)
                let mac: String = {
                    if case .badMAC = behavior { return String(repeating: "0", count: 64) }
                    return LanHandshake.payloadMAC(pin: pin, payload: payload)
                }()
                var response = Data(proofLine.utf8)
                response.append(Data("OK \(payload.count) \(mac)\n".utf8))
                response.append(payload)
                connection.send(content: response, completion: .idempotent)
            case .malformedProof:
                connection.send(content: Data("FLASH-AERO/1 not-a-proof\n".utf8),
                                completion: .idempotent)
            case .badOKHeader(let header):
                var response = Data(proofLine.utf8)
                response.append(Data("\(header)\n".utf8))
                connection.send(content: response, completion: .idempotent)
            case .oversizedHeaderNoNewline:
                var response = Data(proofLine.utf8)
                response.append(Data("OK 99999999 \(String(repeating: "ab", count: 40))".utf8))
                connection.send(content: response, completion: .idempotent)
            case .drip(let json, let chunkDelay):
                let payload = Data(json.utf8)
                var response = Data(proofLine.utf8)
                response.append(Data("OK \(payload.count) \(LanHandshake.payloadMAC(pin: pin, payload: payload))\n".utf8))
                response.append(payload)
                for (index, byte) in response.enumerated() {
                    queue.asyncAfter(deadline: .now() + chunkDelay * Double(index)) {
                        connection.send(content: Data([byte]), completion: .idempotent)
                    }
                }
            }
        }
    }

    private func startFakeServer(pin: String, behavior: FakeServer.Behavior) throws -> FakeServer {
        let fake = try FakeServer(pin: pin, behavior: behavior)
        fake.start()
        _ = try waitForPort({ fake.port })
        return fake
    }

    @Test func receiverRejectsMalformedProofLine() throws {
        let fake = try startFakeServer(pin: "123456", behavior: .malformedProof)
        defer { fake.cancel() }
        let result = try runReceiver(device: makeLoopbackDevice(port: fake.port!), pin: "123456")
        #expect(throws: LocalTransferError.invalidResponse) { _ = try result.get() }
    }

    @Test func tamperedPayloadMACIsDiscardedWholeByReceiver() throws {
        let fake = try startFakeServer(pin: "123456", behavior: .badMAC(json: payloadJSON))
        defer { fake.cancel() }
        let result = try runReceiver(device: makeLoopbackDevice(port: fake.port!), pin: "123456")
        #expect(throws: LocalTransferError.payloadTampered) { _ = try result.get() }
    }

    @Test func malformedOKLineIsRejectedByReceiver() throws {
        let fake = try startFakeServer(pin: "123456", behavior: .badOKHeader("OK 123abc"))
        defer { fake.cancel() }
        let result = try runReceiver(device: makeLoopbackDevice(port: fake.port!), pin: "123456")
        #expect(throws: LocalTransferError.invalidResponse) { _ = try result.get() }
    }

    @Test func oversizedOKHeaderWithoutNewlineIsRejected() throws {
        // proof 通过后的 OK 阶段：头行无换行且超过 76 字节上限，按 buffer.count 拒绝
        let fake = try startFakeServer(pin: "123456", behavior: .oversizedHeaderNoNewline)
        defer { fake.cancel() }
        let result = try runReceiver(device: makeLoopbackDevice(port: fake.port!), pin: "123456")
        #expect(throws: LocalTransferError.invalidResponse) { _ = try result.get() }
    }

    @Test func slowDripHitsTotalTransferLimit() throws {
        let fake = try startFakeServer(pin: "123456",
                                       behavior: .drip(json: String(repeating: "x", count: 4096),
                                                       chunkDelay: 0.02))
        defer { fake.cancel() }
        // 总时长硬顶 0.5s：滴流传不完；空闲超时给足以区分两个上限
        var timing = LocalTransferTiming()
        timing.transferLimit = 0.5
        let result = try runReceiver(device: makeLoopbackDevice(port: fake.port!), pin: "123456",
                                     timing: timing, timeout: 8)
        #expect(throws: LocalTransferError.timedOut) { _ = try result.get() }
    }
}
