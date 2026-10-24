// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import SwiftUI
import FlashCore

/// 日志卡片（Home/LogFlow/Explore/Calendar 复用）。内容层：纯色卡片，无玻璃（spec §10.3）。
/// 传入 onEdit/onDelete 后，hover 浮现操作按钮（LogFlow 场景）；不传则行为与之前一致。
/// 触屏（iOS）无 hover：传 `actionsVisibility: .hidden`，操作改由调用方的轻扫/长按菜单承载。
public struct LogCardView: View {
    /// 卡内操作按钮的显示策略
    public enum ActionsVisibility: Sendable {
        /// 指针悬停时浮现（macOS 默认）
        case onHover
        /// 常显
        case always
        /// 不渲染（触屏改用轻扫操作与上下文菜单）
        case hidden
    }

    public let log: LogItem
    public var onEdit: (() -> Void)? = nil
    public var onDelete: (() -> Void)? = nil
    /// 收藏切换（nil 时不渲染星标按钮；已收藏星标常显不受此影响）
    public var onToggleFavorite: (() -> Void)? = nil
    public var actionsVisibility: ActionsVisibility = .onHover
    /// 灵感提醒：未查看过的灵感在徽章旁标「未读」（默认关，macOS 不变）
    public var isUnread: Bool = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hovering = false
    /// 删除确认前的极轻缩放反馈
    @State private var deletePulse = false
    /// hover 浮现操作按钮的命中框：固定基准 28，随系统字体档位缩放（图标框场景）
    @ScaledMetric(relativeTo: .body) private var actionButtonSize = 28

    private var isFavorite: Bool { log.isFavorite == true }
    private var hasActions: Bool {
        actionsVisibility != .hidden && (onEdit != nil || onDelete != nil || onToggleFavorite != nil)
    }
    private var showActions: Bool {
        switch actionsVisibility {
        case .onHover: hovering && hasActions
        case .always: hasActions
        case .hidden: false
        }
    }

    /// 时间戳：日期 + HH:mm，灰色小字（createdAt 解析失败时只显日期）
    private var timestamp: String {
        let time = DateFormatting.localTime(fromISO: log.createdAt)
        return time == "--:--" ? log.recordDate : "\(log.recordDate) \(time)"
    }

    public init(log: LogItem, onEdit: (() -> Void)? = nil, onDelete: (() -> Void)? = nil,
                onToggleFavorite: (() -> Void)? = nil,
                actionsVisibility: ActionsVisibility = .onHover,
                isUnread: Bool = false) {
        self.log = log
        self.onEdit = onEdit
        self.onDelete = onDelete
        self.onToggleFavorite = onToggleFavorite
        self.actionsVisibility = actionsVisibility
        self.isUnread = isUnread
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) { // 10：徽章行与正文的紧凑节奏（无对应令牌）
            // 一行放不下（辅助功能大字号）时时间戳换到徽章下方，不在数字中间折行
            ViewThatFits(in: .horizontal) {
                HStack(spacing: Spacing.xs) {
                    badges
                    Spacer()
                    favoriteMark
                    timestampText
                    actionsOverlay
                }
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    HStack(spacing: Spacing.xs) {
                        badges
                        Spacer()
                        favoriteMark
                        actionsOverlay
                    }
                    timestampText
                }
            }
            Text(log.content)
                .font(Typography.body)
                .foregroundStyle(.primary)
                .textSelection(.enabled)
        }
        .padding(14) // 卡片内边距：sm 与 md 之间的特调值
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(BrandColors.cardSurface)
        .clipShape(RoundedRectangle(cornerRadius: Radius.row))
        .overlay {
            RoundedRectangle(cornerRadius: Radius.row)
                .stroke(BrandColors.weakBorder, lineWidth: 0.5)
        }
        .scaleEffect(deletePulse ? 0.97 : 1)
        .cardFloat(reduceMotion: reduceMotion)
        .onHover { hovering = $0 }
    }

    @ViewBuilder
    private var badges: some View {
        tagBadge
        if isUnread {
            Text("未读")
                .font(Typography.caption).bold()
                .foregroundStyle(BrandColors.ideaYellowText)
                .accessibilityLabel("未读灵感")
        }
        if log.importance > 0 {
            Text(String(repeating: "!", count: log.importance))
                .font(Typography.caption).bold()
                .foregroundStyle(ColorTag.urgent.textColor)
        }
    }

    /// 已收藏星标常显（金色可读变体，深浅色均达标）；未收藏时星标按钮随 hover 浮现
    @ViewBuilder
    private var favoriteMark: some View {
        if isFavorite {
            Image(systemName: "star.fill")
                .font(Typography.caption)
                .foregroundStyle(BrandColors.ideaYellowText)
                .accessibilityLabel("已收藏")
        }
    }

    private var timestampText: some View {
        Text(timestamp)
            .font(Typography.caption)
            .foregroundStyle(.secondary)
            .fixedSize()
    }

    @ViewBuilder
    private var actionsOverlay: some View {
        if hasActions {
            actionButtons
                .opacity(showActions ? 1 : 0)
                .animation(Motion.quick(reduceMotion), value: showActions)
                // 不可见时不拦截点击/右键，保证 contextMenu 与文本选择可用
                .allowsHitTesting(showActions)
        }
    }

    /// 标签徽章：标签色淡底胶囊，替代原先的色点+灰字。
    /// 文案用 textColor（同色系加深变体），浅色模式下达到正文对比度
    private var tagBadge: some View {
        Text(log.colorTag.displayName)
            .font(Typography.caption)
            .padding(.horizontal, Spacing.xs)
            .padding(.vertical, 2) // 徽章纵向内距：极小特调值
            .background(log.colorTag.color.opacity(0.15), in: Capsule())
            .foregroundStyle(log.colorTag.textColor)
    }

    private var actionButtons: some View {
        HStack(spacing: 2) { // 2：相邻图标按钮的极小间距
            if let onToggleFavorite {
                Button(action: onToggleFavorite) {
                    Image(systemName: isFavorite ? "star.fill" : "star")
                        .frame(width: actionButtonSize, height: actionButtonSize)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(isFavorite ? BrandColors.ideaYellowText : .secondary)
                .help(isFavorite ? "取消收藏" : "收藏")
                .accessibilityLabel(isFavorite ? "取消收藏" : "收藏")
            }
            if let onEdit {
                Button(action: onEdit) {
                    Image(systemName: "pencil")
                        .frame(width: actionButtonSize, height: actionButtonSize)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("编辑")
                .accessibilityLabel("编辑")
            }
            if onDelete != nil {
                Button(action: deleteTapped) {
                    Image(systemName: "trash")
                        .frame(width: actionButtonSize, height: actionButtonSize)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("删除")
                .accessibilityLabel("删除")
            }
        }
        .font(Typography.caption)
    }

    /// 点删除：卡片先做一个极轻缩放脉冲（Motion.bounce），同时立刻触发确认流程，不阻塞
    private func deleteTapped() {
        guard let onDelete else { return }
        Motion.animate(Motion.bounce(), reduceMotion: reduceMotion) { deletePulse = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            Motion.animate(Motion.soft(), reduceMotion: reduceMotion) { deletePulse = false }
        }
        onDelete()
    }
}
