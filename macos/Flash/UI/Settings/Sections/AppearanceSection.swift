// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import SwiftUI

/// 「外观与使用」分组：主题模式分段选择
struct AppearanceSection: View {
    @EnvironmentObject private var settings: SettingsStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// 分组入场标记（stagger 淡入上移），由 SettingsView 驱动
    let appeared: Bool

    var body: some View {
        Section("外观与使用") {
            Picker(selection: themeBinding) {
                ForEach(ThemeMode.allCases, id: \.self) {
                    Text($0.displayName).tag($0)
                }
            } label: {
                SettingsRowLabel(title: "主题", systemImage: "circle.lefthalf.filled", color: .blue)
            }
            .pickerStyle(.segmented)
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: !appeared && !reduceMotion ? 6 : 0)
    }

    private var themeBinding: Binding<ThemeMode> {
        Binding(get: { settings.themeMode }, set: { settings.setThemeMode($0) })
    }
}
