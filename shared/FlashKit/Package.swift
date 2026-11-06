// swift-tools-version: 6.0
// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import PackageDescription

/// macOS 与 iOS 共用的数据层与设计语言。
/// - FlashCore：模型、SwiftData 实体与仓储、备份/LAN、领域纯函数、展示层 ViewModel
/// - FlashDesign：设计令牌、动效、品牌色与共用 SwiftUI 组件
let package = Package(
    name: "FlashKit",
    platforms: [.macOS(.v15), .iOS(.v18)],
    products: [
        .library(name: "FlashCore", targets: ["FlashCore"]),
        .library(name: "FlashDesign", targets: ["FlashDesign"]),
    ],
    targets: [
        .target(name: "FlashCore"),
        .target(name: "FlashDesign", dependencies: ["FlashCore"]),
        .testTarget(name: "FlashCoreTests", dependencies: ["FlashCore"]),
        .testTarget(name: "FlashDesignTests", dependencies: ["FlashDesign", "FlashCore"]),
    ]
)
