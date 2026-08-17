import SwiftUI

/// 侧栏：分区 + 自定义行。
/// 选中胶囊用 matchedGeometryEffect 随 Motion.spring 平滑滑动；hover 行高亮走
/// Motion.quick；选中图标极轻 bounce。所有动效尊重 Reduce Motion。
struct Sidebar: View {
    @Environment(AppState.self) private var appState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var selectionNamespace

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 2) {
                sectionHeader("记录")
                row(.home)
                row(.explore)
                row(.logflow)
                row(.emotion)

                Spacer().frame(height: 20)

                sectionHeader("回顾")
                row(.calendar)
                row(.stats)

                Spacer().frame(height: 20)

                row(.settings)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
        }
        .navigationTitle("Flash")
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.callout)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 10)
            .padding(.bottom, 4)
    }

    private func row(_ module: Module) -> some View {
        SidebarRow(
            module: module,
            isSelected: appState.selectedModule == module,
            selectionNamespace: selectionNamespace,
            reduceMotion: reduceMotion
        ) {
            Motion.animate(Motion.spring(), reduceMotion: reduceMotion) {
                appState.selectedModule = module
            }
        }
    }
}

/// 侧栏行：图标 + 标题；选中时胶囊背景（跟随 accent 色）与图标 bounce，hover 时轻高亮。
private struct SidebarRow: View {
    let module: Module
    let isSelected: Bool
    let selectionNamespace: Namespace.ID
    let reduceMotion: Bool
    let onSelect: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 8) {
                Image(systemName: module.systemImage)
                    .font(.system(size: 14))
                    .frame(width: 20, alignment: .center)
                    // 选中图标极轻 bounce（减弱动态时关闭）
                    .scaleEffect(isSelected && !reduceMotion ? 1.06 : 1)
                    .animation(Motion.bounce(reduceMotion), value: isSelected)
                Text(module.title)
                    .font(.system(size: 13))
                Spacer()
            }
            .foregroundStyle(isSelected ? Color.white : .primary)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(BrandColors.accent)
                        .matchedGeometryEffect(id: "selection", in: selectionNamespace)
                } else {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.primary.opacity(hovering ? 0.07 : 0))
                }
            }
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .animation(Motion.quick(reduceMotion), value: hovering)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}
