// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import SwiftUI
import FlashCore
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
             title: L("欢迎来到 Flash"), subtitle: L("一闪而过的想法，值得被记住")),
        Page(id: 1, symbol: "square.and.pencil", tint: BrandColors.logPurple,
             title: L("随手记录"), subtitle: L("日志与灵感，一键即达")),
        Page(id: 2, symbol: "face.smiling", tint: BrandColors.emotionPink,
             title: L("情绪觉察"), subtitle: L("七级情绪记录，看见自己的变化")),
    ]

    @State private var page = 0
    /// 欢迎页图标手绘圈：固定基准 132，随系统字体档位缩放
    @ScaledMetric(relativeTo: .largeTitle) private var heroRingSize: CGFloat = 132
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var isLastPage: Bool { page == pages.count - 1 }

    var body: some View {
        VStack(spacing: Spacing.lg) {
            TabView(selection: $page) {
                ForEach(pages) { item in
                    VStack(spacing: Spacing.sm) {
                        Image(systemName: item.symbol)
                            .scaledSystemFont(size: 52, relativeTo: .largeTitle)
                            .foregroundStyle(item.tint)
                            .symbolEffect(.bounce, value: page == item.id && !reduceMotion)
                            .frame(width: heroRingSize, height: heroRingSize)
                            .background { HandDrawnRing(seed: item.title, tint: item.tint) }
                            .padding(.bottom, Spacing.sm)
                            .accessibilityHidden(true)
                        Text(item.title)
                            .font(Typography.heroTitle)
                            .foregroundStyle(BrandColors.textPrimary)
                            .multilineTextAlignment(.center)
                            .flashHandUnderline(seed: "welcome-\(item.id)", color: item.tint, widthFraction: 0.5)
                            .padding(.bottom, Spacing.xxs)
                        Text(item.subtitle)
                            .font(Typography.body)
                            .foregroundStyle(BrandColors.textSecondary)
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
                Text(isLastPage ? L("开始使用") : L("下一步"))
                    .font(Typography.body.weight(.semibold))
                    .foregroundStyle(BrandColors.onBrandPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.xs)
            }
            .buttonStyle(.borderedProminent)
            .tint(BrandColors.brandPrimary)
            .padding(.horizontal, Spacing.lg)
            .padding(.bottom, Spacing.lg)
            .sensoryFeedback(.selection, trigger: page)
        }
        .flashPageBackground()
    }
}
