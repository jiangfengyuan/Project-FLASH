// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import SwiftUI

/// Home 仪表盘顶部问候区：左侧问候语 + 副标题，右侧搜索框与「+ 新建」菜单。
struct GreetingHeaderView: View {
    @Binding var searchText: String
    /// 可选的外部焦点绑定（如 Home 的 ⌘K 聚焦）；nil 表示不接管焦点
    let focus: FocusState<Bool>.Binding?
    let onNewLog: () -> Void
    let onNewIdea: () -> Void

    @State private var isSearchHovered = false
    @State private var isNewHovered = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(searchText: Binding<String>,
         focus: FocusState<Bool>.Binding? = nil,
         onNewLog: @escaping () -> Void,
         onNewIdea: @escaping () -> Void) {
        _searchText = searchText
        self.focus = focus
        self.onNewLog = onNewLog
        self.onNewIdea = onNewIdea
    }

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text(greeting)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(Color.primary)

                Text("今天也记录一点什么吧。")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.secondary)
            }

            Spacer(minLength: 16)

            searchField
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

    // MARK: - Search

    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.secondary)

            TextField("搜索", text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .foregroundStyle(Color.primary)
                // 外观由自绘胶囊承担；系统焦点环只会贴着内层 NSTextField 画出一圈
                // 与胶囊脱节的蓝色小框（用户截图里搜索框附近的蓝色小标签即此）
                .focusEffectDisabled()
                .modifier(SearchFocusModifier(focus: focus))
                .onExitCommand {
                    // Esc：清空搜索并失焦，时间线恢复
                    searchText = ""
                    focus?.wrappedValue = false
                }

            Text("⌘K")
                .font(.system(size: 11, weight: .medium))
                .monospacedDigit()
                .foregroundStyle(Color.secondary)
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.primary.opacity(0.06))
                )
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(width: 220)
        .background(
            Capsule()
                .fill(Color.primary.opacity(isSearchHovered ? 0.07 : 0.05))
        )
        .overlay(
            Capsule()
                .strokeBorder(Color.primary.opacity(isSearchHovered ? 0.14 : 0.10), lineWidth: 1)
        )
        .onHover { isSearchHovered = $0 }
        .animation(Motion.quick(reduceMotion), value: isSearchHovered)
        .help("搜索 ⌘K")
    }

    // MARK: - New Menu

    /// 「+ 新建」下拉菜单：日志/灵感立即可建，任务/情绪为后续版本预留（禁用）。
    /// 自定义 label + borderlessButton 样式，保持原 accent 胶囊外观不变。
    private var newMenu: some View {
        Menu {
            Button("新建日志") { onNewLog() }
            Button("新建灵感") { onNewIdea() }
            Divider()
            Button("新建任务（后续版本）") {}
                .disabled(true)
            Button("新建情绪（后续版本）") {}
                .disabled(true)
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "plus")
                    .font(.system(size: 12, weight: .semibold))
                Text("新建")
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundStyle(Color.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
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

/// 有条件地应用 .focused 绑定（focus 为 nil 时原样返回）
private struct SearchFocusModifier: ViewModifier {
    let focus: FocusState<Bool>.Binding?

    func body(content: Content) -> some View {
        if let focus {
            content.focused(focus)
        } else {
            content
        }
    }
}

#Preview {
    GreetingHeaderView(searchText: .constant(""), onNewLog: {}, onNewIdea: {})
        .padding(24)
        .frame(width: 720)
}
