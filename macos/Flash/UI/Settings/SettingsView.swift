// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import SwiftUI
import AppKit // NSSavePanel / NSOpenPanel
import UniformTypeIdentifiers

/// 设置页：外观 / 数据备份 / 关于（对齐 Android SettingsViewModel）
struct SettingsView: View {
    @EnvironmentObject private var settings: SettingsStore
    @Environment(\.flashRepository) private var repository
    @Environment(AppState.self) private var appState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var recoveryImport = false
    @State private var importPreview: ImportPreview? = nil
    /// 独立保存待导入数据：首个 alert dismiss 会把 importPreview 置 nil，
    /// 覆盖导入的二次确认从 pendingImport 取，避免 guard 落空静默失效
    @State private var pendingImport: ImportPreview? = nil
    @State private var showOverwriteConfirm = false
    @State private var showClearConfirm = false
    @State private var message: String? = nil
    @State private var sharingPicker: NSSharingServicePicker? = nil
    /// 共享控制器：切走模块时视图销毁但进行中的传输继续，回到设置页可看到进度与结果
    @State private var lanTransfer = LocalBackupTransferController.shared
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
                Button("通过系统分享…") { transferBackup() }
                    .hoverFeedback(reduceMotion: reduceMotion)
                HStack {
                    Button("局域网发送…") { startLanSend() }
                    Button("局域网接收…") { lanTransfer.startReceiving() }
                }
                Button("导出备份…") { exportBackup() }
                    .hoverFeedback(reduceMotion: reduceMotion)
                Button("标准导入…") { chooseImportFile() }
                Button("恢复损坏或旧版备份…") { chooseImportFile(recovery: true) }
                    .hoverFeedback(reduceMotion: reduceMotion)
                Button("清空全部数据…", role: .destructive) { showClearConfirm = true }
                    .hoverFeedback(reduceMotion: reduceMotion)
                Text("通过系统分享传输明文 JSON；可选择 AirDrop、信息、邮件或云盘。")
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
            flushLanTransferResults()
            playEntranceAnimation()
        }
        .onChange(of: appState.exportRequestToken) { flushExportRequest() }
        // 发送/配对接收进行中不静默取消：控制器为共享实例，传输跨模块切换继续；
        // 仅浏览设备阶段（尚未建立连接）随手清理
        .onDisappear {
            if lanTransfer.mode != .sending && lanTransfer.mode != .connecting {
                lanTransfer.cancel()
            }
        }
        .sheet(isPresented: lanTransferPresented) { lanTransferSheet }
        .onChange(of: lanTransfer.receivedJSON) { _, json in
            guard let json else { return }
            lanTransfer.receivedJSON = nil
            prepareLanImport(json)
        }
        .onChange(of: lanTransfer.errorMessage) { _, error in
            guard let error else { return }
            lanTransfer.errorMessage = nil
            message = error
        }
        .onChange(of: lanTransfer.sendCompleted) { _, completed in
            guard completed else { return }
            lanTransfer.sendCompleted = false
            showToast("✓ 备份已发送至对方设备，请在对端确认导入")
        }
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
        .alert(recoveryImport ? "部分恢复预览（原文件不变）" : "标准导入预览", isPresented: previewPresented) {
            Button("按差异合并") { pendingImport = importPreview; confirmImport(overwrite: false) }
            Button("覆盖导入", role: .destructive) { pendingImport = importPreview; showOverwriteConfirm = true }
            Button("取消", role: .cancel) { importPreview = nil; pendingImport = nil }
        } message: {
            if let preview = importPreview {
                Text(importAnalysisText(preview))
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

    private var lanTransferPresented: Binding<Bool> {
        Binding(get: { lanTransfer.mode != .idle }, set: { if !$0 { lanTransfer.cancel() } })
    }

    @ViewBuilder private var lanTransferSheet: some View {
        VStack(alignment: .leading, spacing: 16) {
            switch lanTransfer.mode {
            case .sending:
                Text("等待接收设备").font(.title2.bold())
                Text("在另一台设备选择“局域网接收”，然后输入配对 PIN：")
                Text(lanTransfer.pin)
                    .font(.system(size: 48, weight: .semibold, design: .rounded))
                    .foregroundStyle(.tint)
                    .textSelection(.enabled)
                Text("PIN 仅本次有效，60 秒后自动失效。")
                    .font(.caption).foregroundStyle(.secondary)
                Button("取消发送") { lanTransfer.cancel() }

            case .receiving:
                Text("从局域网接收").font(.title2.bold())
                if lanTransfer.devices.isEmpty {
                    HStack { ProgressView(); Text("正在查找附近的 Flash Aero…") }
                } else {
                    Text("选择发送设备：")
                    ForEach(lanTransfer.devices) { device in
                        Button {
                            lanTransfer.selectedDevice = device
                        } label: {
                            HStack {
                                Image(systemName: lanTransfer.selectedDevice == device ? "checkmark.circle.fill" : "circle")
                                Text(device.name)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                TextField("四位配对 PIN", text: $lanTransfer.enteredPIN)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: lanTransfer.enteredPIN) { _, value in
                        lanTransfer.enteredPIN = String(value.filter(\.isNumber).prefix(4))
                    }
                HStack {
                    Button("取消") { lanTransfer.cancel() }
                    Spacer()
                    Button("配对并接收") { lanTransfer.connect() }
                        .buttonStyle(.borderedProminent)
                        .disabled(lanTransfer.selectedDevice == nil || lanTransfer.enteredPIN.count != 4)
                }

            case .connecting:
                Text("正在配对").font(.title2.bold())
                HStack { ProgressView(); Text("正在验证 PIN 并接收备份…") }
                Button("取消") { lanTransfer.cancel() }

            case .idle:
                EmptyView()
            }
            Divider()
            Text("备份内容未做端到端加密，请仅在可信的家庭或办公局域网使用。")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(24)
        .frame(width: 420)
    }

    private var appVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
        return "Flash Aero v\(version) (\(build))"
    }

    private func importAnalysisText(_ preview: ImportPreview) -> String {
        var text = "包含 \(preview.logCount) 条日志、\(preview.emotionCount) 条情绪、\(preview.taskCount) 个任务"
        let skipped = preview.skippedLogs + preview.skippedEmotions + preview.skippedTasks
        if skipped > 0 { text += "\n跳过异常数据 \(skipped) 条" }
        if let difference = preview.difference {
            text += "\n\n差异分析"
            text += "\n日志：新增 \(difference.logs.added) · 修改 \(difference.logs.changed)" +
                " · 相同 \(difference.logs.unchanged) · 仅本机 \(difference.logs.localOnly)"
            text += "\n情绪：新增 \(difference.emotions.added) · 修改 \(difference.emotions.changed)" +
                " · 相同 \(difference.emotions.unchanged) · 仅本机 \(difference.emotions.localOnly)"
            text += "\n任务：新增 \(difference.tasks.added) · 修改 \(difference.tasks.changed)" +
                " · 相同 \(difference.tasks.unchanged) · 仅本机 \(difference.tasks.localOnly)"
            text += "\n\n差异合并会新增或更新接收数据，并保留仅本机数据；覆盖会先清空本机数据。"
        }
        return text
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

    private func transferBackup() {
        isBusy = true
        Task {
            defer { isBusy = false }
            do {
                let snapshot = try currentSnapshot()
                let version = appVersion
                let url = try await Task.detached(priority: .userInitiated) {
                    let json = try BackupService.exportStrictJSON(logs: snapshot.logs,
                                                        emotions: snapshot.emotions,
                                                        tasks: snapshot.tasks,
                                                        appVersion: version)
                    return try BackupTransfer.createShareFile(json: json)
                }.value
                guard let view = NSApp.keyWindow?.contentView ?? NSApp.mainWindow?.contentView else {
                    throw TransferPresentationError.noWindow
                }
                let picker = NSSharingServicePicker(items: [url])
                sharingPicker = picker
                picker.show(relativeTo: view.bounds, of: view, preferredEdge: .minY)
            } catch {
                print("传输备份失败: \(error)")
                message = "生成传输文件失败，请重试"
            }
        }
    }

    private func startLanSend() {
        do {
            let snapshot = try currentSnapshot()
            let json = try BackupService.exportStrictJSON(logs: snapshot.logs,
                                                emotions: snapshot.emotions,
                                                tasks: snapshot.tasks,
                                                appVersion: appVersion)
            lanTransfer.startSending(json: json)
        } catch {
            message = "无法生成局域网备份，请重试"
        }
    }

    private func flushLanTransferResults() {
        if let json = lanTransfer.receivedJSON {
            lanTransfer.receivedJSON = nil
            prepareLanImport(json)
        }
        if let error = lanTransfer.errorMessage {
            lanTransfer.errorMessage = nil
            message = error
        }
        if lanTransfer.sendCompleted {
            lanTransfer.sendCompleted = false
            showToast("✓ 备份已发送至对方设备，请在对端确认导入")
        }
    }

    private func prepareLanImport(_ json: String) {
        recoveryImport = false
        isBusy = true
        Task {
            defer { isBusy = false }
            do {
                let snapshot = try currentSnapshot()
                let preview = try await Task.detached(priority: .userInitiated) {
                    var preview = try BackupService.parseStrict(json)
                    preview.difference = BackupDiff.analyze(
                        localLogs: snapshot.logs, localEmotions: snapshot.emotions,
                        incomingLogs: preview.logs, incomingEmotions: preview.emotions,
                        localTasks: snapshot.tasks, incomingTasks: preview.tasks)
                    return preview
                }.value
                pendingImport = preview
                importPreview = preview
            } catch let error as BackupError {
                message = error.userMessage
            } catch {
                message = "接收到的内容不是有效的 Flash 备份"
            }
        }
    }

    private enum TransferPresentationError: Error {
        case noWindow
    }

    /// 菜单「导出备份…」⇧⌘E：token 递增时弹导出面板。
    /// onAppear 兜底：跨模块命令使本视图首次创建时 token 已递增，onChange 不会回放。
    private func flushExportRequest() {
        guard appState.exportRequestToken != appState.handledExportToken else { return }
        appState.markExportHandled()
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
                let snapshot = try currentSnapshot()
                let version = appVersion
                try await Task.detached(priority: .userInitiated) {
                    let json = try BackupService.exportStrictJSON(logs: snapshot.logs,
                                                        emotions: snapshot.emotions,
                                                        tasks: snapshot.tasks,
                                                        appVersion: version)
                    try BackupTransfer.writeExportFile(json: json, to: url)
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

    private func chooseImportFile(recovery: Bool = false) {
        recoveryImport = recovery
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        isBusy = true
        Task {
            defer { isBusy = false }
            do {
                let snapshot = try currentSnapshot()
                let preview = try await Task.detached(priority: .userInitiated) {
                    // 全量读入前先查文件大小，超 50MB 直接拒绝
                    let values = try url.resourceValues(forKeys: [.fileSizeKey])
                    if let size = values.fileSize, size > BackupService.maxFileBytes {
                        throw BackupError.fileTooLarge
                    }
                    let json = try BackupService.readJSON(from: url)
                    var preview = try recovery ? BackupService.parseRecovery(json) : BackupService.parseStrict(json)
                    preview.difference = BackupDiff.analyze(
                        localLogs: snapshot.logs, localEmotions: snapshot.emotions,
                        incomingLogs: preview.logs, incomingEmotions: preview.emotions,
                        localTasks: snapshot.tasks, incomingTasks: preview.tasks)
                    return preview
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
        isBusy = true
        Task {
            defer { isBusy = false }
            do {
                guard let repository else { throw SettingsDataError.repositoryUnavailable }
                if overwrite {
                    try repository.replaceAll(logs: preview.logs, emotions: preview.emotions,
                                              tasks: preview.tasks)
                } else {
                    try repository.mergeAll(logs: preview.logs, emotions: preview.emotions,
                                            tasks: preview.tasks)
                }
                do {
                    try await TaskReminderScheduler.shared.rebuild(try currentSnapshot().tasks)
                } catch {
                    message = "数据已导入，但系统提醒恢复失败，请稍后重试"
                    pendingImport = nil
                    importPreview = nil
                    return
                }
                let skipped = preview.skippedLogs + preview.skippedEmotions + preview.skippedTasks
                if skipped > 0 {
                    // 有跳过条目时保留 alert，把异常明细告知用户
                    message = "已导入 \(preview.logCount) 条日志、\(preview.emotionCount) 条情绪、" +
                        "\(preview.taskCount) 个任务" +
                        "（跳过异常数据 \(skipped) 条）"
                } else {
                    showToast("✓ 已导入 \(preview.logCount) 条日志、\(preview.emotionCount) 条情绪、" +
                              "\(preview.taskCount) 个任务")
                }
            } catch {
                print("导入写库失败: \(error)")
                message = "导入失败：写入数据库时出错，请重试"
            }
            pendingImport = nil
            importPreview = nil
        }
    }

    private func clearAll() {
        Task {
            do {
                guard let repository else { throw SettingsDataError.repositoryUnavailable }
                try repository.clearAll()
                do {
                    try await TaskReminderScheduler.shared.rebuild([])
                    showToast("✓ 已清空全部数据")
                } catch {
                    message = "数据已清空，但系统提醒清理失败，请重启应用后重试"
                }
            } catch {
                print("清空数据失败: \(error)")
                message = "清空失败，请重试"
            }
        }
    }

    private func currentSnapshot() throws -> FlashSnapshot {
        guard let repository else { throw SettingsDataError.repositoryUnavailable }
        return try repository.snapshot()
    }

    private enum SettingsDataError: Error {
        case repositoryUnavailable
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
