// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import SwiftUI
import FlashCore

/// Home 顶部问候区：问候语 + 「+ 新建」菜单。
/// 「记录」「灵感」开编辑面板，「情绪」直达情绪记录，「任务」直达任务编辑器；
/// 全局搜索已由「记录」页（⌘K）承担，问候区不再内嵌搜索框。
public struct GreetingHeaderView: View {
    public let onNewLog: () -> Void
    public let onNewIdea: () -> Void
    public let onNewEmotion: () -> Void
    public let onNewTask: () -> Void

    @State private var isNewHovered = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(onNewLog: @escaping () -> Void, onNewIdea: @escaping () -> Void,
                onNewEmotion: @escaping () -> Void, onNewTask: @escaping () -> Void) {
        self.onNewLog = onNewLog
        self.onNewIdea = onNewIdea
        self.onNewEmotion = onNewEmotion
        self.onNewTask = onNewTask
    }

    public var body: some View {
        HStack(alignment: .center, spacing: Spacing.md) {
            VStack(alignment: .leading, spacing: 6) { // 6：问候语与副标题的紧凑节奏（无对应令牌）
                Text(greeting)
                    .flashPageTitle()

                Text("今天也记录一点什么吧。")
                    .font(Typography.secondary)
                    .foregroundStyle(Color.secondary)
            }

            Spacer(minLength: Spacing.md)
            newMenu
        }
    }

    // MARK: - Greeting

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<11: return "早上好 ☀️"
        case 11..<18: return "下午好 🌤"
        default: return "晚上好 🌙"
        }
    }

    // MARK: - New Menu

    /// 「+ 新建」下拉菜单：记录/灵感开输入面板，情绪直达情绪记录，任务直达任务编辑器。
    /// 自定义 label + borderlessButton 样式，保持 accent 胶囊外观。
    private var newMenu: some View {
        Menu {
            Button("新建记录") { onNewLog() }
            Button("新建灵感") { onNewIdea() }
            Divider()
            Button("记录情绪") { onNewEmotion() }
            Button("新建任务") { onNewTask() }
        } label: {
            HStack(spacing: Spacing.xxs) {
                Image(systemName: "plus")
                    .font(Typography.secondary.weight(.semibold))
                Text("新建")
                    .font(Typography.secondary.weight(.semibold))
            }
            .foregroundStyle(Color.white)
            .padding(.horizontal, 14) // 胶囊横向内距：无对应令牌（sm 偏紧、md 偏宽）
            .padding(.vertical, Spacing.xs)
            .background(
                Capsule()
                    .fill(BrandColors.accent.opacity(isNewHovered ? 0.85 : 1.0))
            )
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .onHover { isNewHovered = $0 }
        .animation(Motion.quick(reduceMotion), value: isNewHovered)
        .help("新建记录 ⌘N")
    }
}

#Preview {
    GreetingHeaderView(onNewLog: {}, onNewIdea: {}, onNewEmotion: {}, onNewTask: {})
        .padding(Spacing.lg)
        .frame(width: 720)
        .background(BrandColors.pageBackground)
}
