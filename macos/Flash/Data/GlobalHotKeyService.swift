// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Carbon
import Observation
import FlashCore
import FlashDesign

/// 全局热键服务（PRD §13.2）：Carbon `RegisterEventHotKey`——
/// App Sandbox 内可用，无需辅助功能权限，进程退出时系统自动回收注册。
///
/// 线程模型：类隔离在 MainActor（全局 actor 隔离类隐式 Sendable）；
/// Carbon 事件回调是 C 函数（非隔离），经 Unmanaged 还原 self 后
/// `Task { @MainActor in }` 干净跳回主线程派发。
@MainActor
@Observable
final class GlobalHotKeyService {
    static let shared = GlobalHotKeyService()

    /// 注册状态：设置页据 `.failed` 提示「快捷键被占用，请改键」
    enum RegistrationState: Equatable {
        case unregistered
        case registered(KeyChord)
        /// 冲突/不可用（被占用时 status = eventHotKeyExistsErr -9878）
        case failed(KeyChord, OSStatus)
    }

    private(set) var state: RegistrationState = .unregistered

    /// 热键按下回调（MainActor），由 QuickCaptureController 接线
    @ObservationIgnored var onHotKeyPressed: (() -> Void)?

    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?
    /// 自管理 EventHotKeyID：四字符签名 'FLSH' + 固定 id（本应用只有一个热键）
    private let hotKeyID = EventHotKeyID(signature: 0x464C5348, id: 1)

    private init() {}

    /// 注册（或改绑）：先注销旧热键，失败时旧热键不复活，状态暴露给设置页
    func register(_ chord: KeyChord) {
        unregister()
        installHandlerIfNeeded()
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(chord.keyCode, chord.modifiers, hotKeyID,
                                         GetApplicationEventTarget(), 0, &ref)
        if status == noErr {
            hotKeyRef = ref
            state = .registered(chord)
        } else {
            // 固定日志，不含用户数据；UI 文案由设置页按状态给出
            print("[GlobalHotKey] 注册失败 status=\(status) chord=\(chord.displayString)")
            state = .failed(chord, status)
        }
    }

    func unregister() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
        state = .unregistered
    }

    /// 键盘事件处理器整个生命周期只装一次（改绑只换热键不换处理器）
    private func installHandlerIfNeeded() {
        guard handlerRef == nil else { return }
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                      eventKind: UInt32(kEventHotKeyPressed))
        let status = InstallEventHandler(GetApplicationEventTarget(), flashHotKeyHandler,
                                         1, &eventType,
                                         Unmanaged.passUnretained(self).toOpaque(),
                                         &handlerRef)
        if status != noErr {
            print("[GlobalHotKey] 安装事件处理器失败 status=\(status)")
        }
    }

    /// C 回调经 Task hop 后的入口（MainActor）
    fileprivate func handleHotKeyPressed() {
        onHotKeyPressed?()
    }

    /// 与 register/unregister 对称：单例正常随进程存活，这里兜底显式清理
    isolated deinit {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        if let handlerRef { RemoveEventHandler(handlerRef) }
    }
}

/// Carbon 事件回调（@convention(c) 语义的全局函数，非隔离）：
/// 只做 Unmanaged 还原 + MainActor 跳转，不做任何业务。
/// 事件在应用事件循环（主线程）派发，hop 立即执行。
private func flashHotKeyHandler(_ nextHandler: EventHandlerCallRef?,
                                _ event: EventRef?,
                                _ userData: UnsafeMutableRawPointer?) -> OSStatus {
    guard let userData else { return OSStatus(eventNotHandledErr) }
    let service = Unmanaged<GlobalHotKeyService>.fromOpaque(userData).takeUnretainedValue()
    Task { @MainActor in
        service.handleHotKeyPressed()
    }
    return noErr
}
