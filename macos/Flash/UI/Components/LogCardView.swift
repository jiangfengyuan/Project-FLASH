import SwiftUI

/// 日志卡片（Home/LogFlow/Explore/Calendar 复用）。内容层：纯色卡片，无玻璃（spec §10.3）。
/// 传入 onEdit/onDelete 后，hover 浮现操作按钮（LogFlow 场景）；不传则行为与之前一致。
struct LogCardView: View {
    let log: LogItem
    var onEdit: (() -> Void)? = nil
    var onDelete: (() -> Void)? = nil

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hovering = false
    /// 删除确认前的极轻缩放反馈
    @State private var deletePulse = false

    private var hasActions: Bool { onEdit != nil || onDelete != nil }
    private var showActions: Bool { hovering && hasActions }

    /// 时间戳：日期 + HH:mm，灰色小字（createdAt 解析失败时只显日期）
    private var timestamp: String {
        let time = DateFormatting.localTime(fromISO: log.createdAt)
        return time == "--:--" ? log.recordDate : "\(log.recordDate) \(time)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                tagBadge
                if log.importance > 0 {
                    Text(String(repeating: "!", count: log.importance))
                        .font(.caption).bold()
                        .foregroundStyle(ColorTag.urgent.color)
                }
                Spacer()
                Text(timestamp)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                if hasActions {
                    actionButtons
                        .opacity(showActions ? 1 : 0)
                        .animation(Motion.quick(reduceMotion), value: showActions)
                        // 不可见时不拦截点击/右键，保证 contextMenu 与文本选择可用
                        .allowsHitTesting(showActions)
                }
            }
            Text(log.content)
                .font(.body)
                .foregroundStyle(.primary)
                .textSelection(.enabled)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color(nsColor: .separatorColor), lineWidth: 0.5)
        }
        .scaleEffect(deletePulse ? 0.97 : 1)
        .cardFloat(reduceMotion: reduceMotion)
        .onHover { hovering = $0 }
    }

    /// 标签徽章：标签色淡底胶囊，替代原先的色点+灰字
    private var tagBadge: some View {
        Text(log.colorTag.displayName)
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(log.colorTag.color.opacity(0.15), in: Capsule())
            .foregroundStyle(log.colorTag.color)
    }

    private var actionButtons: some View {
        HStack(spacing: 2) {
            if let onEdit {
                Button(action: onEdit) {
                    Image(systemName: "pencil")
                        .frame(width: 20, height: 20)
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
                        .frame(width: 20, height: 20)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("删除")
                .accessibilityLabel("删除")
            }
        }
        .font(.caption)
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
