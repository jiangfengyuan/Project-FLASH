// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import SwiftUI
import FlashCore
import FlashDesign

/// 设置子页面（iOS）：根页只留分类入口，重操作下沉到子页。
/// 子页只负责排版与回调，导出 / 导入 / 局域网的状态机与系统弹层仍由 SettingsScreen 统一持有。
enum SettingsPage: Hashable {
    case ideaReminder
    case backup
    case transfer
}

/// 灵感提醒子页：沿用 IdeaReminderSection（开关 + 频率 + 说明）
struct IdeaReminderSettingsPage: View {
    var body: some View {
        Form {
            Group {
                IdeaReminderSection()
            }
            // 纸上书写：分组行用纸白卡面
            .flashFormRowBackground()
        }
        .scrollContentBackground(.hidden)
        .flashPageBackground()
        .navigationTitle("灵感提醒")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// 内存降级提示分组：说明为何导出 / 导入 / 传输 / 清空暂不可用（F-07）
private struct TemporaryStoreSection: View {
    var body: some View {
        Section {
            Label {
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text("导出与导入已暂停")
                        .font(Typography.cardTitle)
                    Text("本地数据库暂时无法打开，这里只有本次启动后的临时内容，不是完整备份。原有数据仍在本机、未被改动；请完全退出 Flash 后重新打开。")
                        .font(Typography.caption)
                        .foregroundStyle(.secondary)
                }
            } icon: {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(BrandColors.destructive)
            }
        }
    }
}

/// 备份与恢复子页：导出（存到「文件」/ 系统分享）→ 导入（标准 / 恢复）→ 危险操作。
/// 临时存储（内存降级）时整页数据操作禁用并说明原因
struct BackupSettingsPage: View {
    let isTemporaryStore: Bool
    let isBusy: Bool
    let isClearDisabled: Bool
    let onExport: () -> Void
    let onShare: () -> Void
    let onImport: () -> Void
    let onRecoveryImport: () -> Void
    let onClearAll: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Form {
            Group {
                if isTemporaryStore {
                    TemporaryStoreSection()
                } else {
                    StorageBannerSection()
                }

                if isBusy {
                    Section {
                        HStack(spacing: Spacing.xs) {
                            ProgressView()
                            Text("正在处理…")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .transition(.appear(reduceMotion: reduceMotion))
                }

                Section {
                    Button(action: onExport) {
                        SettingsRowLabel(title: L("导出到「文件」…"), systemImage: "tray.and.arrow.up",
                                         color: BrandColors.brandPrimary)
                    }
                    Button(action: onShare) {
                        SettingsRowLabel(title: L("通过系统分享…"), systemImage: "square.and.arrow.up",
                                         color: BrandColors.accessibleGreen)
                    }
                } header: {
                    Text("导出")
                } footer: {
                    Text("备份为明文 JSON，可存到「文件」或用隔空投送发给自己的其他设备。")
                }
                .disabled(isBusy || isTemporaryStore)

                Section {
                    Button(action: onImport) {
                        SettingsRowLabel(title: L("从备份导入…"), systemImage: "tray.and.arrow.down",
                                         color: BrandColors.accessibleGreen)
                    }
                    Button(action: onRecoveryImport) {
                        SettingsRowLabel(title: L("恢复损坏或旧版备份…"), systemImage: "bandage",
                                         color: BrandColors.accessibleGreen)
                    }
                } header: {
                    Text("导入")
                } footer: {
                    Text("导入前会先显示差异预览，可选择按差异合并，或覆盖本机数据。恢复模式只读取原文件，不会修改它。")
                }
                .disabled(isBusy || isTemporaryStore)

                DangerZoneSection(isDisabled: isClearDisabled || isTemporaryStore, onClear: onClearAll)
            }
            // 纸上书写：分组行用纸白卡面
            .flashFormRowBackground()
        }
        .scrollContentBackground(.hidden)
        .flashPageBackground()
        .animation(Motion.soft(reduceMotion), value: isBusy)
        .navigationTitle("备份与恢复")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// 设备间传输子页：局域网发送 / 接收（配对流程在 LanTransferSheet）
struct TransferSettingsPage: View {
    let isTemporaryStore: Bool
    let isDisabled: Bool
    let onSend: () -> Void
    let onReceive: () -> Void

    var body: some View {
        Form {
            Group {
                if isTemporaryStore {
                    TemporaryStoreSection()
                }
                Section {
                    Button(action: onSend) {
                        SettingsRowLabel(title: L("发送到另一台设备…"), systemImage: "paperplane",
                                         color: BrandColors.accessibleGreen)
                    }
                    Button(action: onReceive) {
                        SettingsRowLabel(title: L("从另一台设备接收…"), systemImage: "antenna.radiowaves.left.and.right",
                                         color: BrandColors.accessibleGreen)
                    }
                } header: {
                    Text("局域网传输")
                } footer: {
                    Text("两台设备连接同一局域网，接收方输入发送方显示的配对 PIN 即可。备份内容未做端到端加密，请仅在可信的家庭或办公网络使用。")
                }
                .disabled(isDisabled || isTemporaryStore)
            }
            // 纸上书写：分组行用纸白卡面
            .flashFormRowBackground()
        }
        .scrollContentBackground(.hidden)
        .flashPageBackground()
        .navigationTitle("设备间传输")
        .navigationBarTitleDisplayMode(.inline)
    }
}
