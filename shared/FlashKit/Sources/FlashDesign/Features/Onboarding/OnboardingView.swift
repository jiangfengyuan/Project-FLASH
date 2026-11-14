// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import SwiftUI
import FlashCore

/// 新手引导的四个步骤（四端同一内容与顺序：欢迎 → 能做什么 → 隐私 → 偏好）
public enum OnboardingStep: Int, CaseIterable, Sendable {
    case welcome, features, privacy, preferences

    var isFirst: Bool { self == Self.allCases.first }
    var isLast: Bool { self == Self.allCases.last }
    var next: OnboardingStep? { OnboardingStep(rawValue: rawValue + 1) }
    var previous: OnboardingStep? { OnboardingStep(rawValue: rawValue - 1) }
}

/// 首次安装的欢迎与新手引导（iOS 全屏覆盖 / macOS 主窗口），也可从 设置 › 辅助功能 重新打开。
///
/// 交互约定：
/// - 每一步都能「跳过」（Esc），上一步（←）/ 下一步（Return）；iOS 另可左右轻扫；
/// - 最后一步就地设置外观与辅助功能偏好，改动立即生效、随时可在设置里修改；
/// - 读屏：每步切换后焦点移到新标题，步骤指示朗读「第 n 步，共 4 步」，装饰图标不朗读；
/// - 遵守减少动态效果；内容放在滚动容器里，超大字号下不截断。
public struct OnboardingView: View {
    @EnvironmentObject private var settings: SettingsStore
    @FlashReduceMotion private var reduceMotion
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @AccessibilityFocusState private var focusedTitle: OnboardingStep?

    @State private var step: OnboardingStep = .welcome

    private let onFinish: () -> Void

    /// 引导内容的阅读宽度（几何值）：宽窗口 / iPad 上不把文字拉成长行
    private static let contentMaxWidth: CGFloat = 520

    public init(onFinish: @escaping () -> Void) {
        self.onFinish = onFinish
    }

    public var body: some View {
        VStack(spacing: 0) {
            topBar
            pages
            bottomBar
        }
        .background(BrandColors.pageBackground.ignoresSafeArea())
        .flashHaptic(.selection, trigger: step)
        .onChange(of: step) { _, newStep in
            // 读屏焦点跟随到新步骤标题（下一帧，等新页面挂载）
            DispatchQueue.main.async { focusedTitle = newStep }
        }
        #if os(macOS)
        .frame(minWidth: 560, idealWidth: 640, minHeight: 560, idealHeight: 620)
        #endif
    }

    // MARK: - 顶部 / 底部

    private var topBar: some View {
        HStack {
            Spacer()
            if !step.isLast {
                Button("跳过", action: onFinish)
                    .buttonStyle(.borderless)
                    .foregroundStyle(BrandColors.textSecondary)
                    .keyboardShortcut(.cancelAction)
                    .accessibilityHint("跳过介绍，直接开始使用；之后可在设置里重新查看")
            }
        }
        .frame(minHeight: Metrics.minTouchTarget)
        .padding(.horizontal, Metrics.pageGutter)
        .padding(.top, Spacing.xs)
    }

