// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import SwiftUI
import FlashCore

/// 应用锁的遮挡页：纸面 + 解锁按钮。不显示任何记录内容。
/// `onQuickCapture` 非 nil 时提供「快速记录」：锁定时也能只写不读。
public struct AppLockScreen: View {
    @Environment(AppLockController.self) private var lock
    private let onQuickCapture: (() -> Void)?

    public init(onQuickCapture: (() -> Void)? = nil) {
        self.onQuickCapture = onQuickCapture
    }

    public var body: some View {
        VStack(spacing: Spacing.lg) {
            Spacer()
            Image(systemName: "lock.fill")
                .font(.system(size: 34, weight: .regular))
                .foregroundStyle(BrandColors.textSecondary)
                .accessibilityHidden(true)
            VStack(spacing: Spacing.xs) {
                Text(verbatim: "✦ Flash")
                    .font(.system(.title, design: .serif, weight: .semibold))
                    .foregroundStyle(BrandColors.textPrimary)
                Text("Flash 已锁定")
                    .font(.body)
                    .foregroundStyle(BrandColors.textSecondary)
                if lock.lastAttemptFailed {
                    Text("未能验证身份，请重试")
                        .font(Typography.caption)
                        .foregroundStyle(BrandColors.destructive)
                }
            }
            .multilineTextAlignment(.center)
            Button {
                Task { await lock.unlock(reason: L("解锁 Flash 以查看你的记录")) }
            } label: {
                Text("解锁")
                    .frame(minWidth: 160)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(BrandColors.brandPrimary)
            .disabled(lock.isAuthenticating)
            .keyboardShortcut(.defaultAction)
            if let onQuickCapture {
                Button(action: onQuickCapture) {
                    Label(L("快速记录"), systemImage: "square.and.pencil")
                }
                .buttonStyle(.borderless)
                .tint(BrandColors.brandPrimary)
            }
            Spacer()
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .flashPageBackground()
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
    }
}

/// 设置页「隐私」里的应用锁开关。开、关都先验证一次：开启时确认此刻能解开，避免把自己锁在门外；
/// 关闭时防止拿到已解锁设备的人顺手关掉。设备没设密码时不允许开启（关闭总是允许）。
public struct AppLockToggleRow: View {
    @EnvironmentObject private var settings: SettingsStore
    @Environment(AppLockController.self) private var lock
    @State private var verifying = false
    @State private var refusal: String? = nil

    public init() {}

    public var body: some View {
        Toggle(isOn: Binding(get: { settings.appLockEnabled },
                             set: { newValue in Task { await change(to: newValue) } })) {
            SettingsRowLabel(title: L("应用锁"), systemImage: "lock", color: BrandColors.accessibleGreen)
        }
        .tint(BrandColors.brandPrimary)
        .disabled(verifying)
        .alert(refusal ?? "", isPresented: Binding(get: { refusal != nil }, set: { if !$0 { refusal = nil } })) {
            Button("好") { refusal = nil }
        }
    }

    private func change(to enabled: Bool) async {
        guard enabled != settings.appLockEnabled, !verifying else { return }
        verifying = true
        defer { verifying = false }
        let reason = enabled ? L("验证身份以开启应用锁") : L("验证身份以关闭应用锁")
        switch await lock.verifyToggle(reason: reason) {
        case nil:
            apply(enabled)
        case .unavailable:
            if enabled {
                refusal = L("此设备未设置锁屏密码，无法开启应用锁")
            } else {
                apply(false)
            }
        case .failed:
            refusal = L("未能验证身份，设置未更改")
        case .cancelled, .busy:
            break
        }
    }

    private func apply(_ enabled: Bool) {
        settings.setAppLockEnabled(enabled)
        lock.settingChanged(enabled: enabled)
    }
}
