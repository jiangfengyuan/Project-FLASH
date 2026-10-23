// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import SwiftUI
import FlashCore

/// 「数据与安全」分组：导出备份为主操作（.borderedProminent 强调），
/// 系统分享 / 局域网收发 / 标准与恢复导入为普通行按钮（均带 hover 反馈）。
/// 各动作通过闭包抛回 SettingsView（导出/导入状态机、LAN 控制器均由其持有）。
public struct DataSafetySection: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// 导入/导出进行中（期间禁用整组并显示进度行）
    public let isBusy: Bool
    /// 分组入场标记（stagger 淡入上移），由 SettingsView 驱动
    public let appeared: Bool
    public let onShare: () -> Void
    public let onLanSend: () -> Void
    public let onLanReceive: () -> Void
    public let onExport: () -> Void
    public let onImport: () -> Void
    public let onRecoveryImport: () -> Void

    public init(isBusy: Bool, appeared: Bool, onShare: @escaping () -> Void,
                onLanSend: @escaping () -> Void, onLanReceive: @escaping () -> Void,
                onExport: @escaping () -> Void, onImport: @escaping () -> Void,
                onRecoveryImport: @escaping () -> Void) {
        self.isBusy = isBusy
        self.appeared = appeared
        self.onShare = onShare
        self.onLanSend = onLanSend
        self.onLanReceive = onLanReceive
        self.onExport = onExport
        self.onImport = onImport
        self.onRecoveryImport = onRecoveryImport
    }

    public var body: some View {
        Section("数据与安全") {
            // 主操作：导出备份（ prominent 胶囊，图标/文字随按钮样式反白）
            Button(action: onExport) {
                Label("导出备份…", systemImage: "tray.and.arrow.up")
            }
            .buttonStyle(.borderedProminent)
            .tint(BrandColors.brandPrimary)

            Button(action: onShare) {
                SettingsRowLabel(title: "通过系统分享…", systemImage: "square.and.arrow.up", color: BrandColors.accessibleGreen)
            }
            .hoverFeedback(reduceMotion: reduceMotion)
            Button(action: onLanSend) {
                SettingsRowLabel(title: "局域网发送…", systemImage: "paperplane", color: BrandColors.accessibleGreen)
            }
            .hoverFeedback(reduceMotion: reduceMotion)
            Button(action: onLanReceive) {
                SettingsRowLabel(title: "局域网接收…", systemImage: "antenna.radiowaves.left.and.right", color: BrandColors.accessibleGreen)
            }
            .hoverFeedback(reduceMotion: reduceMotion)
            Button(action: onImport) {
                SettingsRowLabel(title: "标准导入…", systemImage: "tray.and.arrow.down", color: BrandColors.accessibleGreen)
            }
            .hoverFeedback(reduceMotion: reduceMotion)
            Button(action: onRecoveryImport) {
                SettingsRowLabel(title: "恢复损坏或旧版备份…", systemImage: "bandage", color: BrandColors.accessibleGreen)
            }
            .hoverFeedback(reduceMotion: reduceMotion)
            Text("导出与传输均为明文 JSON，仅在可信设备与网络中使用。")
                .font(Typography.caption)
                .foregroundStyle(.secondary)
            if isBusy {
                HStack(spacing: Spacing.xs) {
                    ProgressView().controlSize(.small)
                    Text("正在处理…")
                        .font(Typography.caption)
                        .foregroundStyle(.secondary)
                }
                .transition(.appear(reduceMotion: reduceMotion))
            }
        }
        .disabled(isBusy)
        .animation(reduceMotion ? Motion.reducedFade(true) : Motion.soft(), value: isBusy)
        .opacity(appeared ? 1 : 0)
        .offset(y: !appeared && !reduceMotion ? 6 : 0)
    }
}

/// 按钮悬停反馈：quick 曲线轻微降不透明度；Reduce Motion 下瞬变
private struct HoverFeedbackModifier: ViewModifier {
    let reduceMotion: Bool
    @State private var hovering = false

    func body(content: Content) -> some View {
        content
            .opacity(hovering ? 0.7 : 1)
            .animation(Motion.quick(reduceMotion), value: hovering)
            .onHover { hovering = $0 }
    }
}

private extension View {
    func hoverFeedback(reduceMotion: Bool) -> some View {
        modifier(HoverFeedbackModifier(reduceMotion: reduceMotion))
    }
}
