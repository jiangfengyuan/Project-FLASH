// Copyright (c) 2026 Fengyuan Jiang · MPL-2.0
import SwiftUI
import FlashCore

/// Both endpoints actively confirm the same library-generated decimal groups.
public struct LanTransferSheet: View {
    @Bindable public var controller: LocalBackupTransferController
    public init(controller: LocalBackupTransferController) { self.controller = controller }
    public var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            switch controller.phase {
            case .confirming, .waitingForPeer:
                Text("核对两端短码").font(Typography.sectionTitle)
                Text("请当面或通过可信通话核对两台设备上的三组数字，全部一致后，两端都要点确认。")
                Text(controller.shortCode.map { String(format: "%04d", $0) }.joined(separator: "  "))
                    .scaledSystemFont(size: 32, weight: .semibold, design: .monospaced, relativeTo: .largeTitle)
                    .accessibilityLabel(controller.shortCode.map { String(format: "%04d", $0) }.joined(separator: "，"))
                if controller.phase == .waitingForPeer {
                    HStack { ProgressView(); Text("已确认，等待另一端确认…") }
                } else {
                    Button("三组数字全部一致") { controller.confirmMatch() }.buttonStyle(.borderedProminent)
                }
                Button("不一致，拒绝传输", role: .destructive) { controller.reject() }
                Text("60 秒内完成核对；未双向确认前不会生成或发送备份。")
                    .font(Typography.caption).foregroundStyle(.secondary)
            case .waiting:
                Text("等待接收设备").font(Typography.sectionTitle)
                Text("在同一局域网的另一台设备选择“局域网接收”，选中本次 Flash 服务。设备名称仅供发现，连接后仍需核对短码。")
                HStack { ProgressView(); Text("本次开启窗口为 120 秒") }
            case .discovering:
                Text("选择发送设备").font(Typography.sectionTitle)
                if controller.devices.isEmpty {
                    HStack { ProgressView(); Text("正在查找安全 LAN v2 服务…") }
                }
                ForEach(controller.devices) { device in
                    Button { controller.selectedDevice = device } label: {
                        HStack {
                            Image(systemName: controller.selectedDevice == device ? "checkmark.circle.fill" : "circle")
                            Text(device.name)
                        }
                    }.buttonStyle(.plain)
                }
                Button("连接并核对短码") { controller.connect() }
                    .buttonStyle(.borderedProminent).disabled(controller.selectedDevice == nil)
            case .handshake:
                Text("正在建立安全连接").font(Typography.sectionTitle)
                ProgressView()
            case .transferring:
                Text("正在加密传输备份").font(Typography.sectionTitle)
                ProgressView()
            case .verifying:
                Text("正在完整校验备份").font(Typography.sectionTitle)
                Text("校验通过后进入导入预览，仍需选择合并或覆盖。")
                ProgressView()
            case .completed: Text("传输完成，导入需另行确认")
            case .failed: Text("传输未完成，请重新发起")
            case .idle: EmptyView()
            }
            Button("取消") { controller.cancel() }
            Divider()
            Text("仅支持安全 LAN v2，不兼容旧版 LAN。传输完成不代表已导入。")
                .font(Typography.caption).foregroundStyle(.secondary)
        }
        .padding(Spacing.lg)
        .flashPanelWidth(420)
    }
}
