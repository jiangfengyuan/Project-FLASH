// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import SwiftUI
import FlashDesign

/// 首次启动欢迎页（iOS）：三页横滑（文案与 macOS WelcomeView、Android WelcomeScreen 同源），
/// 末页「开始使用」完成后 setWelcomed。图标随翻页轻弹入场，尊重 Reduce Motion。
struct WelcomeScreen: View {
    let onFinish: () -> Void

    private struct Page: Identifiable {
        let id: Int
        let symbol: String
        let tint: Color
        let title: String
        let subtitle: String
    }

    private let pages: [Page] = [
        Page(id: 0, symbol: "bolt.fill", tint: BrandColors.brandPrimary,
             title: "欢迎来到 Flash", subtitle: "一闪而过的想法，值得被记住"),
        Page(id: 1, symbol: "square.and.pencil", tint: BrandColors.logPurple,
             title: "随手记录", subtitle: "日志与灵感，一键即达"),
        Page(id: 2, symbol: "face.smiling", tint: BrandColors.emotionPink,
             title: "情绪觉察", subtitle: "七级情绪记录，看见自己的变化"),
    ]

    @State private var page = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var isLastPage: Bool { page == pages.count - 1 }

    var body: some View {
        VStack(spacing: Spacing.lg) {
            TabView(selection: $page) {
                ForEach(pages) { item in
                    VStack(spacing: Spacing.sm) {
                        Image(systemName: item.symbol)
                            .scaledSystemFont(size: 64, relativeTo: .largeTitle)
                            .foregroundStyle(item.tint)
                            .symbolEffect(.bounce, value: page == item.id && !reduceMotion)
                            .padding(.bottom, Spacing.xs)
                            .accessibilityHidden(true)
                        Text(item.title)
                            .font(Typography.heroTitle)
                            .multilineTextAlignment(.center)
                        Text(item.subtitle)
                            .font(Typography.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, Spacing.lg)
                    .tag(item.id)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))

            Button {
                if isLastPage {
                    onFinish()
                } else {
                    Motion.animate(Motion.soft(), reduceMotion: reduceMotion) { page += 1 }
                }
            } label: {
                Text(isLastPage ? "开始使用" : "下一步")
                    .font(Typography.body.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.xs)
            }
            .buttonStyle(.borderedProminent)
            .tint(BrandColors.brandPrimary)
            .padding(.horizontal, Spacing.lg)
            .padding(.bottom, Spacing.lg)
            .sensoryFeedback(.selection, trigger: page)
        }
        .background(BrandColors.pageBackground)
    }
}
