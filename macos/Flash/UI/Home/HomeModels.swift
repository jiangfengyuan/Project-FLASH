// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation

/// Home 仪表盘模块枚举（Task 暂无独立实体，仅作展示预留）
enum HomeModule { case log, idea, task, emotion }

/// 「今日概览」统计卡数据（纯展示，由 HomeViewModel 组装）。
/// id 取 module（各卡模块唯一）：stats 数组每次重算都整体重建，
/// 若用随机 UUID 会让 ForEach 身份不稳、卡片反复销毁重建。
struct OverviewStat: Identifiable {
    var id: HomeModule { module }
    let module: HomeModule
    let valueText: String   // 大号数字如 "03"，情绪卡为 emoji
    let title: String       // 副标题如 "Logs"，情绪卡为情绪名
    let trend: [Double]     // 底部迷你柱状图数据
}

/// 「最近动态」时间线条目（由 Log/Emotion 合并而来）
struct ActivityEntry: Identifiable, Equatable {
    let id: String
    let time: String      // "HH:mm"
    let module: HomeModule
    let title: String
    let tag: String?      // 如 #工作，可为 nil
}
