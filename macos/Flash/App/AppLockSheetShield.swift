// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import AppKit
import SwiftUI
import FlashCore
import FlashDesign

/// 主窗口的 sheet 是独立 NSWindow，主窗口的 SwiftUI overlay 盖不到它们。
/// 只保护此主窗口的 sheet 子树；菜单栏与 Quick Capture 的独立窗口维持原政策。
struct AppLockSheetShield: NSViewRepresentable {
    let lock: AppLockController
    let isLocked: Bool

    func makeCoordinator() -> Coordinator { Coordinator(lock: lock) }

    func makeNSView(context: Context) -> WindowAnchor {
        let view = WindowAnchor()
        view.onWindowChanged = { [weak coordinator = context.coordinator] window in
            coordinator?.attach(to: window)
        }
        return view
    }

    func updateNSView(_ view: WindowAnchor, context: Context) {
        context.coordinator.update(isLocked: isLocked, window: view.window)
    }

    static func dismantleNSView(_ view: WindowAnchor, coordinator: Coordinator) {
        view.onWindowChanged = nil
        coordinator.stop()
    }

    final class WindowAnchor: NSView {
        var onWindowChanged: ((NSWindow?) -> Void)?
        override func hitTest(_ point: NSPoint) -> NSView? { nil }
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            onWindowChanged?(window)
        }
    }

    @MainActor final class Coordinator {
        private let lock: AppLockController
        private weak var window: NSWindow?
        private var tokens: [NSObjectProtocol] = []
        private var keyMonitor: Any?
        private weak var toolbar: NSToolbar?
        private var toolbarWasVisible: Bool?
        private var shields: [ObjectIdentifier: SheetShield] = [:]
        private var retiredShields: [SheetShield] = []

        init(lock: AppLockController) {
            self.lock = lock
            keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                let allowEvent: Bool = MainActor.assumeIsolated {
                    guard let self, self.lock.isLocked, let root = self.window,
                          let target = event.window else { return true }
                    var ancestor: NSWindow? = target
                    while let current = ancestor {
                        if current === root {
                            self.refresh()
                            // Native default cells and SwiftUI shortcuts remain registered
                            // while their owner is hidden. Intercept before action routing.
                            if event.keyCode == 36,
                               event.modifierFlags.intersection([.command, .control, .option, .shift]).isEmpty {
                                Task { await self.lock.unlock(reason: "解锁 Flash 以查看你的记录") }
                            }
                            return false
                        }
                        ancestor = current.sheetParent
                    }
                    return true
                }
                return allowEvent ? event : nil
            }
            let center = NotificationCenter.default
            // willBeginSheet precedes attachment; application updates also cover sheets
            // opened by an asynchronous operation that was already running at lock time.
            for name in [NSWindow.willBeginSheetNotification,
                         NSWindow.didEndSheetNotification,
                         NSWindow.didBecomeKeyNotification,
                         NSApplication.willUpdateNotification] {
                tokens.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                    MainActor.assumeIsolated { self?.refresh() }
                })
            }
        }

        func attach(to window: NSWindow?) {
            if self.window !== window {
                restoreAll()
                self.window = window
            }
            refresh()
        }

        func update(isLocked _: Bool, window: NSWindow?) {
            attach(to: window)
        }

        func stop() {
            restoreAll()
            tokens.forEach(NotificationCenter.default.removeObserver)
            tokens.removeAll()
            if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
            keyMonitor = nil
            window = nil
        }

        private func refresh() {
            guard lock.isLocked, let window else { restoreAll(); return }
            if toolbar !== window.toolbar {
                if let visible = toolbarWasVisible { toolbar?.isVisible = visible }
                toolbar = window.toolbar
                toolbarWasVisible = toolbar?.isVisible
            }
            toolbar?.isVisible = false
            let sheets = NSApp.windows.filter { candidate in
                var parent = candidate.sheetParent
                while let ancestor = parent {
                    if ancestor === window { return true }
                    parent = ancestor.sheetParent
                }
                return false
            }
            for sheet in sheets {
                let id = ObjectIdentifier(sheet)
                if let existing = shields[id], existing.matches(sheet) { continue }
                // Do not restore a replaced/closing surface while locked.
                if let prior = shields[id] { retiredShields.append(prior) }
                shields[id] = SheetShield(window: sheet, lock: lock)
            }
        }

        private func restoreAll() {
            shields.values.forEach { $0.restore() }
            shields.removeAll()
            retiredShields.reversed().forEach { $0.restore() }
            retiredShields.removeAll()
            if let visible = toolbarWasVisible { toolbar?.isVisible = visible }
            toolbar = nil
            toolbarWasVisible = nil
        }
    }
}

/// 保持原 contentView 在原层级，只隐藏它并加同级遮挡；不替换 hosting view，
/// 不触发 onDisappear/onAppear（记录编辑器 onAppear 会重读标签），保留全部草稿。
@MainActor final class SheetShield {
    private weak var content: NSView?
    private weak var window: NSWindow?
    private var orderedOut = false
    private let wasVisible: Bool
    private weak var defaultCell: NSButtonCell?
    private let defaultWasEnabled: Bool
    private let wasHidden: Bool
    private let wasAccessibilityHidden: Bool
    private let shield: LockHostingView
    private weak var previousResponder: NSResponder?

    private final class LockHostingView: NSHostingView<AnyView> {
        override var acceptsFirstResponder: Bool { true }
    }

    init(window: NSWindow, lock: AppLockController) {
        let content = window.contentView
        self.window = window
        self.content = content
        wasVisible = window.isVisible
        defaultCell = window.defaultButtonCell
        defaultWasEnabled = window.defaultButtonCell?.isEnabled ?? false
        window.defaultButtonCell?.isEnabled = false
        wasHidden = content?.isHidden ?? true
        wasAccessibilityHidden = content?.isAccessibilityHidden() ?? true
        shield = LockHostingView(rootView: AnyView(AppLockScreen().environment(lock)))
        previousResponder = window.firstResponder
        guard let content, let container = content.superview else {
            content?.setAccessibilityHidden(true)
            content?.isHidden = true
            orderedOut = true
            window.orderOut(nil)
            return
        }
        shield.frame = content.frame
        shield.autoresizingMask = [.width, .height]
        container.addSubview(shield, positioned: .above, relativeTo: content)
        // The former editor must not remain the keyboard/Copy action target.
        if !window.makeFirstResponder(shield) {
            window.endEditing(for: nil)
            guard window.makeFirstResponder(shield) else {
                content.setAccessibilityHidden(true)
                content.isHidden = true
                orderedOut = true
                window.orderOut(nil)
                return
            }
        }
        content.setAccessibilityHidden(true)
        content.isHidden = true
    }

    func matches(_ candidate: NSWindow) -> Bool {
        window === candidate && content === candidate.contentView
    }

    func restore() {
        content?.isHidden = wasHidden
        content?.setAccessibilityHidden(wasAccessibilityHidden)
        if let responder = previousResponder as? NSView,
           let window = content?.window, responder.window === window {
            window.makeFirstResponder(responder)
        }
        shield.removeFromSuperview()
        defaultCell?.isEnabled = defaultWasEnabled
        if orderedOut, wasVisible { window?.orderFront(nil) }
    }
}
