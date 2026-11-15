// Copyright (c) 2026 Fengyuan Jiang. SPDX-License-Identifier: MPL-2.0
import Foundation
#if canImport(CFlashLAN)
import CFlashLAN
#endif

enum SecureLanError: Error, Sendable {
    case unavailable
    case native(Int64)
    case invalidBackup
    case network
    case expired
    case unconfirmed

    var userMessage: String {
        switch self {
        case .unavailable: return LocalBackupAvailability.message
        case .invalidBackup: return "收到的备份未通过校验，请更新两端应用后重新传输"
        case .expired: return "配对或传输已超时，请重新发起"
        case .unconfirmed: return "传输结果未确认，请在接收设备核对；接收后仍需确认导入"
        case .native(let code):
            if code == -3 { return "两端的安全传输版本不兼容，请更新后重试" }
            if code == -6 { return "配对或传输已超时，请重新发起" }
            return "安全传输未完成，请重新发起"
        case .network: return "无法连接，请确认两端已开启传输、连接同一局域网并允许本地网络访问"
        }
    }
}

/// Opaque C ABI owner. Calls belong to the transport's serial actor; the native
/// registry also protects each operation. It exposes no keys or partial backup.
final class SecureLanSession: @unchecked Sendable {
    let id: UInt64
    static var available: Bool {
        #if canImport(CFlashLAN)
        true
        #else
        false
        #endif
    }
    init(sender: Bool, now: UInt64, remaining: UInt64) throws {
        #if canImport(CFlashLAN)
        id = flash_lan_new(sender ? 1 : 2, now, remaining)
        guard id != 0 else { throw SecureLanError.unavailable }
        #else
        id = 0
        throw SecureLanError.unavailable
        #endif
    }
    deinit {
        #if canImport(CFlashLAN)
        flash_lan_free(id)
        #endif
    }
    private func checked(_ code: Int64) throws -> Int64 {
        guard code >= 0 else { throw SecureLanError.native(code) }
        return code
    }
    var state: Int {
        get throws {
            #if canImport(CFlashLAN)
            Int(try checked(flash_lan_state(id)))
            #else
            throw SecureLanError.unavailable
            #endif
        }
    }
    func tick(_ now: UInt64) throws {
        #if canImport(CFlashLAN)
        _ = try checked(flash_lan_tick(id, now))
        #else
        throw SecureLanError.unavailable
        #endif
    }
    func accept(_ now: UInt64) throws {
        #if canImport(CFlashLAN)
        _ = try checked(flash_lan_accept(id, now))
        #else
        throw SecureLanError.unavailable
        #endif
    }
    func wrote(_ now: UInt64) throws {
        #if canImport(CFlashLAN)
        _ = try checked(flash_lan_wrote(id, now))
        #else
        throw SecureLanError.unavailable
        #endif
    }
    func cancel() {
        #if canImport(CFlashLAN)
        _ = flash_lan_cancel(id)
        #endif
    }
    func receive(_ data: Data, now: UInt64) throws {
        #if canImport(CFlashLAN)
        _ = try data.withUnsafeBytes { buffer in
            try checked(flash_lan_receive(id, buffer.bindMemory(to: UInt8.self).baseAddress, buffer.count, now))
        }
        #else
        throw SecureLanError.unavailable
        #endif
    }
    func provide(_ data: Data, now: UInt64) throws {
        #if canImport(CFlashLAN)
        _ = try data.withUnsafeBytes { buffer in
            try checked(flash_lan_provide(id, buffer.bindMemory(to: UInt8.self).baseAddress, buffer.count, now))
        }
        #else
        throw SecureLanError.unavailable
        #endif
    }
    func output(_ now: UInt64) throws -> Data? {
        #if canImport(CFlashLAN)
        let count = try checked(flash_lan_output_len(id, now))
        if count == 0 { return nil }
        guard count <= 65_570 else { throw SecureLanError.native(-5) }
        var result = Data(count: Int(count))
        let copied = try result.withUnsafeMutableBytes { buffer in
            try checked(flash_lan_copy_output(id, buffer.bindMemory(to: UInt8.self).baseAddress, buffer.count))
        }
        guard copied == count else { throw SecureLanError.native(-1) }
        return result
        #else
        throw SecureLanError.unavailable
        #endif
    }
    func code() throws -> [UInt16] {
        #if canImport(CFlashLAN)
        var result = [UInt16](repeating: 0, count: 3)
        _ = try result.withUnsafeMutableBufferPointer { try checked(flash_lan_sas(id, $0.baseAddress)) }
        return result
        #else
        throw SecureLanError.unavailable
        #endif
    }
    func received() throws -> Data {
        #if canImport(CFlashLAN)
        let count = try checked(flash_lan_received_len(id))
        guard count > 0, count <= BackupService.maxFileBytes else { throw SecureLanError.invalidBackup }
        var data = Data(count: Int(count))
        let copied = try data.withUnsafeMutableBytes { buffer in
            try checked(flash_lan_copy_received(id, buffer.bindMemory(to: UInt8.self).baseAddress, buffer.count))
        }
        guard copied == count else { throw SecureLanError.invalidBackup }
        return data
        #else
        throw SecureLanError.unavailable
        #endif
    }
    func validated(_ valid: Bool, now: UInt64) throws {
        #if canImport(CFlashLAN)
        _ = try checked(flash_lan_validated(id, valid ? 1 : 0, now))
        #else
        throw SecureLanError.unavailable
        #endif
    }
}
