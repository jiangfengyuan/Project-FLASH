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
    @Query(sort: \LogEntity.createdAt, order: .reverse) private var logEntities: [LogEntity]

    @State private var filter: ExploreFilter = .all
    @State private var draft = ""
    @State private var selectedTag: ColorTag? = nil
    @FocusState private var inputFocused: Bool

    private static let maxLength = 140

    private var filteredLogs: [LogItem] {
        let all = logEntities.map { $0.toModel() }
        switch filter {
        case .all: return all
        case .log: return all.filter { $0.category == .log }
        case .idea: return all.filter { $0.category == .idea }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("筛选", selection: $filter) {
                ForEach(ExploreFilter.allCases, id: \.self) {
                    Text($0.displayName).tag($0)
                }
            }
            .pickerStyle(.segmented)
            .padding(12)

            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(filteredLogs) { log in
                        LogCardView(log: log)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

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
                        .onChange(of: appState.newLogRequestToken) { inputFocused = true }
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
    }

    private func tagButton(_ tag: ColorTag) -> some View {
        let isSelected = selectedTag == tag
        return Button {
            selectedTag = isSelected ? nil : tag
        } label: {
            Circle()
                .fill(BrandColors.tagColor(tag))
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

    private func save() {
        let content = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else { return }
        let asIdea = filter == .idea
        let tag = selectedTag ?? (asIdea ? .idea : .daily)
        do {
            try repository?.addLog(
                content: content,
                colorTag: tag,
                category: asIdea ? .idea : .log,
                importance: asIdea ? importanceFromContent(content) : 0
            )
            draft = ""
            selectedTag = nil
        } catch {
            print("Explore save failed: \(error)")
        }
    }
}
