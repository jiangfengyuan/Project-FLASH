// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import SwiftUI
import FlashCore

/// 顶部轻提示（toast）：悬浮层玻璃胶囊（`flashGlassBackground`，macOS 26+ Liquid Glass /
/// macOS 15 regularMaterial + 细边框）+ 悬浮层阴影令牌。
/// 出现/消失过渡内置为 FlashMotion `.pop`（淡入 + 缩放 0.94，锚点顶部），
/// 尊重 Reduce Motion。已实测：SwiftUI 会采用被插入视图 body 根部的 transition，
/// 因此调用方只需用 `Motion.animate`/`withAnimation` 切换 message 即可，
/// 不要再叠加自己的 `.transition`（会与内置过渡复合）。
/// 自动消隐由外部定时把 message 置回 nil（参考 HomeView 用法）。
public struct ToastView: View {
    public let message: String
    /// 可选的行内操作（如「撤销」）；nil 时为纯文案胶囊
    public let actionTitle: String?
    public let action: (@MainActor () -> Void)?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(message: String, actionTitle: String? = nil, action: (@MainActor () -> Void)? = nil) {
        self.message = message
        self.actionTitle = actionTitle
        self.action = action
    }

    public var body: some View {
        HStack(spacing: Spacing.sm) {
            Text(message)
                .font(.body.weight(.medium))
                .foregroundStyle(Color.primary)
                .accessibilityLabel(message)
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(BrandColors.brandPrimary)
                    .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14) // 胶囊横向呼吸：无对应间距令牌（sm 偏紧、md 偏宽）
        .padding(.vertical, Spacing.xs)
        #if os(iOS)
        .flashVellum(in: Capsule())
        #else
        .flashGlassBackground(in: Capsule())
        #endif
        .flashElevatedShadow()
        .accessibilityElement(children: .contain)
        .transition(.pop(reduceMotion: reduceMotion))
    }
}

/// 一条 toast 请求：文案 + 可选操作（撤销等）。每次新建都有新 id，相同文案连发也会重置计时
public struct FlashToast: Identifiable, Equatable {
    public let id = UUID()
    public var message: String
    public var actionTitle: String?
    public var action: (@MainActor () -> Void)?

    public init(_ message: String, actionTitle: String? = nil, action: (@MainActor () -> Void)? = nil) {
        self.message = message
        self.actionTitle = actionTitle
        self.action = action
    }

    public static func == (lhs: FlashToast, rhs: FlashToast) -> Bool { lhs.id == rhs.id }
}

/// 顶部 toast 承载：出现动画 + 自动消隐（纯文案 1.6s；带操作 4s，给足点「撤销」的时间）。
/// 点操作后立即收起。替代各页重复的 toastMessage / toastID / task 计时样板。
private struct FlashToastModifier: ViewModifier {
    @Binding var toast: FlashToast?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                if let toast {
                    ToastView(message: toast.message, actionTitle: toast.actionTitle,
                              action: toast.action.map { action in
                                  { action(); self.toast = nil }
                              })
                        .padding(.top, Spacing.sm)
                        .id(toast.id)
                }
            }
            .animation(reduceMotion ? Motion.reducedFade(true) : Motion.spring(), value: toast)
            .task(id: toast?.id) {
                guard let current = toast else { return }
                try? await Task.sleep(for: .seconds(current.action == nil ? 1.6 : 4))
                guard !Task.isCancelled, toast?.id == current.id else { return }
                toast = nil
            }
    }
}

public extension View {
    func flashToast(_ toast: Binding<FlashToast?>) -> some View {
        modifier(FlashToastModifier(toast: toast))
    }
}

#Preview {
    VStack(spacing: Spacing.md) {
        ToastView(message: "✓ 已保存到日志")
        ToastView(message: "✓ 已保存到灵感")
    }
    .padding(Spacing.lg)
    .frame(width: 360, height: 160)
}
