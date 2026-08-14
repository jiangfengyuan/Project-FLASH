import SwiftUI
import SwiftData

/// 记录流：搜索 + 标签/日期/排序筛选 + 编辑删除（对齐 Android LogFlowViewModel）
struct LogFlowView: View {
    @Environment(\.flashRepository) private var repository
    @Query(sort: \LogEntity.createdAt, order: .reverse) private var logEntities: [LogEntity]

    @State private var filter = LogFilter()
    @State private var editingLog: LogItem? = nil
    @State private var deletingLog: LogItem? = nil
    @State private var errorMessage: String? = nil

    private var filteredLogs: [LogItem] {
        filter.apply(to: logEntities.map { $0.toModel() })
    }

    var body: some View {
        VStack(spacing: 0) {
            // 工具区
            VStack(spacing: 10) {
                HStack(spacing: 8) {
                    ForEach(ColorTag.allCases, id: \.self) { tag in
                        tagChip(tag)
                    }
                    Spacer()
                    Picker("排序", selection: $filter.sort) {
                        ForEach(LogSort.allCases, id: \.self) {
                            Text($0.displayName).tag($0)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 110)
                }
                HStack(spacing: 8) {
                    DatePicker("开始", selection: startBinding, displayedComponents: .date)
                        .labelsHidden()
                        .opacity(filter.startDate == nil ? 0.45 : 1)
                    Text("至").foregroundStyle(.secondary)
                    DatePicker("结束", selection: endBinding, displayedComponents: .date)
                        .labelsHidden()
                        .opacity(filter.endDate == nil ? 0.45 : 1)
                    if filter.startDate != nil || filter.endDate != nil {
                        Button("清除日期") {
                            filter.startDate = nil
                            filter.endDate = nil
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(Color(nsColor: .controlAccentColor))
                    }
                    Spacer()
                }
                .font(.caption)
            }
            .padding(12)

            Divider()

            if filteredLogs.isEmpty {
                ContentUnavailableView("没有匹配的记录",
                                       systemImage: "magnifyingglass",
                                       description: Text("调整筛选条件试试"))
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(filteredLogs) { log in
                            LogCardView(log: log)
                                .contextMenu {
                                    Button("编辑…") { editingLog = log }
                                    Button("删除", role: .destructive) { deletingLog = log }
                                }
                        }
                    }
                    .padding(16)
                }
            }
        }
        .searchable(text: $filter.query, placement: .toolbar, prompt: "搜索记录内容")
        .sheet(item: $editingLog) { log in
            LogEditSheet(log: log) { updated in
                do { try repository?.updateLog(updated) }
                catch { errorMessage = "保存失败：\(error.localizedDescription)" }
            }
        }
        .alert("删除这条记录？", isPresented: deletePresented) {
            Button("删除", role: .destructive) {
                if let log = deletingLog {
                    do { try repository?.deleteLog(id: log.id) }
                    catch { errorMessage = "删除失败：\(error.localizedDescription)" }
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

    // 日期桥接：filter 存 yyyy-MM-dd 字符串（对齐 Web/Android），DatePicker 用 Date
    private var startBinding: Binding<Date> {
        Binding(
            get: { filter.startDate.flatMap(DateFormatting.parseDay) ?? Date() },
            set: { filter.startDate = DateFormatting.dayString($0) }
        )
    }

    private var endBinding: Binding<Date> {
        Binding(
            get: { filter.endDate.flatMap(DateFormatting.parseDay) ?? Date() },
            set: { filter.endDate = DateFormatting.dayString($0) }
        )
    }

    private var deletePresented: Binding<Bool> {
        Binding(get: { deletingLog != nil }, set: { if !$0 { deletingLog = nil } })
    }

    private var errorPresented: Binding<Bool> {
        Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
    }

    private func tagChip(_ tag: ColorTag) -> some View {
        let isOn = filter.tags.contains(tag)
        return Button {
            if isOn { filter.tags.remove(tag) } else { filter.tags.insert(tag) }
        } label: {
            Text(tag.displayName)
                .font(.caption)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(isOn ? BrandColors.tagColor(tag).opacity(0.25)
                                 : Color(nsColor: .controlBackgroundColor))
                .foregroundStyle(.primary)
                .clipShape(Capsule())
                .overlay {
                    Capsule().stroke(isOn ? BrandColors.tagColor(tag)
                                          : Color(nsColor: .separatorColor),
                                     lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
    }
}
