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
            controller.receivedBackup = ImportPreview(logCount: 0, emotionCount: 0,
                skippedLogs: 0, skippedEmotions: 0, taskCount: 0, skippedTasks: 0,
                logs: [], emotions: [], tasks: [], sourceVersion: "fictional stale transfer")
            controller.selectedDevice = LocalTransferDevice(id: "fixture", name: "Spoofed name",
                endpoint: .hostPort(host: .ipv4(.loopback), port: 9))
            switch action {
            case 0: controller.startSending { Issue.record("Disabled LAN invoked snapshot provider"); return "fictional backup" }
            case 1: controller.startReceiving()
            default: controller.connect()
            }
            #expect(controller.mode == .idle)
            #expect(controller.shortCode.isEmpty && controller.devices.isEmpty)
            #expect(controller.receivedBackup == nil)
            #expect(controller.errorMessage?.contains("局域网传输暂时停用") == true)
            #expect(controller.errorMessage?.contains("导出备份") == true)
        }
    }
}
