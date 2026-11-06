// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import SwiftUI
import UniformTypeIdentifiers
import FlashCore
import FlashDesign

/// 设置页（iOS 外壳）：共享分组（外观 / 数据与安全 / 危险操作 / 关于）+ iOS 文件交互：
/// 导出走 `.fileExporter`（存到「文件」），分享走 ShareLink，导入走 `.fileImporter`（安全作用域访问），
/// 局域网收发走共享 LanTransferSheet。导入预览、合并/覆盖与提醒重建全部经 BackupImportCoordinator。
struct SettingsScreen: View {
    @Environment(\.flashRepository) private var repository
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var lanTransfer = LocalBackupTransferController.shared
    @State private var isBusy = false
    @State private var message: String? = nil
    @State private var toastMessage: String? = nil
    @State private var toastID = 0

    // 导出 / 分享
    @State private var exportDocument: BackupJSONDocument? = nil
    @State private var shareFile: ShareFile? = nil

    // 导入
    @State private var importerPresented = false
    @State private var recoveryImport = false
    @State private var importPreview: ImportPreview? = nil
    /// 首个 alert 关闭会把 importPreview 置 nil，覆盖二次确认从 pendingImport 取
    @State private var pendingImport: ImportPreview? = nil
    /// 生成预览时的本地快照（覆盖前 TOCTOU 重校验）
    @State private var pendingSnapshot: FlashSnapshot? = nil
    @State private var showOverwriteConfirm = false
    @State private var showClearConfirm = false

