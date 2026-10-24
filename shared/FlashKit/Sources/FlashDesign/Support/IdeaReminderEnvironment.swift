// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import SwiftUI

/// 「标记灵感已读」动作：包成结构体放进环境（裸闭包无法比较，每次更新都会让依赖视图失效）。
/// 相等性恒为 true：动作只是转发给宿主，换实例不应触发重绘。
public struct FlashMarkIdeaViewedAction: Equatable {
    private let handler: (String) -> Void

    public init(_ handler: @escaping (String) -> Void) {
        self.handler = handler
    }

    public func callAsFunction(_ ideaID: String) {
        handler(ideaID)
    }

    public static func == (lhs: Self, rhs: Self) -> Bool { true }
}

/// 灵感提醒（未读灵感）在共享视图中的接入点：宿主 App 注入未读 id 集与「标记已读」动作，
/// 共享列表据此显示「未读」并在打开灵感时回调。未注入时为空集 / nil，行为与之前一致。
public extension EnvironmentValues {
    @Entry var flashUnreadIdeaIDs: Set<String> = []
    @Entry var flashMarkIdeaViewed: FlashMarkIdeaViewedAction? = nil
}
