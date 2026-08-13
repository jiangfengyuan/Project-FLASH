import Foundation

enum SubEmotion: String, CaseIterable, Codable {
    case sad, angry, uncomfortable

    var displayName: String {
        switch self {
        case .sad: "伤心"
        case .angry: "生气"
        case .uncomfortable: "难受"
        }
    }

    var colorHex: String {
        switch self {
        case .sad: "#A78BFA"
        case .angry: "#F87171"
        case .uncomfortable: "#FB923C"
        }
    }
}
