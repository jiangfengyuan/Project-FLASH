import Foundation
import SwiftData

enum FlashDatabase {
    static func makeContainer(inMemory: Bool = false) -> ModelContainer {
        let schema = Schema([LogEntity.self, EmotionEntity.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("无法创建 SwiftData 容器: \(error)")
        }
    }
}
