// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import SwiftUI
import FlashCore
import FlashDesign

/// 「灵感提醒」分组（PRD v3 §6.3）：推送开关 + 频率（每天 / 每 3 天 / 每周），默认开启、每天。
/// 角标与此刻提示行不受开关影响（属于页面内提示）；开关只控制本地通知。
struct IdeaReminderSection: View {
    @EnvironmentObject private var settings: SettingsStore
    @Environment(IdeaReminderCenter.self) private var ideaReminders

    var body: some View {
        Section {
            Toggle(isOn: enabledBinding) {
                SettingsRowLabel(title: "灵感提醒", systemImage: "lightbulb.max", color: BrandColors.ideaYellowText)
            }
            .tint(BrandColors.brandPrimary)
            if settings.ideaReminderEnabled {
                Picker("提醒频率", selection: frequencyBinding) {
                    ForEach(IdeaReminder.Frequency.allCases, id: \.self) { frequency in
                        Text(frequency.displayName).tag(frequency)
                    }
                }
            }
        } header: {
            Text("灵感提醒")
        } footer: {
            Text(footerText)
        }
        .animation(.default, value: settings.ideaReminderEnabled)
    }

    private var footerText: String {
        let status = ideaReminders.unreadCount > 0
            ? "当前有 \(ideaReminders.unreadCount) 个未查看的想法。"
            : "目前没有未查看的想法。"
        return status + "累计 \(IdeaReminder.threshold) 个以上时，晚上 8 点提醒你梳理；打开查看过的想法不再计入。"
    }

    private var enabledBinding: Binding<Bool> {
        Binding(get: { settings.ideaReminderEnabled }, set: { settings.setIdeaReminderEnabled($0) })
    }

    private var frequencyBinding: Binding<IdeaReminder.Frequency> {
        Binding(get: { settings.ideaReminderFrequency }, set: { settings.setIdeaReminderFrequency($0) })
    }
}
