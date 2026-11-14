import FlashCore
import SwiftUI

private struct TaggingAllowedKey: EnvironmentKey { static let defaultValue = true }
extension EnvironmentValues {
  public var flashTaggingAllowed: Bool {
    get { self[TaggingAllowedKey.self] }
    set { self[TaggingAllowedKey.self] = newValue }
  }
}
public struct DraftTagsEditor: View {
  @Environment(\.flashRepository) private var repository
  @Environment(\.flashTaggingAllowed) private var allowed
  @Binding var draft: TagDraft
  let text: String
  @State private var name = ""
  @State private var query = ""
  @State private var suggestions: [TagSuggestion] = []
  @State private var loading = false
  @State private var dismissed: Set<String> = []
  public init(draft: Binding<TagDraft>, text: String) {
    _draft = draft
    self.text = text
  }
  public var body: some View {
    VStack(alignment: .leading, spacing: Spacing.sm) {
      Text(L("自由标签")).font(Typography.blockTitle)
      if allowed {
        if loading { Text(L("正在找几个合适的标签…")).font(Typography.caption).foregroundStyle(.secondary) }
        if !suggestions.isEmpty {
          ScrollView(.horizontal, showsIndicators: false) {
            HStack {
              ForEach(suggestions, id: \.name) { suggestion in
                Button {
                  adopt(suggestion)
                } label: {
                  Label(
                    suggestion.name,
                    systemImage: draft.selected.contains(suggestion.existingID ?? "")
                      ? "checkmark" : "plus")
                }.buttonStyle(.bordered)
              }
            }
          }
        }
        if draft.catalog.count > 12 {
          TextField(L("输入关键词或标签"), text: $query).textFieldStyle(.roundedBorder)
        }
        LazyVGrid(
          columns: [GridItem(.adaptive(minimum: 100), alignment: .leading)], alignment: .leading,
          spacing: Spacing.xs
        ) {
          ForEach(visibleTags) { tag in
            Button {
              if draft.selected.contains(tag.id) {
                draft.selected.removeAll { $0 == tag.id }
                draft.automatic.removeAll { $0 == tag.id }
                dismissed.insert(tag.normalized)
              } else if draft.selected.count < 20 {
                draft.selected.append(tag.id)
                draft.automatic.removeAll { $0 == tag.id }
              }
            } label: {
              Label(tag.name, systemImage: draft.selected.contains(tag.id) ? "checkmark" : "plus")
                .frame(maxWidth: .infinity, alignment: .leading)
            }.buttonStyle(.bordered)
              .accessibilityAddTraits(draft.selected.contains(tag.id) ? .isSelected : [])
          }
        }
        HStack {
          TextField(L("新标签"), text: $name)
          Button(L("添加")) {
            adopt(TagSuggestion(name: name))
            name = ""
          }.disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
      }
    }
    .task(id: text + String(allowed)) {
      suggestions = []
      loading = false
      guard allowed, !text.isEmpty, !RecordTemplate.containsOnlyPrompts(text) else { return }
      do { try await Task.sleep(for: .milliseconds(700)) } catch { return }
      while TextCompositionState.isComposing {
        do { try await Task.sleep(for: .milliseconds(200)) } catch { return }
      }
      guard !Task.isCancelled else { return }
      loading = true
      let values = await TagRecommendationService.shared.suggestions(
        text: text, catalog: draft.catalog,
        locale: Bundle.main.preferredLocalizations.first ?? Locale.current.identifier)
      guard !Task.isCancelled else { return }
      suggestions = values
      loading = false
      if (try? repository?.preferences().taggingMode) == .existing {
        for value in values
        where value.existingID != nil
          && !dismissed.contains(PersonalTag(name: value.name).normalized)
        { adopt(value, automatic: true) }
      }
    }
  }
  private var visibleTags: [PersonalTag] {
    let matching = draft.catalog.filter {
      query.isEmpty || $0.name.localizedCaseInsensitiveContains(query)
    }
    return Array(
      matching.filter { draft.selected.contains($0.id) }
        + matching.filter { !draft.selected.contains($0.id) }.prefix(24))
  }
  private func adopt(_ value: TagSuggestion, automatic: Bool = false) {
    let tag =
      draft.catalog.first { $0.normalized == PersonalTag(name: value.name).normalized }
      ?? PersonalTag(name: value.name)
    guard !tag.name.isEmpty, tag.name.unicodeScalars.count <= 80,
      draft.selected.contains(tag.id) || draft.selected.count < 20
    else { return }
    if !draft.catalog.contains(where: { $0.id == tag.id }) { draft.catalog.append(tag) }
    if !draft.selected.contains(tag.id) {
      draft.selected.append(tag.id)
      if automatic { draft.automatic.append(tag.id) }
    }
  }
}
