import SwiftUI

enum SubEmotion: String, CaseIterable, Codable {
    case sad, angry, uncomfortable

    var displayName: String {
        switch self {
        case .sad: "伤心"
        case .angry: "生气"
        case .uncomfortable: "难受"
        }
    }

    /// light 外观色值
    var colorHex: String {
        switch self {
        case .sad: "#A78BFA"
        case .angry: "#F87171"
        case .uncomfortable: "#FB923C"
        }
    }

    /// dark 外观色值
    var darkColorHex: String {
        switch self {
        case .sad: "#BFA2FC"
        case .angry: "#FA9292"
        case .uncomfortable: "#FCA763"
        }
    }

    /// 跟随系统外观的动态色（light/dark 双变体）
    var color: Color { BrandColors.dynamic(light: colorHex, dark: darkColorHex) }
}
