import SwiftUI
import AppKit // NSSavePanel / NSOpenPanel
import UniformTypeIdentifiers

/// 设置页：外观 / 数据备份 / 关于（对齐 Android SettingsViewModel）
struct SettingsView: View {
    @EnvironmentObject private var settings: SettingsStore
    @Environment(\.flashRepository) private var repository
    @Environment(AppState.self) private var appState

    @State private var importPreview: ImportPreview? = nil
    @State private var showOverwriteConfirm = false
    @State private var showClearConfirm = false
    @State private var message: String? = nil
    @State private var handledExportToken = 0

    var body: some View {
        Form {
            Section("外观") {
                Picker("主题", selection: themeBinding) {
                    ForEach(ThemeMode.allCases, id: \.self) {
                        Text($0.displayName).tag($0)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section("数据") {
                Button("导出备份…") { exportBackup() }
                Button("导入备份…") { chooseImportFile() }
                Button("清空全部数据…", role: .destructive) { showClearConfirm = true }
            }

            Section("关于") {
                LabeledContent("版本", value: appVersion)
                Text("数据仅保存在本机，不会上传到任何服务器。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
        .onAppear { flushExportRequest() }
        .onChange(of: appState.exportRequestToken) { flushExportRequest() }
        .alert("导入备份", isPresented: previewPresented) {
            Button("合并导入") { confirmImport(overwrite: false) }
            Button("覆盖导入", role: .destructive) { showOverwriteConfirm = true }
            Button("取消", role: .cancel) { importPreview = nil }
        } message: {
            if let preview = importPreview {
                Text("包含 \(preview.logCount) 条日志、\(preview.emotionCount) 条情绪" +
                     (preview.skippedLogs + preview.skippedEmotions > 0
                      ? "\n跳过异常数据 \(preview.skippedLogs + preview.skippedEmotions) 条" : ""))
            }
        }
        .alert("覆盖导入将清空现有全部数据，确定继续？", isPresented: $showOverwriteConfirm) {
            Button("覆盖导入", role: .destructive) { confirmImport(overwrite: true) }
            Button("取消", role: .cancel) {}
        }
        .alert("清空全部数据？此操作不可撤销。", isPresented: $showClearConfirm) {
            Button("清空", role: .destructive) { clearAll() }
            Button("取消", role: .cancel) {}
        }
        .alert("提示", isPresented: messagePresented) {
            Button("好") { message = nil }
        } message: {
            Text(message ?? "")
        }
    }

    private var themeBinding: Binding<ThemeMode> {
        Binding(get: { settings.themeMode }, set: { settings.setThemeMode($0) })
    }

    private var previewPresented: Binding<Bool> {
        Binding(get: { importPreview != nil }, set: { if !$0 { importPreview = nil } })
    }

    private var messagePresented: Binding<Bool> {
        Binding(get: { message != nil }, set: { if !$0 { message = nil } })
    }

    private var appVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
        return "\(version) (\(build))"
    }

    // MARK: - 导出

    /// 菜单「导出备份…」⇧⌘E：token 递增时弹导出面板。
    /// onAppear 兜底：跨模块命令使本视图首次创建时 token 已递增，onChange 不会回放。
    private func flushExportRequest() {
        guard appState.exportRequestToken != handledExportToken else { return }
        handledExportToken = appState.exportRequestToken
        // 菜单 action 在 AppKit 菜单跟踪事件循环内同步触发，同步 runModal() 会被吞；
        // 异步逃逸出菜单跟踪后再弹面板（onAppear 路径同样安全）
        DispatchQueue.main.async { exportBackup() }
    }

    private func exportBackup() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "flash-backup-\(DateFormatting.today()).json"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let logs = try repository?.allLogs() ?? []
            let emotions = try repository?.allEmotions() ?? []
            let json = BackupService.exportJSON(logs: logs, emotions: emotions,
                                                appVersion: appVersion)
            try json.write(to: url, atomically: true, encoding: .utf8)
            message = "备份已导出"
        } catch {
            message = "导出失败：\(error.localizedDescription)"
        }
    }

    // MARK: - 导入

    private func chooseImportFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let data = try Data(contentsOf: url)
            guard data.count <= BackupService.maxFileBytes else {
                message = BackupError.fileTooLarge.userMessage
                return
            }
            let text = String(decoding: data, as: UTF8.self)
            importPreview = try BackupService.parse(text)
        } catch let error as BackupError {
            message = error.userMessage
        } catch {
            message = "导入失败：\(error.localizedDescription)"
        }
    }

    private func confirmImport(overwrite: Bool) {
        guard let preview = importPreview else { return }
        do {
            if overwrite {
                try repository?.replaceAll(logs: preview.logs, emotions: preview.emotions)
            } else {
                try repository?.mergeAll(logs: preview.logs, emotions: preview.emotions)
            }
            let skipped = preview.skippedLogs + preview.skippedEmotions
            message = "已导入 \(preview.logCount) 条日志、\(preview.emotionCount) 条情绪" +
                (skipped > 0 ? "（跳过异常数据 \(skipped) 条）" : "")
        } catch {
            message = "导入失败：\(error.localizedDescription)"
        }
        importPreview = nil
    }

    private func clearAll() {
        do {
            try repository?.clearAll()
            message = "已清空全部数据"
        } catch {
            message = "清空失败：\(error.localizedDescription)"
        }
    }
}
