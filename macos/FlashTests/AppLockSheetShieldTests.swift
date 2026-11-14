import AppKit
import Testing
import FlashCore
@testable import Flash

private struct CancelledAuthenticator: AppLockAuthenticating {
    func availability() -> AppLockAvailability { .available }
    func authenticate(reason: String) async -> AppLockAuthResult { .cancelled }
}

@MainActor @Suite(.serialized) struct AppLockSheetShieldTests {
    @Test func lockedSheetHidesAccessibilityAndRetainsUnsavedEditor() {
        let lock = AppLockController(isEnabled: { true }, authenticator: CancelledAuthenticator(), policy: .desktop)
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 400, height: 250),
                              styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        defer { window.close() }
        let field = NSTextField(string: "Synthetic unsaved text")
        let original = NSView(frame: NSRect(x: 0, y: 0, width: 400, height: 250))
        original.addSubview(field)
        window.contentView = original
        let button = NSButton(title: "Synthetic save", target: nil, action: nil)
        original.addSubview(button)
        button.keyEquivalent = "\r"
        window.defaultButtonCell = button.cell as? NSButtonCell
        #expect(window.defaultButtonCell != nil)
        let shield = SheetShield(window: window, lock: lock)
        #expect(original.isHidden)
        #expect(original.isAccessibilityHidden())
        #expect(window.defaultButtonCell?.isEnabled == false)
        #expect(window.firstResponder !== field)
        shield.restore()
        #expect(window.contentView === original)
        #expect(!original.isHidden)
        #expect(!original.isAccessibilityHidden())
        #expect(field.stringValue == "Synthetic unsaved text")
        #expect(window.defaultButtonCell?.isEnabled == true)
    }

    @Test func coordinatorUsesLiveLockAndRestoresToolbarAndSheet() {
        let lock = AppLockController(isEnabled: { true }, authenticator: CancelledAuthenticator(), policy: .desktop)
        let root = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 400, height: 250),
                            styleMask: [.titled], backing: .buffered, defer: false)
        let sheet = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 300, height: 200),
                             styleMask: [.titled], backing: .buffered, defer: false)
        root.isReleasedWhenClosed = false; sheet.isReleasedWhenClosed = false
        let toolbar = NSToolbar(identifier: "SyntheticLockTest")
        root.toolbar = toolbar; toolbar.isVisible = true
        let original = NSTextField(string: "Synthetic private sheet")
        sheet.contentView = original
        root.beginSheet(sheet)
        let coordinator = AppLockSheetShield.Coordinator(lock: lock)
        defer { coordinator.stop(); root.endSheet(sheet); sheet.close(); root.close() }
        // A stale SwiftUI argument must never override the current lock state.
        coordinator.update(isLocked: false, window: root)
        #expect(original.isHidden)
        #expect(original.isAccessibilityHidden())
        #expect(!toolbar.isVisible)
        lock.settingChanged(enabled: false)
        coordinator.update(isLocked: true, window: root)
        #expect(!original.isHidden)
        #expect(!original.isAccessibilityHidden())
        #expect(toolbar.isVisible)
        #expect(sheet.contentView === original)
    }
}
