import SwiftUI
import SwiftData

/// 情绪页：七级情绪记录（对齐 Android EmotionViewModel）
struct EmotionView: View {
    @Environment(\.flashRepository) private var repository
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var sliderValue: Double = 5 // 1...7 → veryUnhappy...slightlyHappy 默认
    @State private var selectedSubEmotion: SubEmotion? = nil
    @State private var note = ""
    @State private var errorMessage: String? = nil

    private var selectedLevel: EmotionLevel {
        EmotionLevel.allCases[Int(sliderValue) - 1]
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // 当前情绪
                VStack(spacing: 12) {
                    Text(selectedLevel.emoji)
                        .font(.system(size: 72))
                        .id(selectedLevel)
                        .transition(emojiTransition)
                    Text(selectedLevel.displayName)
                        .font(.title3)
                        .foregroundStyle(selectedLevel.color)

                    Slider(value: $sliderValue, in: 1...7, step: 1) {
                        Text("情绪等级")
                    } minimumValueLabel: {
                        Text("😡")
                    } maximumValueLabel: {
                        Text("😍")
                    }
                    .frame(maxWidth: 420)
                    .onChange(of: sliderValue) {
                        if !selectedLevel.isNegative { selectedSubEmotion = nil }
                    }
                    .accessibilityValue(selectedLevel.displayName)
                }
                .padding(.top, 24)

                // 子情绪（仅负面）
                if selectedLevel.isNegative {
                    HStack(spacing: 10) {
                        ForEach(SubEmotion.allCases, id: \.self) { sub in
                            subEmotionChip(sub)
                        }
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                }

                // 备注 + 保存
                VStack(spacing: 10) {
                    TextField("想说点什么？（可选）", text: $note)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 420)
                    Button("记录情绪") { save() }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                }

                Divider().padding(.vertical, 8)

                // 历史（独立子视图，拖动滑杆不触发其重建）
                EmotionHistoryView()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(24)
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: selectedLevel)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .alert("提示", isPresented: errorPresented) {
            Button("好") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    /// 情绪 emoji 切换：轻微缩放 + 淡入淡出；减弱动态时仅淡入淡出
    private var emojiTransition: AnyTransition {
        reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.9))
    }

    private func subEmotionChip(_ sub: SubEmotion) -> some View {
        let isOn = selectedSubEmotion == sub
        return Button {
            selectedSubEmotion = isOn ? nil : sub
        } label: {
            Text(sub.displayName)
                .font(.callout)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(isOn ? sub.color.opacity(0.3)
                                 : Color(nsColor: .controlBackgroundColor))
                .clipShape(Capsule())
                .overlay {
                    Capsule().stroke(isOn ? sub.color
                                          : Color(nsColor: .separatorColor),
                                     lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
    }

    private var errorPresented: Binding<Bool> {
        Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
    }

    private func save() {
        let level = selectedLevel
        let sub = level.isNegative ? selectedSubEmotion : nil
        let noteValue = note.isEmpty ? nil : note
        do {
            try repository?.addEmotion(level: level, subEmotion: sub, note: noteValue)
            note = ""
            selectedSubEmotion = nil
        } catch {
            // 固定文案，详情仅输出到控制台，避免向用户暴露内部路径
            print("[EmotionView] 保存情绪记录失败: \(error)")
            errorMessage = "保存失败，请重试"
        }
    }
}

/// 近期情绪记录：自带 @Query（按创建时间倒序、限 20 条），与父视图滑杆/输入状态隔离
private struct EmotionHistoryView: View {
    @Environment(\.flashRepository) private var repository
    @Query private var emotionEntities: [EmotionEntity]

    @State private var deletingRecord: EmotionRecord? = nil
    @State private var errorMessage: String? = nil

    init() {
        var descriptor = FetchDescriptor<EmotionEntity>(
            sortBy: [SortDescriptor(\EmotionEntity.createdAt, order: .reverse)]
        )
        descriptor.fetchLimit = 20
        _emotionEntities = Query(descriptor)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("近期记录").font(.headline)
            if emotionEntities.isEmpty {
                Text("还没有情绪记录，从上方开始吧")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(emotionEntities.map { $0.toModel() }) { record in
                    emotionRow(record)
                }
            }
        }
        .alert("删除这条情绪记录？", isPresented: deletePresented) {
            Button("删除", role: .destructive) {
                if let record = deletingRecord {
                    do { try repository?.deleteEmotion(id: record.id) }
                    catch {
                        print("[EmotionHistoryView] 删除情绪记录失败: \(error)")
                        errorMessage = "删除失败，请重试"
                    }
                }
            }
            Button("取消", role: .cancel) {}
        }
        .alert("提示", isPresented: errorPresented) {
            Button("好") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func emotionRow(_ record: EmotionRecord) -> some View {
        HStack(spacing: 10) {
            Text(record.level.emoji).font(.title3)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(record.level.displayName).font(.callout)
                    if let sub = record.subEmotion {
                        Text(sub.displayName)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(sub.color.opacity(0.25))
                            .clipShape(Capsule())
                    }
                }
                if let note = record.note, !note.isEmpty {
                    Text(note).font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            Text(record.recordDate).font(.caption).foregroundStyle(.tertiary)
        }
        .padding(10)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .contextMenu {
            Button("删除", role: .destructive) { deletingRecord = record }
        }
    }

    private var deletePresented: Binding<Bool> {
        Binding(get: { deletingRecord != nil }, set: { if !$0 { deletingRecord = nil } })
    }

    private var errorPresented: Binding<Bool> {
        Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
    }
}
