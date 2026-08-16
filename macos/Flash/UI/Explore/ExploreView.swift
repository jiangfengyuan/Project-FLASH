import SwiftUI
import SwiftData

enum ExploreFilter: String, CaseIterable {
    case all, log, idea

    var displayName: String {
        switch self {
        case .all: "全部"
        case .log: "日志"
        case .idea: "灵感"
        }
    }
}

/// 探索页：统一信息流（日志+灵感），模块筛选 + 底部快速输入
struct ExploreView: View {
    @Environment(\.flashRepository) private var repository
    @Environment(AppState.self) private var appState

    @State private var filter: ExploreFilter = .all
    @State private var draft = ""
    @State private var selectedTag: ColorTag? = nil
    @State private var errorMessage: String? = nil
    @State private var handledNewLogToken = 0
    @FocusState private var inputFocused: Bool

    private static let maxLength = 140

    var body: some View {
        VStack(spacing: 0) {
            Picker("筛选", selection: $filter) {
                ForEach(ExploreFilter.allCases, id: \.self) {
                    Text($0.displayName).tag($0)
                }
            }
            .pickerStyle(.segmented)
            .padding(12)

            ExploreLogListView(filter: filter)
                // 筛选切换时强制重建列表查询（@Query 谓词初始化后不随新实例更新）
                .id(filter)

            Divider()

            // 底部快速输入
            VStack(spacing: 8) {
                HStack(spacing: 6) {
                    ForEach(ColorTag.allCases, id: \.self) { tag in
                        tagButton(tag)
                    }
                    Spacer()
                    Text("\(draft.count)/\(Self.maxLength)")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                HStack(alignment: .bottom, spacing: 8) {
                    TextField(filter == .idea ? "记录灵感（!! 标记重要度）…" : "记录此刻…",
                              text: $draft, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(1...3)
                        .focused($inputFocused)
                        .onAppear { flushNewLogRequest() }
                        .onChange(of: appState.newLogRequestToken) { flushNewLogRequest() }
                        .onChange(of: draft) {
                            if draft.count > Self.maxLength {
                                draft = String(draft.prefix(Self.maxLength))
                            }
                        }
                    Button("发送") { save() }
                        .buttonStyle(.borderedProminent)
                        .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .keyboardShortcut(.return, modifiers: .command)
                }
            }
            .padding(12)
            .background(Color(nsColor: .controlBackgroundColor))
        }
        .alert("提示", isPresented: errorPresented) {
            Button("好") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func tagButton(_ tag: ColorTag) -> some View {
        let isSelected = selectedTag == tag
        return Button {
            selectedTag = isSelected ? nil : tag
        } label: {
            Circle()
                .fill(tag.color)
                .frame(width: 18, height: 18)
                .overlay {
                    if isSelected {
                        Circle().stroke(Color.primary, lineWidth: 2)
                    }
                }
        }
        .buttonStyle(.plain)
        .help(tag.displayName)
        .accessibilityLabel(tag.displayName)
    }

    private var errorPresented: Binding<Bool> {
        Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
    }

    /// 菜单「新建记录」⌘N：token 递增时聚焦输入框。
    /// onAppear 兜底：跨模块命令使本视图首次创建时 token 已递增，onChange 不会回放。
    private func flushNewLogRequest() {
        guard appState.newLogRequestToken != handledNewLogToken else { return }
        handledNewLogToken = appState.newLogRequestToken
        inputFocused = true
    }

    private func save() {
        let content = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else { return }
        guard let repository else { errorMessage = "内部错误：存储未就绪"; return }
        let asIdea = filter == .idea
        let tag = selectedTag ?? (asIdea ? .idea : .daily)
        do {
            try repository.addLog(
                content: content,
                colorTag: tag,
                category: asIdea ? .idea : .log,
                importance: asIdea ? importanceFromContent(content) : 0
            )
            draft = ""
            selectedTag = nil
        } catch {
            // 固定文案，详情仅输出到控制台，避免向用户暴露内部路径
            print("[ExploreView] 保存记录失败: \(error)")
            errorMessage = "保存失败，请重试"
        }
    }
}

/// 信息流列表：自带 @Query（静态 category 谓词），与底部输入框的 draft 状态隔离，
/// 每敲一键不再触发全量 map。
private struct ExploreLogListView: View {
    @Query private var logEntities: [LogEntity]

    init(filter: ExploreFilter) {
        switch filter {
        case .all:
            _logEntities = Query(sort: \LogEntity.createdAt, order: .reverse)
        case .log:
            let category = Category.log.rawValue
            _logEntities = Query(filter: #Predicate<LogEntity> { $0.category == category },
                                 sort: \LogEntity.createdAt, order: .reverse)
        case .idea:
            let category = Category.idea.rawValue
            _logEntities = Query(filter: #Predicate<LogEntity> { $0.category == category },
                                 sort: \LogEntity.createdAt, order: .reverse)
        }
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(logEntities.map { $0.toModel() }) { log in
                    LogCardView(log: log)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
