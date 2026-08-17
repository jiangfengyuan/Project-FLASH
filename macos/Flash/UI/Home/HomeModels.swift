// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

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
