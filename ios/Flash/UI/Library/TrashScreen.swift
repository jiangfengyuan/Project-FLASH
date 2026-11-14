import FlashCore
import FlashDesign
import SwiftUI

struct TrashScreen: View {
  @Environment(\.flashRepository) private var repository
  @State private var items: [TrashItem] = []
  @State private var selected: Set<String> = []
  @State private var preferences = LibraryPreferences()
  @State private var days = 30
  @State private var forever = false
  @State private var confirmation: String?
  @State private var error: String?
  @State private var preview: TrashItem?
  var body: some View {
    List {
      if let error { Text(error).foregroundStyle(.red) }
      Section(L("自动清理")) {
        Toggle(L("永不清理（不推荐）"), isOn: $forever)
        if !forever {
          Picker(L("快捷设置"), selection: $days) {
            Text(L("7天")).tag(7)
            Text(L("30天")).tag(30)
            Text(L("90天")).tag(90)
            if ![7, 30, 90].contains(days) { Text(L("自定义")).tag(days) }
          }
          Stepper(L("保留天数") + ": \(days)", value: $days, in: 1...365)
        }
        Button(L("应用保留期限")) { confirmation = "retention" }
        Text(L("默认保留30天，过期后将永久删除。恢复会保留正文、日期、收藏和标签。"))
          .font(.caption).foregroundStyle(.secondary)
      }
      Section {
        HStack {
          Button(L("全选")) { selected = Set(items.map(\.id)) }
          Spacer()
          Button(L("恢复所选")) { restore(Array(selected)) }.disabled(selected.isEmpty)
        }
        Button(L("永久删除所选"), role: .destructive) { confirmation = "selected" }.disabled(
          selected.isEmpty)
        Button(L("清空回收站"), role: .destructive) { confirmation = "all" }.disabled(items.isEmpty)
      }
      Section(L("回收站")) {
        if items.isEmpty { Text(L("这里暂时没有已删除的内容")).foregroundStyle(.secondary) }
        ForEach(items) { item in
          VStack(alignment: .leading, spacing: 8) {
            Toggle(
              isOn: Binding(
                get: { selected.contains(item.id) },
                set: { if $0 { selected.insert(item.id) } else { selected.remove(item.id) } })
            ) {
              Text(item.title).lineLimit(3)
            }
            Text(item.deletedAt.formatted(date: .abbreviated, time: .shortened)).font(.caption)
              .foregroundStyle(.secondary)
            HStack {
              Button(L("查看")) { preview = item }
              Button(L("恢复")) { restore([item.id]) }
              Button(L("恢复为副本")) { restore([item.id], asCopy: true) }
              Button(L("永久删除"), role: .destructive) {
                selected = [item.id]
                confirmation = "selected"
              }
            }.font(.caption).buttonStyle(.borderless)
          }
        }
      }
    }
    .navigationTitle(L("回收站")).scrollContentBackground(.hidden).flashPageBackground()
    .task { reload() }.onChange(of: repository?.revision) { reload() }
    .confirmationDialog(
      L("请确认操作"),
      isPresented: Binding(get: { confirmation != nil }, set: { if !$0 { confirmation = nil } })
    ) {
      Button(confirmation == "retention" ? L("应用保留期限") : L("永久删除"), role: .destructive) {
        perform {
          if confirmation == "retention" {
            preferences.retentionDays = forever ? 0 : days
            try repository?.savePreferences(preferences)
          } else {
            try repository?.permanentlyDeleteTrash(
              confirmation == "all" ? items.map(\.id) : Array(selected))
          }
        }
        confirmation = nil
      }
      Button(L("取消"), role: .cancel) { confirmation = nil }
    } message: {
      if confirmation == "retention" {
        let affected =
          forever
          ? 0
          : items.filter {
            Calendar.current.date(byAdding: .day, value: days, to: $0.deletedAt).map {
              $0 <= Date()
            } ?? false
          }.count
        Text(L("将永久删除到期内容") + ": \(affected)")
      } else {
        Text(L("此操作无法撤销。"))
      }
    }
    .sheet(item: $preview) { item in
      NavigationStack {
        ScrollView { Text(item.title).textSelection(.enabled).padding() }.navigationTitle(
          L("已删除内容")
        ).toolbar { Button(L("完成")) { preview = nil } }
      }
    }
  }
  private func reload() {
    do {
      items = try repository?.trashItems() ?? []
      preferences = try repository?.preferences() ?? .init()
      days = preferences.retentionDays == 0 ? 30 : preferences.retentionDays
      forever = preferences.retentionDays == 0
      selected.formIntersection(Set(items.map(\.id)))
    } catch { self.error = error.localizedDescription }
  }
  private func perform(_ block: () throws -> Void) {
    do {
      try block()
      error = nil
      reload()
    } catch { self.error = (error as? BackupError)?.userMessage ?? error.localizedDescription }
  }
  private func restore(_ ids: [String], asCopy: Bool = false) {
    do {
      try repository?.restoreTrash(ids, asCopy: asCopy)
      error = nil
      reload()
    } catch {
      self.error = (error as? BackupError)?.userMessage ?? error.localizedDescription
      return
    }
    guard let repository else { return }
    Task {
      do { try await TaskReminderScheduler.shared.rebuild(repository.tasksOnly()) } catch {
        self.error = L("内容已恢复，提醒未能启用")
      }
    }
  }
}
struct TaggingSettingsScreen: View {
  @Environment(\.flashRepository) private var repository
  @State private var preferences = LibraryPreferences()
  @State private var error: String?
  var body: some View {
    Form {
      Section(L("标签推荐")) {
        Picker(L("处理方式"), selection: $preferences.taggingMode) {
          ForEach(TaggingMode.allCases, id: \.self) { Text($0.title).tag($0) }
        }
        Text(LocalTagProvider.availabilityDescription).font(.caption).foregroundStyle(.secondary)
        Text(L("文字只在本机分析。推荐不会阻塞保存，你可以随时调整标签。"))
      }
      if let error { Text(error).foregroundStyle(.red) }
    }.navigationTitle(L("本地智能标签"))
      .task {
        do { preferences = try repository?.preferences() ?? .init() } catch {
          self.error = error.localizedDescription
        }
      }
      .onChange(of: preferences.taggingMode) {
        do {
          var current = try repository?.preferences() ?? .init()
          current.taggingMode = preferences.taggingMode
          try repository?.savePreferences(current)
        } catch { self.error = error.localizedDescription }
      }
  }
}