    var body: some View {
        Form {
            StorageBannerSection()
            AppearanceSection(appeared: true)
            IdeaReminderSection()
            DataSafetySection(isBusy: isBusy, appeared: true,
                              onShare: prepareShare,
                              onLanSend: startLanSend,
                              onLanReceive: { lanTransfer.startReceiving() },
                              onExport: prepareExport,
                              onImport: { chooseImportFile(recovery: false) },
                              onRecoveryImport: { chooseImportFile(recovery: true) })
            DangerZoneSection(isDisabled: isBusy || lanTransfer.mode != .idle) {
                showClearConfirm = true
            }
            AboutSection(version: BackupImportCoordinator.appVersion, appeared: true)
        }
        .scrollContentBackground(.hidden)
        .background(BrandColors.pageBackground)
        .navigationTitle("设置")
        .toolbar { GlobalSearchToolbarItem() }
        // 导出：先在后台生成 JSON，再交给系统「存储到文件」
        .fileExporter(isPresented: exportPresented, document: exportDocument,
                      contentType: .json,
                      defaultFilename: "flash-backup-\(DateFormatting.today()).json") { result in
            exportDocument = nil
            switch result {
            case .success: showToast("✓ 备份已导出")
            case .failure(let error):
                print("导出备份失败: \(error)")
                message = "导出失败，请检查目标位置后重试"
            }
        }
        .fileImporter(isPresented: $importerPresented, allowedContentTypes: [.json]) { result in
            switch result {
            case .success(let url): prepareFileImport(url)
            case .failure(let error):
                print("选择备份文件失败: \(error)")
                message = "无法打开所选文件，请重试"
            }
        }
        .sheet(item: $shareFile) { file in
            ShareBackupSheet(url: file.url)
                .presentationDetents([.height(260)])
        }
        .sheet(isPresented: lanTransferPresented) {
            LanTransferSheet(controller: lanTransfer)
                .presentationDetents([.medium, .large])
        }
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
        .overlay(alignment: .top) {
            if let toastMessage {
                ToastView(message: toastMessage)
                    .padding(.top, Spacing.sm)
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
            Button("取消", role: .cancel) { importPreview = nil; pendingImport = nil; pendingSnapshot = nil }
        } message: {
            if let preview = importPreview {
                Text(BackupImportCoordinator.analysisText(preview))
            }
        }
        .alert("覆盖导入将清空现有全部数据，确定继续？", isPresented: $showOverwriteConfirm) {
            Button("覆盖导入", role: .destructive) { confirmImport(overwrite: true) }
            Button("取消", role: .cancel) { pendingImport = nil; pendingSnapshot = nil }
        }
        .alert("清空全部数据？此操作不可撤销。", isPresented: $showClearConfirm) {
            Button("清空", role: .destructive) { clearAll() }
            Button("取消", role: .cancel) {}
        } message: {
            Text("将删除本机全部日志、灵感、情绪与任务。如未导出备份，数据将无法找回。")
        }
        .alert("提示", isPresented: messagePresented) {
            Button("好") { message = nil }
        } message: {
            Text(message ?? "")
        }
    }

    // MARK: - 绑定

    private var exportPresented: Binding<Bool> {
        Binding(get: { exportDocument != nil }, set: { if !$0 { exportDocument = nil } })
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

    // MARK: - 导出 / 分享 / 局域网发送

    private func prepareExport() {
        isBusy = true
        Task {
            defer { isBusy = false }
            do {
                let json = try await BackupImportCoordinator.exportJSON(
                    snapshot: try currentSnapshot(), appVersion: BackupImportCoordinator.appVersion)
                exportDocument = BackupJSONDocument(json: json)
            } catch {
                print("生成备份失败: \(error)")
                message = "生成备份失败，请重试"
            }
        }
    }

    private func prepareShare() {
        isBusy = true
        Task {
            defer { isBusy = false }
            do {
                let json = try await BackupImportCoordinator.exportJSON(
                    snapshot: try currentSnapshot(), appVersion: BackupImportCoordinator.appVersion)
                // 沙箱缓存副本（0600，过期自动清理），交给系统分享面板
                let url = try await Task.detached(priority: .userInitiated) {
                    try BackupTransfer.createShareFile(json: json)
                }.value
                shareFile = ShareFile(url: url)
            } catch {
                print("生成分享文件失败: \(error)")
                message = "生成传输文件失败，请重试"
            }
        }
    }

    private func startLanSend() {
        Task {
            do {
                let json = try await BackupImportCoordinator.exportJSON(
                    snapshot: try currentSnapshot(), appVersion: BackupImportCoordinator.appVersion)
                lanTransfer.startSending(json: json)
            } catch {
                message = "无法生成局域网备份，请重试"
            }
        }
    }

    // MARK: - 导入

    private func chooseImportFile(recovery: Bool) {
        recoveryImport = recovery
        importerPresented = true
    }

    private func prepareFileImport(_ url: URL) {
        isBusy = true
        Task {
            defer { isBusy = false }
            // 「文件」App 选中的文件需安全作用域访问
            let accessing = url.startAccessingSecurityScopedResource()
            defer { if accessing { url.stopAccessingSecurityScopedResource() } }
            do {
                let snapshot = try currentSnapshot()
                let preview = try await BackupImportCoordinator.preview(fileAt: url, recovery: recoveryImport,
                                                                        against: snapshot)
                pendingImport = preview
                pendingSnapshot = snapshot
                importPreview = preview
            } catch let error as BackupError {
                message = error.userMessage
            } catch {
                print("导入备份失败: \(error)")
                message = "导入失败，请确认选择的是 Flash 备份文件后重试"
            }
        }
    }

    private func prepareLanImport(_ json: String) {
        recoveryImport = false
        isBusy = true
        Task {
            defer { isBusy = false }
            do {
                let snapshot = try currentSnapshot()
                let preview = try await BackupImportCoordinator.preview(json: json, against: snapshot)
                pendingImport = preview
                pendingSnapshot = snapshot
                importPreview = preview
            } catch let error as BackupError {
                message = error.userMessage
            } catch {
                message = "接收到的内容不是有效的 Flash 备份"
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
                switch try await BackupImportCoordinator.apply(preview, overwrite: overwrite,
                                                               previewSnapshot: pendingSnapshot,
                                                               repository: repository) {
                case .changedSincePreview(let refreshed, let current):
                    pendingSnapshot = current
                    pendingImport = refreshed
                    importPreview = refreshed
                    showToast("本地数据在预览后有变化，差异已重新计算，请确认后再覆盖")
                    return
                case .importedRemindersFailed:
                    message = "数据已导入，但系统提醒恢复失败，请稍后重试"
                case .imported(let text, let hasSkipped):
                    if hasSkipped { message = text } else { showToast("✓ " + text) }
                }
            } catch {
                print("导入写库失败: \(error)")
                message = "导入失败：写入数据库时出错，请重试"
            }
            pendingImport = nil
            pendingSnapshot = nil
            importPreview = nil
        }
    }

    // MARK: - 清空

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

    // MARK: - 工具

    private func currentSnapshot() throws -> FlashSnapshot {
        guard let repository else { throw SettingsDataError.repositoryUnavailable }
        return try repository.snapshot()
    }

    private func showToast(_ text: String) {
        toastMessage = text
        toastID += 1
    }

    private enum SettingsDataError: Error {
        case repositoryUnavailable
    }
}

/// 导出用的 JSON 文档（交给 `.fileExporter`；只写不读）
struct BackupJSONDocument: FileDocument {
    static let readableContentTypes: [UTType] = [.json]
    let json: String

    init(json: String) {
        self.json = json
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents,
              let json = String(data: data, encoding: .utf8) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.json = json
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(json.utf8))
    }
}

/// 待分享的备份副本（sheet(item:) 承载）
struct ShareFile: Identifiable {
    let url: URL
    var id: URL { url }
}

/// 分享面板：备份副本已生成，由 ShareLink 交给系统分享（AirDrop / 信息 / 邮件 / 云盘）
private struct ShareBackupSheet: View {
    let url: URL

    var body: some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: "doc.badge.arrow.up")
                .font(.largeTitle)
                .foregroundStyle(BrandColors.brandPrimary)
            Text("备份文件已准备好")
                .font(Typography.cardTitle)
            Text("明文 JSON，仅分享给可信设备或联系人。")
                .font(Typography.caption)
                .foregroundStyle(.secondary)
            ShareLink(item: url, preview: SharePreview("Flash 备份", image: Image(systemName: "doc"))) {
                Label("分享备份…", systemImage: "square.and.arrow.up")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(BrandColors.brandPrimary)
        }
        .padding(Spacing.lg)
    }
}
