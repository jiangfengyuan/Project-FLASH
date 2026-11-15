// Copyright (c) 2026 Fengyuan Jiang. SPDX-License-Identifier: MPL-2.0
import Foundation
import CFlashLAN

// Standalone C ABI smoke test; no application store, discovery or sockets.
func check(_ code: Int64) { precondition(code >= 0, "LAN test code \(code)") }
func drain(_ from: UInt64, _ to: UInt64) {
    while true {
        let length = flash_lan_output_len(from, 0)
        check(length)
        if length == 0 { break }
        var buffer = [UInt8](repeating: 0, count: Int(length))
        check(buffer.withUnsafeMutableBufferPointer { flash_lan_copy_output(from, $0.baseAddress, $0.count) })
        // Exercise the C ABI parser across single-byte callbacks.
        for byte in buffer {
            var one = byte
            check(withUnsafePointer(to: &one) { flash_lan_receive(to, $0, 1, 0) })
        }
        check(flash_lan_wrote(from, 0))
    }
}
let sender = flash_lan_new(1, 0, 120_000)
let receiver = flash_lan_new(2, 0, 120_000)
precondition(sender != 0 && receiver != 0)
defer { flash_lan_free(sender); flash_lan_free(receiver) }
drain(receiver, sender); drain(sender, receiver)
drain(receiver, sender); drain(sender, receiver)
var s = [UInt16](repeating: 0, count: 3)
var r = s
check(s.withUnsafeMutableBufferPointer { flash_lan_sas(sender, $0.baseAddress) })
check(r.withUnsafeMutableBufferPointer { flash_lan_sas(receiver, $0.baseAddress) })
precondition(s == r) // Codes are never printed.
let backup = Array("{\"fixture\":\"C ABI round-trip\"}".utf8)
precondition(backup.withUnsafeBufferPointer { flash_lan_provide(sender, $0.baseAddress, $0.count, 0) } < 0)
check(flash_lan_accept(sender, 0)); check(flash_lan_accept(receiver, 0))
drain(sender, receiver); drain(receiver, sender)
check(backup.withUnsafeBufferPointer { flash_lan_provide(sender, $0.baseAddress, $0.count, 0) })
drain(sender, receiver)
let count = flash_lan_received_len(receiver)
check(count)
var received = [UInt8](repeating: 0, count: Int(count))
check(received.withUnsafeMutableBufferPointer { flash_lan_copy_received(receiver, $0.baseAddress, $0.count) })
precondition(received == backup)
_ = try JSONSerialization.jsonObject(with: Data(received)) // Fixture-only validation.
precondition(flash_lan_state(sender) == 12)
check(flash_lan_validated(receiver, 1, 0)); drain(receiver, sender)
precondition(flash_lan_state(sender) == 13)
print("Swift/C/Rust candidate round-trip: PASS (no database import)")
