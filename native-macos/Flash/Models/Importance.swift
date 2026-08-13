import Foundation

/// 与 Web 版 getImportanceFromContent 对齐：从内容中的 !! 标记推断重要度
func importanceFromContent(_ content: String) -> Int {
    if content.contains("!!!!") { return 4 }
    if content.contains("!!!") { return 3 }
    if content.contains("!!") { return 2 }
    return 0
}
