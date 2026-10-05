// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import SwiftUI

/// 「数据与安全」分组：系统分享 / 局域网收发 / 导出 / 标准与恢复导入。
/// 各动作通过闭包抛回 SettingsView（导出/导入状态机、LAN 控制器均由其持有）。
struct DataSafetySection: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// 导入/导出进行中（期间禁用整组并显示进度行）
    let isBusy: Bool
    /// 分组入场标记（stagger 淡入上移），由 SettingsView 驱动
    let appeared: Bool
    let onShare: () -> Void
    let onLanSend: () -> Void
    let onLanReceive: () -> Void
    let onExport: () -> Void
    let onImport: () -> Void
    let onRecoveryImport: () -> Void

    var body: some View {
        Section("数据与安全") {
            Button(action: onShare) {
                SettingsRowLabel(title: "通过系统分享…", systemImage: "square.and.arrow.up", color: BrandColors.accessibleGreen)
            }
            .hoverFeedback(reduceMotion: reduceMotion)
            Button(action: onLanSend) {
                SettingsRowLabel(title: "局域网发送…", systemImage: "paperplane", color: BrandColors.accessibleGreen)
            }
            Button(action: onLanReceive) {
                SettingsRowLabel(title: "局域网接收…", systemImage: "antenna.radiowaves.left.and.right", color: BrandColors.accessibleGreen)
            }
            Button(action: onExport) {
                SettingsRowLabel(title: "导出备份…", systemImage: "tray.and.arrow.up", color: BrandColors.accessibleGreen)
            }
            .hoverFeedback(reduceMotion: reduceMotion)
            Button(action: onImport) {
                SettingsRowLabel(title: "标准导入…", systemImage: "tray.and.arrow.down", color: BrandColors.accessibleGreen)
            }
            Button(action: onRecoveryImport) {
                SettingsRowLabel(title: "恢复损坏或旧版备份…", systemImage: "bandage", color: BrandColors.accessibleGreen)
            }
            .hoverFeedback(reduceMotion: reduceMotion)
            Text("通过系统分享传输明文 JSON；可选择 AirDrop、信息、邮件或云盘。")
                .font(.caption)
                .foregroundStyle(.secondary)
            if isBusy {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("正在处理…")
                        .font(.caption)
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
