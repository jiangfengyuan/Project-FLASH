// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import SwiftUI
import UIKit
import FlashDesign

/// 离开前台时用纸面遮住窗口，系统存下的多任务快照里不出现日志、情绪或任务正文（对齐 Android
/// `setRecentsScreenshotEnabled(false)`）。用独立的高层级窗口而不是根视图 overlay：
/// 快速记录、搜索等 sheet 在根视图之上，overlay 遮不住。不拦截截屏。
@MainActor
final class PrivacyShield {
    static let shared = PrivacyShield()

    private var covers: [ObjectIdentifier: UIWindow] = [:]

    func update(isActive: Bool) {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        if isActive {
            covers.values.forEach { $0.isHidden = true }
            covers.removeAll()
            return
        }
        for scene in scenes where covers[ObjectIdentifier(scene)] == nil {
            let window = UIWindow(windowScene: scene)
            window.windowLevel = .alert + 1
            window.rootViewController = UIHostingController(rootView: PrivacyCoverView())
            window.isHidden = false
            covers[ObjectIdentifier(scene)] = window
        }
    }
}

private struct PrivacyCoverView: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let dark = colorScheme == .dark
        ZStack {
            Color(hex: dark ? PaperPalette.pageBackground.dark : PaperPalette.pageBackground.light)
            Text(verbatim: "✦ Flash")
                .font(.system(.title, design: .serif, weight: .semibold))
                .foregroundStyle(Color(hex: dark ? PaperPalette.textPrimary.dark : PaperPalette.textPrimary.light))
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}
