import Foundation
import Network
import Testing
@testable import FlashCore

@Suite("Legacy LAN disablement")
struct LegacyLANDisablementTests {
    @Test @MainActor func everyApplicationActionStaysIdleAndClearsStalePayload() {
        for action in 0..<3 {
            let controller = LocalBackupTransferController()
            defer { controller.cancel() }
            controller.receivedJSON = "fictional stale transfer"
            controller.selectedDevice = LocalTransferDevice(id: "fixture", name: "Spoofed name",
                endpoint: .hostPort(host: .ipv4(.loopback), port: 9))
            controller.enteredPIN = "123456"
            switch action {
            case 0: controller.startSending(json: "fictional backup")
            case 1: controller.startReceiving()
            default: controller.connect()
            }
            #expect(controller.mode == .idle)
            #expect(controller.pin.isEmpty && controller.devices.isEmpty)
            #expect(controller.receivedJSON == nil)
            #expect(controller.errorMessage?.contains("局域网传输暂时停用") == true)
            #expect(controller.errorMessage?.contains("导出备份") == true)
        }
    }
}
