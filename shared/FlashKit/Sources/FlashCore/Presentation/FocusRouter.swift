// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Observation

/// 跨模块定位目标（全局搜索跳转 / 日历「查看灵感」/ 通知与小组件深链）。
public enum FocusDestination: Equatable, Sendable {
    /// 记录/灵感：记录页打开该记录的编辑弹层
    case log(String)
    /// 情绪：仅切到情绪页
    case emotion
    /// 任务：日历页选中并翻到该日历日（yyyy-MM-dd；nil = 仅切页）
    case task(String?)
}

/// 跨模块定位路由（token + 载荷，macOS 与 iOS 共用的消费语义）：
/// - `request` 先经 `onRequest` 让宿主切换模块/Tab，再发 token；
/// - 目标页在 onAppear 兜底 + onChange(requestToken) 时调用 `consume()`，每个 token 只交付一次；
/// - 无论载荷是否适用都标记已处理，避免不适用载荷滞留后被后续页面误消费。
/// handled token 存在路由上而非视图里，视图重建后不会回放旧请求。
/// 与宿主 AppState 同为非隔离的 @Observable 类，只在主线程（视图与命令回调）读写。
@Observable
public final class FocusRouter {
    public private(set) var requestToken = 0
    private var handledToken = 0
    private var pending: FocusDestination?
    /// 宿主（App 层 AppState）据目标切换模块/Tab；在发 token 之前调用
    @ObservationIgnored public var onRequest: ((FocusDestination) -> Void)?

    public init() {}

    public func request(_ destination: FocusDestination) {
        onRequest?(destination)
        pending = destination
        requestToken += 1
    }

    /// 只交付符合条件的目标：不符合时不标记已处理，留给对应页面消费。
    /// 多个页面同时存活（iOS 各 Tab 常驻）时必须用此方法，避免误吞别的页面的定位请求。
    public func consume(matching predicate: (FocusDestination) -> Bool) -> FocusDestination? {
        guard requestToken != handledToken, let pending, predicate(pending) else { return nil }
        return consume()
    }

    @discardableResult
    public func consume() -> FocusDestination? {
        guard requestToken != handledToken else { return nil }
        handledToken = requestToken
        defer { pending = nil }
        return pending
    }
}
