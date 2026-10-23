// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import SwiftUI
import FlashCore

/// 局域网收发面板（macOS 设置页 sheet 与 iOS 设置页 sheet 共用）：
/// 发送方展示六位 PIN；接收方选设备、输入 PIN 后配对接收；连接中显示进度。
/// 状态全部在共享的 LocalBackupTransferController，面板只做呈现与输入。
public struct LanTransferSheet: View {
    @Bindable public var controller: LocalBackupTransferController

    public init(controller: LocalBackupTransferController) {
        self.controller = controller
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            switch controller.mode {
            case .sending:
                Text("等待接收设备").font(Typography.sectionTitle)
                Text("在另一台设备选择“局域网接收”，然后输入配对 PIN：")
                Text(controller.pin)
                    .scaledSystemFont(size: 48, weight: .semibold, design: .rounded, relativeTo: .largeTitle)
                    .foregroundStyle(.tint)
                    .textSelection(.enabled)
                Text("PIN 仅本次有效，60 秒后自动失效。")
                    .font(Typography.caption).foregroundStyle(.secondary)
                Button("取消发送") { controller.cancel() }

            case .receiving:
                Text("从局域网接收").font(Typography.sectionTitle)
                if controller.devices.isEmpty {
                    HStack { ProgressView(); Text("正在查找附近的 Flash Aero…") }
                } else {
                    Text("选择发送设备：")
                    ForEach(controller.devices) { device in
                        Button {
                            controller.selectedDevice = device
                        } label: {
                            HStack {
                                Image(systemName: controller.selectedDevice == device ? "checkmark.circle.fill" : "circle")
                                Text(device.name)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                TextField("六位配对 PIN", text: $controller.enteredPIN)
                    .textFieldStyle(.roundedBorder)
                    #if os(iOS)
                    .keyboardType(.numberPad)
                    #endif
                    .onChange(of: controller.enteredPIN) { _, value in
                        controller.enteredPIN = String(value.filter(\.isNumber).prefix(6))
                    }
                HStack {
                    Button("取消") { controller.cancel() }
                    Spacer()
                    Button("配对并接收") { controller.connect() }
                        .buttonStyle(.borderedProminent)
                        .disabled(controller.selectedDevice == nil || controller.enteredPIN.count != 6)
                }

            case .connecting:
                Text("正在配对").font(Typography.sectionTitle)
                HStack { ProgressView(); Text("正在验证 PIN 并接收备份…") }
                Button("取消") { controller.cancel() }

            case .idle:
                EmptyView()
            }
            Divider()
            Text("备份内容未做端到端加密，请仅在可信的家庭或办公局域网使用。")
                .font(Typography.caption)
                .foregroundStyle(.secondary)
        }
        .padding(Spacing.lg)
        .flashPanelWidth(420) // 传输面板固有宽度（几何值，仅 macOS）
    }
}
