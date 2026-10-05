// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

/// body 求值期 memo 化缓存：key 与上次相等时直接返回缓存值，key 变化才执行 compute。
/// 用于把「全表实体→模型映射 + 聚合/过滤」从每次 body 求值（文本框按键、动画状态
/// 翻转等都会触发）降为每次输入变化一次，同时保留首帧同步计算（无前瞻空窗）。
/// 引用类型，配合 @State 持有（与 HomeViewModel 同一模式）；只在主线程视图求值链中使用。
final class ViewComputeCache<Key: Equatable, Value> {
    private var lastKey: Key?
    private var lastValue: Value?

    /// key 未变化时返回上次结果；否则执行 compute 并更新缓存
    func value(for key: Key, compute: () -> Value) -> Value {
        if let lastKey, lastKey == key, let lastValue {
            return lastValue
        }
        let value = compute()
        lastKey = key
        lastValue = value
        return value
    }
}