    private var bottomBar: some View {
        // 步骤指示居中（ZStack），不随左右按钮宽度不同而偏移
        ZStack {
            stepIndicator
            HStack {
                if let previous = step.previous {
                    Button("上一步") { go(to: previous) }
                        .buttonStyle(.bordered)
                        .keyboardShortcut(.leftArrow, modifiers: [])
                }
                Spacer()
                Button(step.isLast ? "开始使用" : "下一步") {
                    if let next = step.next { go(to: next) } else { onFinish() }
                }
                .buttonStyle(.borderedProminent)
                .tint(BrandColors.brandPrimary)
                .keyboardShortcut(.defaultAction)
            }
            .controlSize(.large)
        }
        .frame(maxWidth: Self.contentMaxWidth)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, Metrics.pageGutter)
        .padding(.vertical, Spacing.lg)
    }

    private var stepIndicator: some View {
        HStack(spacing: Spacing.xs) {
            ForEach(OnboardingStep.allCases, id: \.self) { item in
                Capsule()
                    .fill(item == step ? BrandColors.brandPrimary : BrandColors.weakBorder)
                    .frame(width: item == step ? 20 : 8, height: 8) // 指示点尺寸（几何值）
            }
        }
        .animation(Motion.quick(reduceMotion), value: step)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("第 \(step.rawValue + 1) 步，共 \(OnboardingStep.allCases.count) 步")
    }

    private func go(to target: OnboardingStep) {
        Motion.animate(Motion.soft(), reduceMotion: reduceMotion) { step = target }
    }

    // MARK: - 页面

    @ViewBuilder
    private var pages: some View {
        #if os(iOS)
        // 轻扫翻页；页码指示用底部自绘指示点（系统圆点隐藏，避免与按钮行重复）
        TabView(selection: $step) {
            ForEach(OnboardingStep.allCases, id: \.self) { item in
                page(item).tag(item)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        #else
        page(step)
            .id(step)
            .transition(.appear(reduceMotion: reduceMotion))
            .frame(maxHeight: .infinity)
        #endif
    }

    private func page(_ item: OnboardingStep) -> some View {
        ScrollView {
            VStack(spacing: Spacing.lg) {
                header(for: item)
                switch item {
                case .welcome: EmptyView()
                case .features: featureList
                case .privacy: privacyList
                case .preferences: preferencesCard
                }
            }
            .frame(maxWidth: Self.contentMaxWidth)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, Metrics.pageGutter)
            .padding(.vertical, Spacing.lg)
        }
        .scrollBounceBehavior(.basedOnSize)
    }

    private func header(for item: OnboardingStep) -> some View {
        let content = Self.header(item)
        return VStack(spacing: Spacing.sm) {
            Image(systemName: content.symbol)
                .scaledSystemFont(size: item == .welcome ? 72 : 56, relativeTo: .largeTitle)
                .foregroundStyle(content.tint)
                .symbolEffect(.bounce, value: step == item && !reduceMotion)
                .padding(.bottom, Spacing.xs)
                .accessibilityHidden(true)
            Text(content.title)
                .font(Typography.heroTitle)
                .foregroundStyle(BrandColors.textPrimary)
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)
                .accessibilityFocused($focusedTitle, equals: item)
            Text(content.subtitle)
                .font(Typography.body)
                .foregroundStyle(BrandColors.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, item == .welcome ? Spacing.xl : Spacing.sm)
    }

    private struct Header {
        let symbol: String
        let tint: Color
        let title: String
        let subtitle: String
    }

    private static func header(_ item: OnboardingStep) -> Header {
        switch item {
        case .welcome:
            Header(symbol: "bolt.fill", tint: BrandColors.brandPrimary,
                   title: "欢迎来到 Flash",
                   subtitle: "闪过即留，一目了然。\n把一闪而过的念头、情绪与待办，安心留在这台设备上。")
        case .features:
            Header(symbol: "sparkles", tint: BrandColors.logPurple,
                   title: "Flash 能帮你做什么",
                   subtitle: "四个模块，覆盖从记下到回看的全过程。")
        case .privacy:
            Header(symbol: "lock.shield", tint: BrandColors.accessibleGreen,
                   title: "你的记录只属于你",
                   subtitle: "本地优先：没有账号，也没有后端。")
        case .preferences:
            Header(symbol: "accessibility", tint: BrandColors.brandPrimary,
                   title: "让 Flash 更适合你",
                   subtitle: "以下选项随时可在「设置 › 辅助功能」中修改。")
        }
    }

    // MARK: - 各步内容

    private var featureList: some View {
        SolidCard {
            VStack(alignment: .leading, spacing: Spacing.md) {
                OnboardingRow(symbol: "square.and.pencil", tint: BrandColors.logPurple,
                              title: "随手记录", detail: "日志与灵感一键记下，用 !! 标记重要程度。")
                OnboardingRow(symbol: "face.smiling", tint: BrandColors.emotionPink,
                              title: "情绪觉察", detail: "七级情绪加上具体感受，看见自己的变化。")
                OnboardingRow(symbol: "calendar", tint: BrandColors.accessibleGreen,
                              title: "任务与日历", detail: "按日期回看记录；任务可设系统提醒。")
                OnboardingRow(symbol: "chart.line.uptrend.xyaxis", tint: BrandColors.brandPrimary,
                              title: "回顾", detail: "周、月趋势与情绪分布，发现记录的节奏。")
            }
            .padding(Metrics.cardInset)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var privacyList: some View {
        SolidCard {
            VStack(alignment: .leading, spacing: Spacing.md) {
                OnboardingRow(symbol: Self.deviceSymbol, tint: BrandColors.accessibleGreen,
                              title: "数据保存在这台设备", detail: "无需注册，不上传到任何服务器。")
                OnboardingRow(symbol: "square.and.arrow.up", tint: BrandColors.accessibleGreen,
                              title: "备份与传输由你发起", detail: "随时导出 JSON 备份，或在可信局域网内直传到另一台设备。")
                OnboardingRow(symbol: "exclamationmark.shield", tint: BrandColors.accessibleGreen,
                              title: "妥善保管备份文件", detail: "备份是明文 JSON，请只保存或分享到可信的位置。")
            }
            .padding(Metrics.cardInset)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    #if os(macOS)
    private static let deviceSymbol = "desktopcomputer"
    #else
    private static let deviceSymbol = "iphone"
    #endif

    private var preferencesCard: some View {
        SolidCard {
            VStack(alignment: .leading, spacing: Spacing.md) {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("外观").font(Typography.cardTitle)
                    Picker("外观", selection: themeBinding) {
                        ForEach(ThemeMode.allCases, id: \.self) { Text($0.displayName).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }

                Divider()

                Toggle(isOn: reduceMotionBinding) {
                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        Text("减少动态效果").font(Typography.cardTitle)
                        Text(systemReduceMotion
                             ? "系统已开启「减弱动态效果」，应用会自动遵循。"
                             : "关闭页面切换、卡片入场与弹性动画。")
                            .font(Typography.caption)
                            .foregroundStyle(BrandColors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                #if os(iOS)
                Divider()

                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("文字大小").font(Typography.cardTitle)
                    Picker("文字大小", selection: textSizeBinding) {
                        ForEach(TextSizePreference.allCases, id: \.self) { Text($0.displayName).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    Text("系统字体设置更大时，以系统为准。")
                        .font(Typography.caption)
                        .foregroundStyle(BrandColors.textSecondary)
                }

                Divider()

                Toggle(isOn: hapticsBinding) {
                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        Text("触感反馈").font(Typography.cardTitle)
                        Text("保存、切换时的轻微振动。")
                            .font(Typography.caption)
                            .foregroundStyle(BrandColors.textSecondary)
                    }
                }
                #endif
            }
            .padding(Metrics.cardInset)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var themeBinding: Binding<ThemeMode> {
        Binding(get: { settings.themeMode }, set: { settings.setThemeMode($0) })
    }

    private var reduceMotionBinding: Binding<Bool> {
        Binding(get: { settings.reduceMotion }, set: { settings.setReduceMotion($0) })
    }

    #if os(iOS)
    private var textSizeBinding: Binding<TextSizePreference> {
        Binding(get: { settings.textSize }, set: { settings.setTextSize($0) })
    }

    private var hapticsBinding: Binding<Bool> {
        Binding(get: { settings.hapticsEnabled }, set: { settings.setHapticsEnabled($0) })
    }
    #endif
}

/// 引导里的说明行：图标列 + 标题 + 说明；读屏合并为一句
private struct OnboardingRow: View {
    let symbol: String
    let tint: Color
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.sm) {
            Image(systemName: symbol)
                .foregroundStyle(tint)
                .flashIconColumn()
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(title)
                    .font(Typography.cardTitle)
                    .foregroundStyle(BrandColors.textPrimary)
                Text(detail)
                    .font(Typography.secondary)
                    .foregroundStyle(BrandColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
