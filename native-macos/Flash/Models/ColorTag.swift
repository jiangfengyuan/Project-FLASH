import SwiftUI

/// 与 Web 版 src/lib/constants.ts 对齐。rawValue 即 storageKey，保证三端数据互通。
enum ColorTag: String, CaseIterable, Codable {
    case urgent, inspiration, daily, memo, emotion, idea

    var displayName: String {
        switch self {
        case .urgent: "紧急"
        case .inspiration: "灵感"
        case .daily: "日常"
        case .memo: "备忘"
        case .emotion: "情绪"
        case .idea: "想法"
        }
    }

    /// light 外观色值（与 Web/Android 互通的存储色）
    var colorHex: String {
        switch self {
        case .urgent: "#FF6B6B"
        case .inspiration: "#FFD93D"
        case .daily: "#4D96FF"
        case .memo: "#6BCB77"
        case .emotion: "#9B59B6"
        case .idea: "#FF9F43"
        }
    }

    /// dark 外观色值
    var darkColorHex: String {
        switch self {
        case .urgent: "#FF8585"
        case .inspiration: "#C9A227"
        case .daily: "#6BA8FF"
        case .memo: "#82D18E"
        case .emotion: "#B578D1"
        case .idea: "#FFB268"
        }
    }

    /// 跟随系统外观的动态色（light/dark 双变体）
    var color: Color { BrandColors.dynamic(light: colorHex, dark: darkColorHex) }
}
