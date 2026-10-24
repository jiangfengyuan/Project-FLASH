// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation

/// Carbon 修饰键位（HIToolbox Events.h，ABI 稳定常量）：
/// cmdKey = 1<<8，shiftKey = 1<<9，optionKey = 1<<11，controlKey = 1<<12。
/// 本地重定义而非 import Carbon：KeyChord 是纯数据模型（Codable/单测），不拉 Carbon 头。
public enum CarbonKeyModifiers: Sendable {
    public static let command: UInt32 = 256
    public static let shift: UInt32 = 512
    public static let option: UInt32 = 2048
    public static let control: UInt32 = 4096
}

/// 全局快捷键组合（PRD §13.2）：Carbon 虚拟键码 + Carbon 修饰位。
/// 持久化走 Codable JSON（SettingsStore.quickCaptureHotkey），
/// 注册走 RegisterEventHotKey（GlobalHotKeyService）。
public struct KeyChord: Codable, Equatable, Sendable {
    /// Carbon / AppKit 虚拟键码（ANSI 布局，如 kVK_Space = 49）
    public var keyCode: UInt32
    /// Carbon 修饰位（CarbonKeyModifiers 的按位或）
    public var modifiers: UInt32

    /// 默认 Quick Capture 快捷键：⌘⇧Space（PRD §13.2）
    public static let defaultQuickCapture = KeyChord(
        keyCode: 49, // kVK_Space
        modifiers: CarbonKeyModifiers.command | CarbonKeyModifiers.shift)

    public init(keyCode: UInt32, modifiers: UInt32) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }

    // 从 NSEvent 构造（设置页录制）的 init?(nsEvent:) 依赖 AppKit，
    // 位于 macOS 端 macos/Flash/Data/KeyChord+NSEvent.swift

    /// 显示字符串：修饰键按 macOS 惯例 ⌃⌥⇧⌘ 序 + 键名（如 ⌘⇧Space、⌥⌘J）
    public var displayString: String {
        var result = ""
        if modifiers & CarbonKeyModifiers.control != 0 { result += "⌃" }
        if modifiers & CarbonKeyModifiers.option != 0 { result += "⌥" }
        if modifiers & CarbonKeyModifiers.shift != 0 { result += "⇧" }
        if modifiers & CarbonKeyModifiers.command != 0 { result += "⌘" }
        return result + Self.keyName(for: keyCode)
    }

    /// ANSI 虚拟键码 → 键名。未收录的键码回退 `Key<N>`（仍可读、可编解码往返）。
    public static func keyName(for keyCode: UInt32) -> String {
        Self.keyNames[keyCode] ?? "Key\(keyCode)"
    }

    private static let keyNames: [UInt32: String] = [
        // 字母（kVK_ANSI_*）
        0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X",
        8: "C", 9: "V", 11: "B", 12: "Q", 13: "W", 14: "E", 15: "R",
        16: "Y", 17: "T", 31: "O", 32: "U", 34: "I", 35: "P", 37: "L",
        38: "J", 40: "K", 45: "N", 46: "M",
        // 数字行
        18: "1", 19: "2", 20: "3", 21: "4", 23: "5", 22: "6", 26: "7",
        28: "8", 25: "9", 29: "0",
        // 标点
        27: "-", 24: "=", 33: "[", 30: "]", 42: "\\", 41: ";", 39: "'",
        43: ",", 47: ".", 44: "/", 50: "`",
        // 编辑/空白键
        49: "Space", 36: "↩", 48: "⇥", 51: "⌫", 117: "⌦", 53: "⎋",
        // 方向键
        123: "←", 124: "→", 125: "↓", 126: "↑",
        // 功能键
        122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5", 97: "F6",
        98: "F7", 100: "F8", 101: "F9", 109: "F10", 103: "F11", 111: "F12",
    ]
}
