// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import SwiftData
import SwiftUI

/// Repository 注入单一入口（债务 A6）。
///
/// 统一前：App 装配层自行创建容器与仓储，写路径读 Optional 环境值，
/// 读路径直取 SwiftData 环境（@Query），口径分散。
/// 统一后：容器创建（含内存降级回退）与仓储装配全部经
/// `RepositoryEnvironment.makeDefault()`；View 只读 `\.flashRepository`
/// 环境键（本文件是其唯一定义处）。
public enum RepositoryEnvironment: Sendable {
    /// 启动装配结果：容器与仓储共享同一 ModelContainer 实例
    public struct Assembly {
        /// 供 `.modelContainer(_:)` 挂载，驱动各视图的 @Query 读路径
        public let container: ModelContainer
        /// 写路径仓储（增删改、导入导出、清空）
        public let repository: FlashRepository
        /// true 表示持久化容器创建失败、已降级为内存容器（本次运行数据不持久，
        /// 应经 AppState.databaseFallbackMessage 提示用户）
        public let didFallbackToMemory: Bool

        public init(container: ModelContainer, repository: FlashRepository, didFallbackToMemory: Bool) {
            self.container = container
            self.repository = repository
            self.didFallbackToMemory = didFallbackToMemory
        }
    }

    /// 生产环境装配：创建持久化容器（失败自动降级内存）并装配仓储。
    /// App 装配层启动时调用一次即可。
    public static func makeDefault() -> Assembly {
        let result = FlashDatabase.makeContainerWithFallback()
        return Assembly(container: result.container,
                        repository: FlashRepository(container: result.container),
                        didFallbackToMemory: result.didFallbackToMemory)
    }
}

private struct FlashRepositoryKey: EnvironmentKey {
    nonisolated(unsafe) static let defaultValue: FlashRepository? = nil
}

extension EnvironmentValues {
    /// 写路径仓储的统一环境键。保持 Optional 以兼容现有 View：
    /// 未注入（预览/测试场景）时 View 侧自行降级（guard let 报错或 ?. 跳过写入）。
    public var flashRepository: FlashRepository? {
        get { self[FlashRepositoryKey.self] }
        set { self[FlashRepositoryKey.self] = newValue }
    }
}
