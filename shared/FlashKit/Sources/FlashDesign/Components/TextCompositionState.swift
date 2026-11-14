#if os(iOS)
  import UIKit
#elseif os(macOS)
  import AppKit
#endif

/// Wait for marked text to commit before analyzing a draft (including Chinese IME).
@MainActor enum TextCompositionState {
  static var isComposing: Bool {
    #if os(iOS)
      func containsMarkedResponder(_ view: UIView) -> Bool {
        if view.isFirstResponder, let input = view as? any UITextInput {
          return input.markedTextRange != nil
        }
        return view.subviews.contains(where: containsMarkedResponder)
      }
      return UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        .flatMap(\.windows).contains(where: containsMarkedResponder)
    #elseif os(macOS)
      return (NSApp.keyWindow?.firstResponder as? NSTextView)?.hasMarkedText() ?? false
    #else
      return false
    #endif
  }
}
