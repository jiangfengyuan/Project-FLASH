import Foundation

/// 对应 PRD 的 emoji 情绪模型：😍😊🙂😐😔😣😡（3→-3）
/// 纯数据模型：仅保存 hex 色值字符串，SwiftUI Color 换算见 Theme/ModelColors.swift（A4）。
enum EmotionLevel: Int, CaseIterable, Codable {
    case veryUnhappy = -3
    case unhappy = -2
    case slightlyUnhappy = -1
    case neutral = 0
    case slightlyHappy = 1
    case happy = 2
    case veryHappy = 3

    var displayName: String {
        switch self {
        case .veryUnhappy: "非常不开心"
        case .unhappy: "很不开心"
        case .slightlyUnhappy: "不开心"
        case .neutral: "中性"
        case .slightlyHappy: "开心"
        case .happy: "很开心"
        case .veryHappy: "非常开心"
        }
    }

    /// light 外观色值
    var colorHex: String {
        switch self {
        case .veryUnhappy: "#800080"
        case .unhappy: "#DDA0DD"
        case .slightlyUnhappy: "#B0C4DE"
        case .neutral: "#B0E0E6"
        case .slightlyHappy: "#90EE90"
        case .happy: "#F0D878"
        case .veryHappy: "#FFB347"
        }
    }

    /// dark 外观色值
    var darkColorHex: String {
        switch self {
        case .veryUnhappy: "#B266B2"
        case .unhappy: "#E2B0E2"
        case .slightlyUnhappy: "#A9BCD6"
        case .neutral: "#A8D2D8"
        case .slightlyHappy: "#7FCC7F"
        case .happy: "#E8CD6B"
        case .veryHappy: "#F5A83C"
        }
    }

    var emoji: String {
        switch self {
        case .veryUnhappy: "😡"
        case .unhappy: "😣"
        case .slightlyUnhappy: "😔"
        case .neutral: "😐"
        case .slightlyHappy: "🙂"
        case .happy: "😊"
        case .veryHappy: "😍"
        }
    }

    var isNegative: Bool { rawValue < 0 }
}
