import FlashCore
import SwiftUI

/// The detail sheet has an explicit save boundary; opening it never writes tags.
public struct RecordTagsEditor: View {
  @Environment(\.flashRepository) private var repository
  public let recordKey: String
  @State private var draft = TagDraft()
  @State private var text = ""
  @State private var error: String?
  public init(recordKey: String) { self.recordKey = recordKey }
  public var body: some View {
    VStack(alignment: .leading, spacing: Spacing.sm) {
      DraftTagsEditor(draft: $draft, text: text)
      Button(L("保存标签")) {
        do {
          try repository?.saveTagDraft(draft, key: recordKey)
          error = nil
        } catch { self.error = (error as? BackupError)?.userMessage ?? error.localizedDescription }
      }
      if let error { Text(error).foregroundStyle(BrandColors.destructive) }
    }
    .task {
      do {
        draft = try repository?.tagDraft(for: recordKey) ?? .init()
        text = try repository?.textForRecord(recordKey) ?? ""
      } catch { self.error = error.localizedDescription }
    }
  }
}
