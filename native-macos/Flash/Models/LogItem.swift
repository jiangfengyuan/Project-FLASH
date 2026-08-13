import Foundation

struct LogItem: Identifiable, Equatable {
    let id: String
    var content: String
    var colorTag: ColorTag
    var category: Category
    var importance: Int
    var createdAt: String   // ISO-8601
    var recordDate: String  // yyyy-MM-dd
}
