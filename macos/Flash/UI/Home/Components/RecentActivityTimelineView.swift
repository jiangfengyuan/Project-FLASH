import SwiftUI

/// 「最近动态」时间线卡片：按时间倒序展示各模块的最新活动。
/// 纯展示型组件，数据由外部传入；条目模型见 `ActivityEntry`（HomeModels.swift）。
struct RecentActivityTimelineView: View {
    let entries: [ActivityEntry]
    /// 卡片标题（搜索时外部传「搜索结果」）
    let title: String
    /// 空列表占位文案（搜索无结果时外部传「没有找到相关记录。」）
    let emptyMessage: String
    let onViewAll: () -> Void

    init(entries: [ActivityEntry],
         title: String = "最近动态",
         emptyMessage: String = "今天还没有故事。",
         onViewAll: @escaping () -> Void = {}) {
        self.entries = entries
        self.title = title
        self.emptyMessage = emptyMessage
        self.onViewAll = onViewAll
    }

    @State private var isViewAllHovering = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                header
                if entries.isEmpty {
                    emptyState
                        .transition(.appear(reduceMotion: reduceMotion))
                } else {
                    timeline
                        .transition(.appear(reduceMotion: reduceMotion))
                }
            }
            .padding(16)
        }
    }

    // MARK: - 顶部标题栏

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.caption.weight(.semibold))
                .tracking(0.8)
                .foregroundStyle(Color.secondary)
            Spacer()
            Button("查看全部", action: onViewAll)
                .buttonStyle(.plain)
                .font(.caption)
                .foregroundStyle(BrandColors.accent.opacity(isViewAllHovering ? 0.7 : 1))
                .onHover { isViewAllHovering = $0 }
                .animation(Motion.quick(reduceMotion), value: isViewAllHovering)
                .help("查看全部记录")
        }
    }

    // MARK: - 空状态

    /// 空状态：品牌化文案由外部传入（PRD §34，如「今天还没有故事。」），
    /// .appear 过渡在父级动画事务（HomeView 的 Motion.soft）中生效
    private var emptyState: some View {
        Text(emptyMessage)
            .font(.subheadline)
            .foregroundStyle(Color.secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 32)
    }

    // MARK: - 时间线

    private var timeline: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                row(entry, isLast: index == entries.count - 1)
            }
        }
    }

    private func row(_ entry: ActivityEntry, isLast: Bool) -> some View {
        let moduleColor = BrandColors.moduleColor(entry.module)
        return HStack(alignment: .top, spacing: 12) {
            // 时间（等宽数字，右对齐）
            Text(entry.time)
                .font(.caption.monospacedDigit())
                .foregroundStyle(Color.secondary)
                .frame(width: 38, alignment: .trailing)
                .padding(.top, 8)

            // 圆点 + 连接线（连接线贯穿整行高度，行间无缝衔接）
            ZStack(alignment: .top) {
                Rectangle()
                    .fill(Color.secondary.opacity(isLast ? 0 : 0.25))
                    .frame(width: 1)
                Circle()
                    .fill(moduleColor)
                    .frame(width: 8, height: 8)
                    .padding(.top, 10)
            }
            .frame(width: 8)

            // 模块 + 内容
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Image(systemName: Self.moduleIcon(entry.module))
                        .font(.caption)
                    Text(Self.moduleName(entry.module))
                        .font(.caption)
                }
                .foregroundStyle(moduleColor)

                Text(entry.title)
                    .font(.subheadline)
                    .foregroundStyle(Color.primary)
                    .lineLimit(2)
                    .truncationMode(.tail)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, 6)

            Spacer(minLength: 8)

            // 可选标签
            if let tag = entry.tag {
                Text(tag)
                    .font(.caption)
                    .foregroundStyle(Color.secondary)
                    .padding(.top, 8)
            }
        }
        .cardFloat(reduceMotion: reduceMotion)
    }

    // MARK: - 模块映射

    private static func moduleIcon(_ module: HomeModule) -> String {
        switch module {
        case .log: return "note.text"
        case .idea: return "lightbulb"
        case .task: return "checkmark.circle"
        case .emotion: return "face.smiling"
        }
    }

    private static func moduleName(_ module: HomeModule) -> String {
        switch module {
        case .log: return "日志"
        case .idea: return "灵感"
        case .task: return "任务"
        case .emotion: return "情绪"
        }
    }
}

#Preview {
    VStack(spacing: 24) {
        RecentActivityTimelineView(
            entries: [
                ActivityEntry(id: "1", time: "09:12", module: .log,
                              title: "晨间咖啡与一段很喜欢的播客，记下了关于「慢决策」的三个要点", tag: "#生活"),
                ActivityEntry(id: "2", time: "11:40", module: .idea,
                              title: "给 Flash 加一个「随机回顾」功能", tag: "#工作"),
                ActivityEntry(id: "3", time: "14:05", module: .task,
                              title: "完成设计稿评审", tag: nil),
                ActivityEntry(id: "4", time: "21:30", module: .emotion,
                              title: "平静，略带一点疲惫", tag: "#晚间"),
            ],
            onViewAll: {}
        )

        RecentActivityTimelineView(entries: [])
    }
    .padding(24)
    .frame(width: 420)
}
