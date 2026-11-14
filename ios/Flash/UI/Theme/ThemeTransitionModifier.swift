import FlashCore
import SwiftUI
import UIKit

/// Animate the window's native appearance so sheets, bars and paper surfaces
/// change together. UIKit owns the ephemeral transition; no screen image is kept.
struct ThemeTransitionModifier: ViewModifier {
  let mode: ThemeMode
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  func body(content: Content) -> some View {
    content.background(
      AppearanceBridge(mode: mode, reduceMotion: reduceMotion).frame(width: 0, height: 0))
  }
}

private struct AppearanceBridge: UIViewRepresentable {
  let mode: ThemeMode
  let reduceMotion: Bool
  func makeUIView(context: Context) -> UIView { UIView() }
  func updateUIView(_ view: UIView, context: Context) {
    let style: UIUserInterfaceStyle =
      mode.colorScheme.map { $0 == .dark ? .dark : .light } ?? .unspecified
    DispatchQueue.main.async {
      guard let window = view.window else { return }
      defer { context.coordinator.firstUpdate = false }
      guard window.overrideUserInterfaceStyle != style else { return }
      let changes = { window.overrideUserInterfaceStyle = style }
      if reduceMotion || context.coordinator.firstUpdate {
        UIView.performWithoutAnimation(changes)
      } else {
        UIView.transition(
          with: window, duration: 0.22, options: [.transitionCrossDissolve, .allowAnimatedContent],
          animations: changes)
      }
    }
  }
  func makeCoordinator() -> Coordinator { Coordinator() }
  final class Coordinator { var firstUpdate = true }
}
