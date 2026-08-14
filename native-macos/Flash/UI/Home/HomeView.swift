import SwiftUI
import SwiftData

/// 首页：今日概览 + 快速记录 + 最近 5 条（对齐 Android HomeViewModel）
struct HomeView: View {
    @Environment(\.flashRepository) private var repository
    @Environment(AppState.self) private var appState
    @Query(sort: \LogEntity.createdAt, order: .reverse) private var logEntities: [LogEntity]
    @Query(sort: \EmotionEntity.createdAt, order: .reverse) private var emotionEntities: [EmotionEntity]

    @State private var draft = ""
    @FocusState private var inputFocused: Bool
    @State private var errorMessage: String? = nil

    private var logs: [LogItem] { logEntities.map { $0.toModel() } }
    private var emotions: [EmotionRecord] { emotionEntities.map { $0.toModel() } }

    private var today: String { DateFormatting.today() }
    private var todayLogs: [LogItem] { logs.filter { $0.recordDate == today && $0.category == .log } }
    private var todayIdeas: [LogItem] { logs.filter { $0.recordDate == today && $0.category == .idea } }
    private var todayEmotions: [EmotionRecord] { emotions.filter { $0.recordDate == today } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // 今日概览
                HStack(spacing: 12) {
                    statCard(title: "今日日志", count: todayLogs.count, icon: "note.text")
                    statCard(title: "今日灵感", count: todayIdeas.count, icon: "lightbulb")
                    statCard(title: "今日情绪", count: todayEmotions.count, icon: "face.smiling")
                }

                if let latest = emotions.first {
                    Label("\(latest.level.emoji) \(latest.level.displayName)",
                          systemImage: "clock")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                // 快速记录
                VStack(alignment: .leading, spacing: 8) {
                    TextField("此刻的想法…", text: $draft, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(1...4)
                        .focused($inputFocused)
                        .onChange(of: appState.newLogRequestToken) { inputFocused = true }
                    HStack {
                        Button("记为日志") { quickAdd(as: .log) }
                            .buttonStyle(.borderedProminent)
                            .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        Button("记为灵感") { quickAdd(as: .idea) }
                            .buttonStyle(.bordered)
                            .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }

                // 最近 5 条
                Text("最近记录")
                    .font(.headline)
                LazyVStack(spacing: 8) {
                    ForEach(logs.prefix(5)) { log in
                        LogCardView(log: log)
                    }
                }
            }
            .padding(24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
        .alert("提示", isPresented: errorPresented) {
            Button("好") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func statCard(title: String, count: Int, icon: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(Color(nsColor: .controlAccentColor))
            Text("\(count)").font(.title2).bold()
            Text(title).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var errorPresented: Binding<Bool> {
        Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
    }

    private func quickAdd(as category: Category) {
        let content = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else { return }
        do {
            switch category {
            case .log:
                try repository?.addLog(content: content, colorTag: .daily, category: .log)
            case .idea:
                try repository?.addLog(content: content, colorTag: .idea, category: .idea,
                                       importance: importanceFromContent(content))
            }
            draft = ""
        } catch {
            errorMessage = "保存失败：\(error.localizedDescription)"
        }
    }
}
