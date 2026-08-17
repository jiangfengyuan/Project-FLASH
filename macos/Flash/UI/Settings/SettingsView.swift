import SwiftUI
import AppKit // NSSavePanel / NSOpenPanel
import UniformTypeIdentifiers

/// 设置页：外观 / 数据备份 / 关于（对齐 Android SettingsViewModel）
struct SettingsView: View {
    @EnvironmentObject private var settings: SettingsStore
    @Environment(\.flashRepository) private var repository
    @Environment(AppState.self) private var appState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var importPreview: ImportPreview? = nil
    /// 独立保存待导入数据：首个 alert dismiss 会把 importPreview 置 nil，
    /// 覆盖导入的二次确认从 pendingImport 取，避免 guard 落空静默失效
    @State private var pendingImport: ImportPreview? = nil
    @State private var showOverwriteConfirm = false
    @State private var showClearConfirm = false
    @State private var message: String? = nil
    @State private var handledExportToken = 0
    /// 导入/导出进行中（大文件 IO 已移到后台，期间禁用按钮防重入）
    @State private var isBusy = false
    /// 成功反馈走顶部 toast（与 Home 一致，nil 表示不展示）；失败仍走 alert 保留详情。
    /// toastID 用于相同文案连发时重置计时
    @State private var toastMessage: String? = nil
    @State private var toastID = 0
    /// 分组入场标记（stagger 依次淡入上移）
    @State private var appearanceAppeared = false
    @State private var dataAppeared = false
    @State private var aboutAppeared = false

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
            .opacity(appearanceAppeared ? 1 : 0)
            .offset(y: !appearanceAppeared && !reduceMotion ? 6 : 0)

