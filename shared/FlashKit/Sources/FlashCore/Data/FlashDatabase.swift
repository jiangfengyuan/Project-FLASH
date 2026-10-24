// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import SwiftData

public enum FlashDatabase: Sendable {
    /// 容器创建结果。didFallbackToMemory 为 true 表示持久化容器创建失败、
    /// 已降级为内存容器（App 可用但数据不持久），调用方可据此提示用户。
    public struct ContainerResult: Sendable {
        public let container: ModelContainer
        public let didFallbackToMemory: Bool

        public init(container: ModelContainer, didFallbackToMemory: Bool) {
            self.container = container
            self.didFallbackToMemory = didFallbackToMemory
        }
    }

    /// 持久化容器创建失败时降级为内存容器，不再 fatalError 导致启动即崩。
    /// 版本化 schema + 迁移计划：V1→V2 轻量迁移（纯增可选列，见 Entities.swift）
    public static func makeContainer(inMemory: Bool = false) -> ModelContainer {
        makeContainerWithFallback(inMemory: inMemory).container
    }

    public static func makeContainerWithFallback(inMemory: Bool = false) -> ContainerResult {
        let schema = Schema(versionedSchema: FlashSchemaV2.self)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory)
        do {
            return ContainerResult(container: try ModelContainer(for: schema,
                                                                 migrationPlan: FlashMigrationPlan.self,
                                                                 configurations: [config]),
                                   didFallbackToMemory: false)
        } catch {
            print("SwiftData 容器创建失败，尝试降级为内存容器: \(error)")
            let memoryConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            if let fallback = try? ModelContainer(for: schema, configurations: [memoryConfig]) {
                print("已降级为内存容器：本次运行数据不会持久化")
                return ContainerResult(container: fallback, didFallbackToMemory: true)
            }
            fatalError("无法创建 SwiftData 容器（内存降级亦失败）: \(error)")
        }
    }
}
