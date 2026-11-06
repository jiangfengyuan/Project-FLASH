// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import AppKit
import FlashCore
import FlashDesign

extension KeyChord {
    /// 从 NSEvent 构造（设置页录制）：deviceIndependentFlags → Carbon 修饰位。
    /// 无修饰键或纯修饰键按下（charactersIgnoringModifiers 为空）返回 nil——
    /// 裸键做全局热键会吞掉正常输入，不允许。
    /// KeyChord 本体在 FlashKit（跨端共享），AppKit 依赖只留在 macOS 端。
    init?(nsEvent: NSEvent) {
        let flags = nsEvent.modifierFlags.intersection(.deviceIndependentFlagsMask)
        var mods: UInt32 = 0
        if flags.contains(.control) { mods |= CarbonKeyModifiers.control }
        if flags.contains(.option) { mods |= CarbonKeyModifiers.option }
        if flags.contains(.shift) { mods |= CarbonKeyModifiers.shift }
        if flags.contains(.command) { mods |= CarbonKeyModifiers.command }
        guard mods != 0 else { return nil }
        guard let chars = nsEvent.charactersIgnoringModifiers, !chars.isEmpty else { return nil }
        self.init(keyCode: UInt32(nsEvent.keyCode), modifiers: mods)
    }
}