            Section("数据") {
                Button("导出备份…") { exportBackup() }
                    .hoverFeedback(reduceMotion: reduceMotion)
                Button("导入备份…") { chooseImportFile() }
                    .hoverFeedback(reduceMotion: reduceMotion)
                Button("清空全部数据…", role: .destructive) { showClearConfirm = true }
                    .hoverFeedback(reduceMotion: reduceMotion)
                Text("备份为明文 JSON 文件，请妥善选择存放位置。")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                if isBusy {
                    HStack(spacing: 8) {
                        ProgressView().controlSize(.small)
                        Text("正在处理…")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .transition(.appear(reduceMotion: reduceMotion))
                }
            }
            .disabled(isBusy)
            .animation(reduceMotion ? Motion.reducedFade(true) : Motion.soft(), value: isBusy)
            .opacity(dataAppeared ? 1 : 0)
            .offset(y: !dataAppeared && !reduceMotion ? 6 : 0)

            Section("关于") {
                LabeledContent("版本", value: appVersion)
                Label("数据仅保存在本机，不会上传到任何服务器。", systemImage: "lock.shield")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .opacity(aboutAppeared ? 1 : 0)
            .offset(y: !aboutAppeared && !reduceMotion ? 6 : 0)
        }
        .formStyle(.grouped)
        .padding()
        .onAppear {
            flushExportRequest()
            playEntranceAnimation()
        }
        .onChange(of: appState.exportRequestToken) { flushExportRequest() }
        // 顶部 toast：过渡由 ToastView 内置 .pop 接管，调用点不再叠加 .transition
        .overlay(alignment: .top) {
            if let toastMessage {
                ToastView(message: toastMessage)
                    .padding(.top, 12)
            }
        }
        .animation(reduceMotion ? Motion.reducedFade(true) : Motion.spring(), value: toastMessage != nil)
        .task(id: toastID) {
            guard toastMessage != nil else { return }
            try? await Task.sleep(for: .seconds(1.6))
            guard !Task.isCancelled else { return }
            toastMessage = nil
        }
        .alert("导入备份", isPresented: previewPresented) {
            Button("合并导入") { pendingImport = importPreview; confirmImport(overwrite: false) }
            Button("覆盖导入", role: .destructive) { pendingImport = importPreview; showOverwriteConfirm = true }
            Button("取消", role: .cancel) { importPreview = nil; pendingImport = nil }
        } message: {
            if let preview = importPreview {
                Text("包含 \(preview.logCount) 条日志、\(preview.emotionCount) 条情绪" +
                     (preview.skippedLogs + preview.skippedEmotions > 0
                      ? "\n跳过异常数据 \(preview.skippedLogs + preview.skippedEmotions) 条" : ""))
            }
        }
        .alert("覆盖导入将清空现有全部数据，确定继续？", isPresented: $showOverwriteConfirm) {
            Button("覆盖导入", role: .destructive) { confirmImport(overwrite: true) }
            Button("取消", role: .cancel) { pendingImport = nil }
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

    /// 入场动画：三分组 fade + 轻微上移（y 6→0，对齐 .appear 过渡），
    /// 按 staggerDelay 依次入场；减弱动态时 Motion.softOut 返回 nil，只留瞬时呈现
    private func playEntranceAnimation() {
        guard !appearanceAppeared else { return }
        withAnimation(Motion.softOut(reduceMotion)) { appearanceAppeared = true }
        withAnimation(Motion.softOut(reduceMotion)?.delay(Motion.staggerDelay(1))) { dataAppeared = true }
        withAnimation(Motion.softOut(reduceMotion)?.delay(Motion.staggerDelay(2))) { aboutAppeared = true }
    }

    /// 展示顶部 toast；toastID 递增使相同文案连发也重新计时（.task(id:) 自动取消旧计时）
    private func showToast(_ text: String) {
        toastMessage = text
        toastID += 1
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
        isBusy = true
        Task {
            defer { isBusy = false }
            do {
                // repository 写库/读库方法均为 @MainActor，序列化与文件 IO 移出主线程
                let logs = try repository?.allLogs() ?? []
                let emotions = try repository?.allEmotions() ?? []
                let version = appVersion
                try await Task.detached(priority: .userInitiated) {
                    let json = BackupService.exportJSON(logs: logs, emotions: emotions,
                                                        appVersion: version)
                    try json.write(to: url, atomically: true, encoding: .utf8)
                    // 日记明文备份：限制为仅当前用户可读写（多用户 Mac 保护）
                    try FileManager.default.setAttributes([.posixPermissions: NSNumber(value: 0o600)],
                                                          ofItemAtPath: url.path)
                }.value
                showToast("✓ 备份已导出")
            } catch {
                // 弹窗只给固定文案，路径等详情只进日志
                print("导出备份失败: \(error)")
                message = "导出失败，请检查目标位置的写入权限后重试"
            }
        }
    }

    // MARK: - 导入

    private func chooseImportFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        isBusy = true
        Task {
            defer { isBusy = false }
            do {
                let preview = try await Task.detached(priority: .userInitiated) {
                    // 全量读入前先查文件大小，超 50MB 直接拒绝
                    let values = try url.resourceValues(forKeys: [.fileSizeKey])
                    if let size = values.fileSize, size > BackupService.maxFileBytes {
                        throw BackupError.fileTooLarge
                    }
                    let data = try Data(contentsOf: url)
                    guard data.count <= BackupService.maxFileBytes else {
                        throw BackupError.fileTooLarge
                    }
                    return try BackupService.parse(String(decoding: data, as: UTF8.self))
                }.value
                pendingImport = preview
                importPreview = preview
            } catch let error as BackupError {
                message = error.userMessage
            } catch {
                print("导入备份失败: \(error)")
                message = "导入失败，请确认选择的是 Flash 备份文件后重试"
            }
        }
    }

    private func confirmImport(overwrite: Bool) {
        guard let preview = pendingImport else { return }
        do {
            if overwrite {
                try repository?.replaceAll(logs: preview.logs, emotions: preview.emotions)
            } else {
                try repository?.mergeAll(logs: preview.logs, emotions: preview.emotions)
            }
            let skipped = preview.skippedLogs + preview.skippedEmotions
            if skipped > 0 {
                // 有跳过条目时保留 alert，把异常明细告知用户
                message = "已导入 \(preview.logCount) 条日志、\(preview.emotionCount) 条情绪" +
                    "（跳过异常数据 \(skipped) 条）"
            } else {
                showToast("✓ 已导入 \(preview.logCount) 条日志、\(preview.emotionCount) 条情绪")
            }
        } catch {
            print("导入写库失败: \(error)")
            message = "导入失败：写入数据库时出错，请重试"
        }
        pendingImport = nil
        importPreview = nil
    }

    private func clearAll() {
        do {
            try repository?.clearAll()
            showToast("✓ 已清空全部数据")
        } catch {
            print("清空数据失败: \(error)")
            message = "清空失败，请重试"
        }
    }
}

/// 按钮悬停反馈：quick 曲线轻微降不透明度；Reduce Motion 下瞬变
private struct HoverFeedbackModifier: ViewModifier {
    let reduceMotion: Bool
    @State private var hovering = false

    func body(content: Content) -> some View {
        content
            .opacity(hovering ? 0.7 : 1)
            .animation(Motion.quick(reduceMotion), value: hovering)
            .onHover { hovering = $0 }
    }
}

private extension View {
    func hoverFeedback(reduceMotion: Bool) -> some View {
        modifier(HoverFeedbackModifier(reduceMotion: reduceMotion))
    }
}
