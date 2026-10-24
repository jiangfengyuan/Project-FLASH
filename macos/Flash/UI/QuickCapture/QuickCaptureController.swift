// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import AppKit
import Combine
import SwiftUI
import FlashCore
import FlashDesign

/// Quick Capture 面板控制器（PRD §13/§14）：全局热键唤起 → 非激活样式 NSPanel
/// 悬浮输入 → Enter/⌘Enter 保存即关、Esc 放弃。未提交关闭时草稿持久化，下次打开恢复。
///
/// 装配顺序：FlashApp.init 调 `configure(repository:settings:)`（容器同源装配完成后），
/// AppDelegate.applicationDidFinishLaunching 调 `start()`（事件循环就绪后注册热键）。
@MainActor
final class QuickCaptureController: NSObject {
    static let shared = QuickCaptureController()

    private var panel: QuickCapturePanel?
    private var repository: FlashRepository?
    private var settings: SettingsStore?
    private let draftStore: QuickCaptureDraftStore
    private var hotKeySubscription: AnyCancellable?
    private var started = false
    /// 视图逐键回报的最新草稿：失焦/再次按热键等关闭路径取它持久化
    private var currentDraft = QuickCaptureDraft(text: "", category: .idea)
    /// 提交成功的关闭不再保存草稿（草稿已在保存时清除）
    private var saveDraftOnClose = true

    private override init() {
        draftStore = QuickCaptureDraftStore()
    }

    func configure(repository: FlashRepository, settings: SettingsStore) {
        self.repository = repository
        self.settings = settings
    }

    /// 启动注册：当前快捷键注册 + 订阅改绑（设置页录制成功后走这里重注册）
    func start() {
        guard !started, let settings else { return }
        started = true
        let hotKeys = GlobalHotKeyService.shared
        hotKeys.onHotKeyPressed = { [weak self] in
            self?.toggle()
        }
        hotKeys.register(settings.quickCaptureHotkey)
        hotKeySubscription = settings.$quickCaptureHotkey
            .dropFirst() // 跳过 @Published 的当前值回放（上面已显式注册）
            .sink { chord in
                Task { @MainActor in
                    GlobalHotKeyService.shared.register(chord)
                }
            }
    }

    /// 热键/菜单入口：面板可见时视为取消（保留草稿），否则打开
    func toggle() {
        if panel?.isVisible == true {
            dismissWithoutCommit()
        } else {
            showPanel()
        }
    }

    func showPanel() {
        guard repository != nil else { return }
        let draft = draftStore.load() ?? QuickCaptureDraft(text: "", category: .idea)
        currentDraft = draft
        saveDraftOnClose = true

        let view = QuickCaptureView(
            draft: draft,
            onCommit: { [weak self] text, category in
                self?.commit(text: text, category: category) ?? "内部错误：面板未装配"
            },
            onCancel: { [weak self] text, category in
                self?.cancel(text: text, category: category)
            },
            onChange: { [weak self] text, category in
                self?.currentDraft = QuickCaptureDraft(text: text, category: category)
            })
        // 应用主题覆盖与主窗口/菜单栏伴侣同源
            .preferredColorScheme(settings?.themeMode.colorScheme)

        let hostingView = NSHostingView(rootView: view)
        let panel = self.panel ?? makePanel()
        panel.setContentSize(hostingView.fittingSize)
        panel.contentView = hostingView
        positionPanel(panel)
        panel.makeKeyAndOrderFront(nil)
        panel.orderFrontRegardless()
        self.panel = panel
    }

    // MARK: - 提交 / 取消 / 关闭

    /// 保存走 FlashRepository（与首页快速记录同一写入口）；返回 nil 成功，非 nil 为内联错误文案
    private func commit(text: String, category: Category) -> String? {
        let content = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else { return nil } // 空输入 Enter：不动（对齐菜单栏伴侣静默守卫）
        guard TextLimits.fits(content) else {
            return "内容超出 \(TextLimits.maxContentUTF16) 字上限，请删减后再保存"
        }
        guard let repository else { return "内部错误：存储未就绪" }
        do {
            switch category {
            case .idea:
                // Quick Capture 默认类型 Idea（PRD §13.3），沿用 !! 语法标记重要度
                try repository.addLog(content: content, colorTag: .idea, category: .idea,
                                      importance: importanceFromContent(content))
            case .log:
                try repository.addLog(content: content, colorTag: .daily, category: .log)
            }
        } catch {
            print("[QuickCapture] 保存记录失败: \(error)")
            return "保存失败，请重试"
        }
        // 保存后立即关闭（PRD §14）；草稿清除，关闭路径不再回存
        draftStore.clear()
        saveDraftOnClose = false
        panel?.close()
        return nil
    }

    private func cancel(text: String, category: Category) {
        persistDraft(text: text, category: category)
        saveDraftOnClose = false // 已在此处持久化，关闭路径不重复写
        panel?.close()
    }

    /// 失焦 / 再次按热键 / 面板被系统关闭：未提交则保留草稿（PRD §14 自动保存草稿）
    private func dismissWithoutCommit() {
        if saveDraftOnClose {
            persistDraft(text: currentDraft.text, category: currentDraft.category)
        }
        panel?.close()
    }

    private func persistDraft(text: String, category: Category) {
        if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            draftStore.clear()
        } else {
            draftStore.save(QuickCaptureDraft(text: text, category: category))
        }
    }

    // MARK: - 面板

    private func makePanel() -> QuickCapturePanel {
        let panel = QuickCapturePanel(
            contentRect: NSRect(x: 0, y: 0, width: 440, height: 260),
            styleMask: [.titled, .closable, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered, defer: false)
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        panel.isReleasedWhenClosed = false
        // 窗口透明、内容自带玻璃卡（Spotlight 风格悬浮层）
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        // 隐藏标准红绿灯：视觉由内容承载，关闭走 Esc/Cancel
        panel.standardWindowButton(.closeButton)?.isHidden = true
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true
        panel.onResignKey = { [weak self] in
            self?.dismissWithoutCommit()
        }
        return panel
    }

    /// 定位到鼠标所在屏：水平居中、垂直略高于中心（Spotlight 风格）
    private func positionPanel(_ panel: NSPanel) {
        let mouse = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { NSMouseInRect(mouse, $0.frame, false) })
                ?? NSScreen.main else {
            panel.center()
            return
        }
        let size = panel.frame.size
        let visible = screen.visibleFrame
        panel.setFrameOrigin(CGPoint(
            x: visible.midX - size.width / 2,
            y: visible.midY - size.height / 2 + visible.height * 0.15))
    }
}

/// 非激活样式浮动面板：不抢「主窗口 key 状态以外的激活逻辑」——
/// 获焦输入是预期行为（NSNonactivatingPanelMask 语义：成为 key 接收键盘输入但不激活 App）。
private final class QuickCapturePanel: NSPanel {
    /// 失焦即关闭（控制器回调，草稿在回调内持久化）
    var onResignKey: (() -> Void)?

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func resignKey() {
        super.resignKey()
        onResignKey?()
    }
}

// ThemeMode.colorScheme 已移入 FlashKit（FlashDesign/Theme/ThemeMode+ColorScheme.swift），与 iOS 共用

