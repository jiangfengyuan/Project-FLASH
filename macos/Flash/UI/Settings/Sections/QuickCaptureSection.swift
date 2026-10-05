// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import AppKit
import SwiftUI

/// 「Quick Capture」分组（PRD §13.2/§13.3）：全局快捷键展示 + 录制改键 + 冲突引导 + 恢复默认。
/// 录制态用 NSEvent local monitor 捕获下一次按键组合（Esc 取消），保存经
/// `SettingsStore.setQuickCaptureHotkey`；重注册由 QuickCaptureController 的订阅完成，
/// 注册结果（含被占用失败）经 GlobalHotKeyService.state 回本组提示。
struct QuickCaptureSection: View {
    @EnvironmentObject private var settings: SettingsStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// 热键服务单例（@Observable）：只读 state，用于冲突提示
    @State private var hotKeys = GlobalHotKeyService.shared

    /// 分组入场标记（stagger 淡入上移），由 SettingsView 驱动
    let appeared: Bool

    @State private var isRecording = false
    @State private var keyMonitor: Any? = nil
    @State private var hint: String? = nil

    var body: some View {
        Section("Quick Capture") {
            HStack {
                SettingsRowLabel(title: "全局快捷键", systemImage: "keyboard",
                                 color: BrandColors.brandPrimary)
                Spacer()
                if isRecording {
                    Text("按下新快捷键…（Esc 取消）")
                        .font(Typography.secondary)
                        .foregroundStyle(.secondary)
                } else {
                    Text(settings.quickCaptureHotkey.displayString)
                        .font(Typography.secondary)
                        .monospaced()
                        .padding(.horizontal, Spacing.xs)
                        .padding(.vertical, Spacing.xxs)
                        .background(BrandColors.weakSurface,
                                    in: RoundedRectangle(cornerRadius: Radius.control, style: .continuous))
                }
                Button(isRecording ? "取消" : "录制") {
                    isRecording ? stopRecording() : startRecording()
                }
            }

            if let hint {
                Text(hint)
                    .font(Typography.caption)
                    .foregroundStyle(Color(nsColor: .systemRed))
            }

            // 注册失败（多为被系统/输入法/其他应用占用）：引导改键（PRD §13.2 补充要求）
            if case .failed(let chord, _) = hotKeys.state {
                Text("「\(chord.displayString)」快捷键被占用，请改键（⇧⌘Space 可能与输入法冲突）。")
                    .font(Typography.caption)
                    .foregroundStyle(Color(nsColor: .systemRed))
            }

            HStack {
                Button("恢复默认 ⇧⌘Space") {
                    settings.setQuickCaptureHotkey(.defaultQuickCapture)
                }
                .disabled(settings.quickCaptureHotkey == .defaultQuickCapture)
                Spacer()
            }

            Text("全局快捷键在 App 运行时可用（含仅菜单栏驻留、主窗口已关闭）。"
                 + "面板内 Enter 或 ⌘Enter 保存，Esc 取消；未提交关闭会保留草稿。")
                .font(Typography.caption)
                .foregroundStyle(.secondary)
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: !appeared && !reduceMotion ? 6 : 0)
        .onDisappear { stopRecording() }
    }

    // MARK: - 录制

    private func startRecording() {
        hint = nil
        isRecording = true
        // local monitor 只在本 App 前台时收事件——录制场景必然在设置页前台，语义吻合；
        // 录制态吞掉全部按键（return nil），避免按键落进其他输入框
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            handleRecordedKey(event)
            return nil
        }
    }

    private func stopRecording() {
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
            self.keyMonitor = nil
        }
        isRecording = false
    }

    private func handleRecordedKey(_ event: NSEvent) {
        // Esc（无修饰键）取消录制，不改动当前绑定
        if event.keyCode == 53, // kVK_Escape
           event.modifierFlags.intersection(.deviceIndependentFlagsMask).isEmpty {
            hint = nil
            stopRecording()
            return
        }
        if let chord = KeyChord(nsEvent: event) {
            settings.setQuickCaptureHotkey(chord) // 持久化 + 触发重注册
            hint = nil
            stopRecording()
        } else {
            hint = "快捷键需要包含修饰键（⌘ ⌥ ⌃ ⇧），请再试一次"
        }
    }
}
