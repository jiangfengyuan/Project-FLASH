import SwiftUI
import AppKit

/// 品牌/模块色。文本一律用 Color.primary/.secondary 语义色；
/// 这里的自定义色仅用于标签、情绪指示等点缀（spec §10.4）。
enum BrandColors {
    /// 跟随系统强调色（用户在系统设置改色后自动跟随）
    static let accent = Color(nsColor: .controlAccentColor)

    /// light/dark 双 hex 的动态色（spec §10.4 三变体中的前两个；
    /// 「增强对比度」由系统对语义色自动处理，自定义色保持简单）
    static func dynamic(light: String, dark: String) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return NSColor(Color(hex: isDark ? dark : light))
        })
    }

    static func tagColor(_ tag: ColorTag) -> Color { tag.color }

    static func emotionColor(_ level: EmotionLevel) -> Color { level.color }

    // MARK: - Home 仪表盘模块强调色（Aero PRD，低饱和柔和色）

    /// 日志模块：柔和紫
    static let logPurple = dynamic(light: "#8B7FD4", dark: "#A89FE0")

    /// 灵感模块：暖黄
    static let ideaYellow = dynamic(light: "#D9B36A", dark: "#E3C584")

    /// 任务模块：柔绿
    static let calendarGreen = dynamic(light: "#7FB38E", dark: "#93C6A3")

    /// 情绪模块：柔粉
    static let emotionPink = dynamic(light: "#D48FA8", dark: "#E0A7BC")

    static func moduleColor(_ module: HomeModule) -> Color {
        switch module {
        case .log: return logPurple
        case .idea: return ideaYellow
        case .task: return calendarGreen
        case .emotion: return emotionPink
        }
    }
}
