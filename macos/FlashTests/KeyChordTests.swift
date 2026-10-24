// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Testing
import AppKit
@testable import Flash
import FlashCore
import FlashDesign

@Suite("KeyChord")
struct KeyChordTests {
    private func keyDown(keyCode: UInt16,
                         modifiers: NSEvent.ModifierFlags,
                         characters: String = "a") -> NSEvent {
        NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: modifiers,
                         timestamp: 0, windowNumber: 0, context: nil,
                         characters: characters, charactersIgnoringModifiers: characters,
                         isARepeat: false, keyCode: keyCode)!
    }

    // MARK: - Codable 往返

    @Test func codableRoundtrip() throws {
        let chord = KeyChord(keyCode: 38, modifiers: CarbonKeyModifiers.option | CarbonKeyModifiers.command)
        let data = try JSONEncoder().encode(chord)
        let decoded = try JSONDecoder().decode(KeyChord.self, from: data)
        #expect(decoded == chord)
        #expect(decoded.keyCode == 38)
        #expect(decoded.modifiers == 2304)
    }

    // MARK: - 默认快捷键

    @Test func defaultQuickCaptureIsCmdShiftSpace() {
        let chord = KeyChord.defaultQuickCapture
        #expect(chord.keyCode == 49) // kVK_Space
        #expect(chord.modifiers == CarbonKeyModifiers.command | CarbonKeyModifiers.shift)
        // 修饰键按 macOS 惯例 ⌃⌥⇧⌘ 序（与系统菜单一致，如 ⇧⌘N）
        #expect(chord.displayString == "⇧⌘Space")
    }

    // MARK: - 显示字符串

    @Test func displayStrings() {
        #expect(KeyChord(keyCode: 38, modifiers: CarbonKeyModifiers.option | CarbonKeyModifiers.command)
            .displayString == "⌥⌘J")
        // 修饰键按 macOS 惯例 ⌃⌥⇧⌘ 序，与存储位序无关
        #expect(KeyChord(keyCode: 0, modifiers: CarbonKeyModifiers.command | CarbonKeyModifiers.control
                         | CarbonKeyModifiers.option | CarbonKeyModifiers.shift)
            .displayString == "⌃⌥⇧⌘A")
        #expect(KeyChord(keyCode: 96, modifiers: CarbonKeyModifiers.command).displayString == "⌘F5")
        #expect(KeyChord(keyCode: 126, modifiers: CarbonKeyModifiers.option).displayString == "⌥↑")
        #expect(KeyChord(keyCode: 36, modifiers: CarbonKeyModifiers.command).displayString == "⌘↩")
        // 无修饰位：纯键名（构造上允许，录制入口会拒绝）
        #expect(KeyChord(keyCode: 38, modifiers: 0).displayString == "J")
        // 未收录键码回退可读占位
        #expect(KeyChord(keyCode: 999, modifiers: CarbonKeyModifiers.command).displayString == "⌘Key999")
    }

    // MARK: - NSEvent 映射

    @Test func nsEventCmdShiftSpace() {
        let event = keyDown(keyCode: 49, modifiers: [.command, .shift], characters: " ")
        let chord = KeyChord(nsEvent: event)
        #expect(chord == KeyChord(keyCode: 49,
                                  modifiers: CarbonKeyModifiers.command | CarbonKeyModifiers.shift))
    }

    @Test func nsEventOptionCmdJ() {
        let event = keyDown(keyCode: 38, modifiers: [.option, .command])
        let chord = KeyChord(nsEvent: event)
        #expect(chord == KeyChord(keyCode: 38,
                                  modifiers: CarbonKeyModifiers.option | CarbonKeyModifiers.command))
        #expect(chord?.displayString == "⌥⌘J")
    }

    @Test func nsEventControlShiftF5() {
        let event = keyDown(keyCode: 96, modifiers: [.control, .shift])
        let chord = KeyChord(nsEvent: event)
        #expect(chord == KeyChord(keyCode: 96,
                                  modifiers: CarbonKeyModifiers.control | CarbonKeyModifiers.shift))
        #expect(chord?.displayString == "⌃⇧F5")
    }

    /// 裸键（无修饰键）拒绝：全局热键会吞掉正常输入
    @Test func nsEventWithoutModifiersRejected() {
        let event = keyDown(keyCode: 38, modifiers: [])
        #expect(KeyChord(nsEvent: event) == nil)
    }

    /// 功能/方向键不携带字符语义，但 charactersIgnoringModifiers 非空，允许映射
    @Test func nsEventArrowKeyMaps() {
        let event = keyDown(keyCode: 126, modifiers: [.command], characters: "\u{F700}")
        #expect(KeyChord(nsEvent: event)?.displayString == "⌘↑")
    }

    /// 纯修饰键按下（无字符）拒绝——防御性分支（实际键序走 flagsChanged，不进 keyDown）
    @Test func nsEventModifierOnlyRejected() {
        let event = keyDown(keyCode: 55, modifiers: [.command], characters: "")
        #expect(KeyChord(nsEvent: event) == nil)
    }

    /// NSEvent 带设备相关位（如 numericPad/capsLock）时只取设备无关修饰位
    @Test func nsEventDeviceFlagsFiltered() {
        let event = keyDown(keyCode: 38, modifiers: [.command, .numericPad, .capsLock])
        let chord = KeyChord(nsEvent: event)
        #expect(chord?.modifiers == CarbonKeyModifiers.command)
    }
}
