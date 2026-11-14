import SwiftUI
import SwiftData
import FlashCore
import FlashDesign

struct PersonalLibraryScreen: View {
    enum Mode { case history, filters, tags, reminders }
    let mode: Mode
    @Environment(\.flashRepository) private var repository
    @Environment(AppState.self) private var appState
    @State private var records: [LibraryRecord] = []
    @State private var library = PersonalLibrary()
    @State private var filter = LibraryFilter()
    @State private var selected: LibraryRecord?
    @State private var recalled: LibraryRecord?
    @State private var error: String?
    @State private var deletingTag: PersonalTag?
    @State private var tagName = ""
    @State private var renamingTag: PersonalTag?
    @State private var name = ""
    var body: some View {
        List {
            if let error { Text(error).foregroundStyle(.red) }
            switch mode {
            case .history: history
            case .filters: filters
            case .tags: tags
            case .reminders: reminders
            }
        }
        .scrollContentBackground(.hidden).flashPageBackground()
        .navigationTitle(title)
        .task(id: repository?.contentRevision ?? 0) {
            reload()
            guard mode != .tags else { return }
            do {
                let kinds: [LibraryKind] = mode == .reminders ? [.idea] : (mode == .history ? [.log,.idea,.emotion,.task] : LibraryKind.allCases)
                let values = try await repository?.readLibraryRecords(kinds:kinds) ?? []
                guard !Task.isCancelled else { return }; records = values
            } catch { self.error = error.localizedDescription }
        }
        .onChange(of: repository?.revision) { reload() }

        .sheet(item: $selected) { record in
            NavigationStack {
                List {
                    Section { Text(record.title).textSelection(.enabled); Text(record.day).foregroundStyle(.secondary) }
                    Section { RecordTagsEditor(recordKey: record.key) }
                    if record.kind == .idea { Section { reminderEditor(record.recordID) } }
                    Button(L("打开原记录")) {
                        selected = nil
                        switch record.kind {
                        case .log,.idea: appState.focusRouter.request(.log(record.recordID))
                        case .emotion: appState.focusRouter.request(.emotion)
                        case .task: appState.focusRouter.request(.task(record.day))
                        }
                    }
                }.navigationTitle(L("记录详情"))
                    .toolbar { Button(L("完成")) { selected = nil } }
            }
        }
        .alert(L("删除自由标签"), isPresented: Binding(get: { deletingTag != nil }, set: { if !$0 { deletingTag = nil } })) {
            Button(L("删除"), role: .destructive) { if let tag = deletingTag { change { $0.deleteTag(tag.id) } }; deletingTag = nil }
            Button(L("取消"), role: .cancel) { deletingTag = nil }
        } message: { Text(L("将移除所有记录关联，并删除引用此标签的保存筛选；记录正文保留。")) }
        .alert(L("重命名"), isPresented: Binding(get: { renamingTag != nil }, set: { if !$0 { renamingTag = nil } })) {
            TextField(L("名称"), text: $name)
            Button(L("保存")) { if let tag = renamingTag { change { value in if let i = value.tags.firstIndex(where: { $0.id == tag.id }) { value.tags[i].name = PersonalTag(name: name).name } } }; renamingTag = nil }
            Button(L("取消"), role: .cancel) { renamingTag = nil }
        }
    }
    private var title: String { switch mode { case .history: L("历史回忆"); case .filters: L("已保存筛选"); case .tags: L("自由标签"); case .reminders: L("灵感周期提醒") } }
    private func row(_ record: LibraryRecord) -> some View {
        Button { selected = record } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(record.title).lineLimit(3).foregroundStyle(.primary)
                Text(record.day).font(.caption).foregroundStyle(.secondary)
            }
        }
    }
    @ViewBuilder private var history: some View {
        Section {
            Toggle(L("展示情绪记录"), isOn: Binding(get: { library.showEmotions }, set: { new in change { $0.showEmotions = new } }))
        }
        recallSection(L("去年的今天"), day: HistoricalRecall.day(before: Date(), years: 1))
        recallSection(L("一个月前"), day: HistoricalRecall.day(before: Date(), months: 1))
        Section(L("抽取收藏")) {
            Button(L("抽取一条收藏")) {
                let candidates = records.filter { $0.favorite && (library.showEmotions || $0.kind != .emotion) }
                recalled = candidates.filter { candidates.count == 1 || $0.key != recalled?.key }.randomElement()
            }
            if let recalled, let current = records.first(where: { $0.key == recalled.key }), library.showEmotions || current.kind != .emotion { row(current) }
            else { Text(L("暂时没有可展示的收藏")).foregroundStyle(.secondary) }
        }
    }
    @ViewBuilder private func recallSection(_ title: String, day: String) -> some View {
        Section(title + " · " + day) {
            let matches = HistoricalRecall.records(records, on: day, showEmotions: library.showEmotions)
            if matches.isEmpty { Text(L("这一天还没有记录")).foregroundStyle(.secondary) }
            ForEach(matches) { row($0) }
        }
    }
    @ViewBuilder private var tags: some View {
        Section {
            HStack { TextField(L("新标签"), text: $tagName); Button(L("添加")) { let tag = PersonalTag(name: tagName); change { $0.tags.append(tag) }; tagName = "" } }
            ForEach(library.tags) { tag in
                HStack {
                    Text(tag.name); Spacer()
                    Button(L("重命名")) { name = tag.name; renamingTag = tag }
                    Button(role: .destructive) { deletingTag = tag } label: { Image(systemName: "trash") }
                }.buttonStyle(.borderless)
            }
        }
    }
    @ViewBuilder private var filters: some View {
        Section(L("已保存筛选")) {
            ForEach(library.filters) { saved in
                Button(saved.name) { filter = saved }
                    .swipeActions { Button(L("删除"), role: .destructive) { change { $0.filters.removeAll { $0.id == saved.id } } } }
            }
        }
        Section(L("筛选条件")) {
            TextField(L("筛选名称"), text: $filter.name)
            TextField(L("关键词"), text: $filter.query)
            ForEach(LibraryKind.allCases, id: \.self) { kind in
                Toggle(kindTitle(kind), isOn: Binding(get: { filter.kinds.contains(kind) }, set: { if $0 { filter.kinds.append(kind) } else { filter.kinds.removeAll { $0 == kind } } }))
            }
            ForEach(library.tags) { tag in
                Toggle(tag.name, isOn: Binding(get: { filter.tagIDs.contains(tag.id) }, set: { if $0 { filter.tagIDs.append(tag.id) } else { filter.tagIDs.removeAll { $0 == tag.id } } }))
            }
            Toggle(L("匹配全部标签"), isOn: $filter.matchAll)
            ForEach(ColorTag.allCases, id: \.self) { color in
                Toggle(color.displayName, isOn: Binding(get: { filter.colors.contains(color.rawValue) }, set: { if $0 { filter.colors.append(color.rawValue) } else { filter.colors.removeAll { $0 == color.rawValue } } }))
            }
            Toggle(L("仅收藏"), isOn: $filter.favoritesOnly)
            TextField(L("起始日期 yyyy-MM-dd"), text: $filter.startDay)
            TextField(L("结束日期 yyyy-MM-dd"), text: $filter.endDay)
            Picker(L("任务状态"), selection: $filter.taskStatus) { Text(L("全部")).tag("all"); Text(L("未完成")).tag("open"); Text(L("已完成")).tag("completed") }
            Toggle(L("最早在前"), isOn: $filter.oldestFirst)
            Button(L("保存筛选")) { change { $0.filters.removeAll { $0.id == filter.id }; $0.filters.append(filter) } }
            Button(L("新建筛选")) { filter = .init() }
        }
        Section(L("筛选结果")) {
            let matches = filter.apply(records, library: library)
            if matches.isEmpty { Text(L("没有匹配的记录")) }
            ForEach(matches) { row($0) }
        }
    }
    @ViewBuilder private var reminders: some View {
        if library.remindersNeedConfirmation {
            Section { Button(L("启用导入的提醒配置")) { change { $0.remindersNeedConfirmation = false } } }
        }
        Section(L("汇总提醒时间")) {
            Toggle(L("灵感汇总提醒"), isOn: Binding(get: { library.summaryEnabled }, set: { value in change { $0.summaryEnabled = value } }))
            Stepper(L("小时") + ": \(library.summaryHour)", value: Binding(get: { library.summaryHour }, set: { value in change { $0.summaryHour = value } }), in: 9...21)
            Stepper(L("分钟") + ": \(library.summaryMinute)", value: Binding(get: { library.summaryMinute }, set: { value in change { $0.summaryMinute = value } }), in: 0...59)
            Picker(L("提醒频率"), selection: Binding(get: { library.summaryIntervalDays }, set: { value in change { $0.summaryIntervalDays = value } })) { frequencies }
            Text(L("每周期最多两次，间隔30分钟；22:00至09:00不提醒。"))
            Text(PeriodicIdeaNotifications.shared.status).font(.caption).foregroundStyle(.secondary)
        }
        Section(L("单条灵感提醒")) { ForEach(records.filter { $0.kind == .idea }) { row($0) } }
    }
    private var frequencies: some View { Group { Text(L("每天")).tag(1); Text(L("每3天")).tag(3); Text(L("每周")).tag(7) } }
    @ViewBuilder private func reminderEditor(_ id: String) -> some View {
        let rule = library.reminders.first { $0.id == id } ?? { var r = PersonalReminder(ideaID: id); r.enabled = false; return r }()
        Toggle(L("周期提醒"), isOn: ruleBinding(id, \.enabled, rule.enabled))
        Picker(L("提醒频率"), selection: ruleBinding(id, \.intervalDays, rule.intervalDays)) { frequencies }
        Stepper(L("小时") + ": \(rule.hour)", value: ruleBinding(id, \.hour, rule.hour), in: 9...21)
        Stepper(L("分钟") + ": \(rule.minute)", value: ruleBinding(id, \.minute, rule.minute), in: 0...59)
        Button(L("本次已梳理")) { PeriodicIdeaNotifications.shared.complete(ideaID: id, repository: repository) }
        Button(L("暂停提醒")) { change { value in if let i = value.reminders.firstIndex(where: { $0.id == id }) { value.reminders[i].enabled = false } } }
    }
    private func ruleBinding<T>(_ id: String, _ key: WritableKeyPath<PersonalReminder,T>, _ fallback: T) -> Binding<T> {
        Binding(get: { (library.reminders.first { $0.id == id })?[keyPath:key] ?? fallback }, set: { new in change { value in
            if let i = value.reminders.firstIndex(where: { $0.id == id }) { value.reminders[i][keyPath:key] = new }
            else { var rule = PersonalReminder(ideaID:id); rule.enabled = false; rule[keyPath:key] = new; value.reminders.append(rule) }
        } })
    }
    private func kindTitle(_ kind: LibraryKind) -> String { switch kind { case .log: L("日志"); case .idea: L("灵感"); case .emotion: L("情绪"); case .task: L("任务") } }
    private func reload() {
        do { library = try repository?.personalLibrary(includeLinks: mode == .filters) ?? .init(); error = nil }
        catch { self.error = (error as? BackupError)?.userMessage ?? error.localizedDescription }
    }
    private func change(_ body: (inout PersonalLibrary) -> Void) {
        do { guard let repository else { return }; var value = try repository.personalLibrary(); body(&value); try repository.savePersonalLibrary(value); reload() }
        catch { self.error = (error as? BackupError)?.userMessage ?? error.localizedDescription }
    }
}
