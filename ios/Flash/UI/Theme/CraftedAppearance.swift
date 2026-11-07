// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import SwiftUI
import UIKit
import FlashDesign

/// 纸上书写的 UIKit 外观：系统导航栏标题改用展示字体与炭墨色。
/// 只设标题属性、不替换导航栏背景外观，保留系统玻璃 / 滚动边缘效果。
enum CraftedAppearance {
    static func apply() {
        let ink = UIColor { traits in
            UIColor(Color(hex: traits.userInterfaceStyle == .dark
                          ? PaperPalette.textPrimary.dark : PaperPalette.textPrimary.light))
        }
        let bar = UINavigationBar.appearance()
        bar.titleTextAttributes = [
            .font: displayFont(size: 17, textStyle: .headline),
            .foregroundColor: ink,
        ]
        bar.largeTitleTextAttributes = [
            .font: displayFont(size: 34, textStyle: .largeTitle),
            .foregroundColor: ink,
        ]
    }

    /// 随系统字体档位缩放；字体缺失（未打包）时回退系统粗体
    private static func displayFont(size: CGFloat, textStyle: UIFont.TextStyle) -> UIFont {
        let system = UIFont.systemFont(ofSize: size, weight: .semibold)
        let serif = system.fontDescriptor.withDesign(.serif).map { UIFont(descriptor: $0, size: size) } ?? system
        let base = Typography.usesBundledDisplayFont
            ? (UIFont(name: Typography.displayFontName, size: size) ?? serif)
            : serif
        return UIFontMetrics(forTextStyle: textStyle).scaledFont(for: base)
    }
}
