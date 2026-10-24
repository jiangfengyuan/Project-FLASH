// Copyright (c) 2026 Fengyuan Jiang · MPL-2.0
import Foundation
import Observation
@preconcurrency import Network

public enum LocalBackupAvailability {
    public static let message = "局域网传输暂时停用：旧协议存在安全风险。请使用‘导出备份’或‘系统分享’，通过可信渠道传输 JSON 文件。"
}

public struct LocalTransferDevice: Identifiable, Hashable, @unchecked Sendable {
    /// 设备条目键：host:port（规格 v1.1 设备发现）；同名伪造服务不同主机并列显示、互不顶替
    public let id: String
    public let name: String
    public let endpoint: NWEndpoint

    public init(id: String, name: String, endpoint: NWEndpoint) {
        self.id = id
        self.name = name
        self.endpoint = endpoint
    }
}

public enum LocalTransferMode: Sendable { case idle, sending, receiving, connecting }

/// Fail closed while a reviewed replacement is selected. There is no listener,
/// browser, connector, PIN generation, export or runtime enable switch here.
@MainActor @Observable
public final class LocalBackupTransferController {
    public static let shared = LocalBackupTransferController()
    public var mode: LocalTransferMode = .idle
    public var pin = ""
    public var devices: [LocalTransferDevice] = []
    public var selectedDevice: LocalTransferDevice?
    public var enteredPIN = ""
    public var receivedJSON: String?
    public var errorMessage: String?
    public var sendCompleted = false

    public func startSending(json: String = "") { unavailable() }
    public func startReceiving() { unavailable() }
    public func connect() { unavailable() }

    private func unavailable() {
        cancel()
        errorMessage = LocalBackupAvailability.message
    }

    public func cancel() {
        mode = .idle
        pin = ""
        devices = []
        selectedDevice = nil
        enteredPIN = ""
        receivedJSON = nil
        sendCompleted = false
    }
}
