// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import Testing
@testable import Flash

@Suite("LocalBackupTransfer")
struct LocalBackupTransferTests {
    @Test func generatedPINIsAlwaysFourDigits() {
        for _ in 0..<200 {
            let pin = LocalBackupSender.generatePIN()
            let onlyDigits = pin.allSatisfy { $0.isNumber }
            #expect(pin.count == 4)
            #expect(onlyDigits)
        }
    }

    // MARK: 握手分类（PIN 计数口径：仅协议头合法但 PIN 错误才计数）

    @Test func classifyHandshakeAcceptsCorrectPIN() {
        #expect(LocalBackupSender.classifyHandshake("FLASH-AERO/1 1234", pin: "1234") == .ok)
    }

    @Test func classifyHandshakeWrongPINCounts() {
        // 协议头合法但 PIN 错误 → 计入尝试次数
        #expect(LocalBackupSender.classifyHandshake("FLASH-AERO/1 9999", pin: "1234") == .wrongPIN)
    }

    @Test func classifyHandshakeRejectsNonProtocolTraffic() {
        // 端口扫描/垃圾连接：不回复、不计数
        #expect(LocalBackupSender.classifyHandshake(nil, pin: "1234") == .notProtocol)
        #expect(LocalBackupSender.classifyHandshake("", pin: "1234") == .notProtocol)
        #expect(LocalBackupSender.classifyHandshake("GET / HTTP/1.1", pin: "1234") == .notProtocol)
        #expect(LocalBackupSender.classifyHandshake("FLASH-AERO/1", pin: "1234") == .notProtocol)
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
