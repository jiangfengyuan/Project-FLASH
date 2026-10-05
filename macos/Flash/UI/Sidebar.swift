// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import SwiftUI

/// 侧栏：三组分区（HOME 此刻 / RECORD 记录·日志流·日历·情绪 / INSIGHTS 回顾）+
/// 底部常驻「设置」（分隔线隔离，不随分组滚动；选中态与导航行一致）。
/// 选中胶囊用 matchedGeometryEffect 随 Motion.spring 平滑滑动；hover 行高亮走
/// Motion.quick；选中图标极轻 bounce。所有动效尊重 Reduce Motion。
struct Sidebar: View {
    @Environment(AppState.self) private var appState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var selectionNamespace

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 2) { // 行间距 2：紧凑清单节奏，无对应令牌
                    sectionHeader("HOME")
                    row(.home)

                    Spacer().frame(height: Spacing.md)

                    sectionHeader("RECORD")
                    row(.explore)
                    row(.logflow)
                    row(.calendar)
                    row(.emotion)

                    Spacer().frame(height: Spacing.md)

                    sectionHeader("INSIGHTS")
                    row(.stats)
                }
                .padding(Spacing.xs)
            }

            Divider()

            // 设置固定底部：与导航行同一 SidebarRow/命名空间，选中胶囊可滑入
            row(.settings)
                .padding(Spacing.xs)
        }
        .navigationTitle("Flash")
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(Typography.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, Spacing.xs)
            .padding(.bottom, Spacing.xxs)
    }

    private func row(_ module: Module) -> some View {
        SidebarRow(
            module: module,
            isSelected: appState.selectedModule == module,
            selectionNamespace: selectionNamespace,
            reduceMotion: reduceMotion
        ) {
            Motion.animate(Motion.spring(), reduceMotion: reduceMotion) {
                appState.selectedModule = module
            }
        }
    }
}

/// 侧栏行：图标 + 标题；选中时胶囊背景（跟随 accent 色）与图标 bounce，hover 时轻高亮。
/// 字号走相对 TextStyle（标题 .body）；图标基准 14pt、图标列宽 20 随系统字体档位缩放。
private struct SidebarRow: View {
    let module: Module
    let isSelected: Bool
    let selectionNamespace: Namespace.ID
    let reduceMotion: Bool
    let onSelect: () -> Void

    @State private var hovering = false
    /// 图标列宽：固定基准 20，随字体档位缩放（图标框场景）
    @ScaledMetric(relativeTo: .body) private var iconColumnWidth = 20

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: Spacing.xs) {
                Image(systemName: module.systemImage)
                    .scaledSystemFont(size: 14, relativeTo: .body)
                    .frame(width: iconColumnWidth, alignment: .center)
                    // 选中图标极轻 bounce（减弱动态时关闭）
                    .scaleEffect(isSelected && !reduceMotion ? 1.06 : 1)
                    .animation(Motion.bounce(reduceMotion), value: isSelected)
                Text(module.title)
                    .font(Typography.body)
                Spacer()
            }
            .foregroundStyle(isSelected ? Color.white : .primary)
            .padding(.horizontal, Spacing.xs)
            .padding(.vertical, 5) // 行高紧凑：5 为侧栏行垂直内距特调值（xxs 偏扁、xs 偏高）
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: Radius.control, style: .continuous)
                        .fill(BrandColors.accent)
                        .matchedGeometryEffect(id: "selection", in: selectionNamespace)
                } else {
                    RoundedRectangle(cornerRadius: Radius.control, style: .continuous)
                        .fill(Color.primary.opacity(hovering ? 0.07 : 0))
                }
            }
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .animation(Motion.quick(reduceMotion), value: hovering)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}
