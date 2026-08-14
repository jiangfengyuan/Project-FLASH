import Foundation

struct EmotionRecord: Identifiable, Equatable {
    let id: String
    var level: EmotionLevel
    var subEmotion: SubEmotion?
    var status: String?
    var note: String?
    var recordDate: String  // yyyy-MM-dd
    var createdAt: String   // ISO-8601
}
