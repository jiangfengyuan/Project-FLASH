// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import SwiftUI
import UIKit
import FlashDesign

/// 暖调手作主题的 UIKit 外观：系统导航栏标题改用随包展示字体与暖墨色。
/// 只设标题属性、不替换导航栏背景外观，保留系统玻璃 / 滚动边缘效果。
enum CraftedAppearance {
    static func apply() {
        let ink = UIColor { traits in
            UIColor(Color(hex: traits.userInterfaceStyle == .dark
                          ? WarmPalette.textPrimary.dark : WarmPalette.textPrimary.light))
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
        let base = UIFont(name: Typography.displayFontName, size: size)
            ?? .systemFont(ofSize: size, weight: .bold)
        return UIFontMetrics(forTextStyle: textStyle).scaledFont(for: base)
    }
}
