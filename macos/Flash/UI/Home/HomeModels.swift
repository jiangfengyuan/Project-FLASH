import Foundation

/// Home 仪表盘模块枚举（Task 暂无独立实体，仅作展示预留）
enum HomeModule { case log, idea, task, emotion }

/// 「最近动态」时间线条目（由 Log/Emotion 合并而来）
struct ActivityEntry: Identifiable, Equatable {
    let id: String
    let time: String      // "HH:mm"
    let module: HomeModule
    let title: String
    let tag: String?      // 如 #工作，可为 nil
}
