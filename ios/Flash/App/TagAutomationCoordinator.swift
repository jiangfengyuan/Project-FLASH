import FlashCore
import Foundation
import Observation

@MainActor @Observable final class TagAutomationCoordinator {
  private(set) var message: String?
  var allowed = false {
    didSet {
      if allowed {
        drain()
      } else {
        tasks.values.forEach { $0.cancel() }
        tasks = [:]
        tokens = [:]
      }
    }
  }
  private let repository: FlashRepository
  private let service: TagRecommendationService
  private var pending: [String: String] = [:]
  private var tasks: [String: Task<Void, Never>] = [:]
  private var tokens: [String: UUID] = [:]
  private var undo: (String, TagDraft, TagDraft)?
  init(repository: FlashRepository, service: TagRecommendationService = .shared) {
    self.repository = repository
    self.service = service
  }
  func enqueue(_ key: String, text: String) {
    tasks[key]?.cancel()
    tasks[key] = nil
    tokens[key] = nil
    pending[key] = text
    if allowed { drain() }
  }
  private func drain() {
    guard !repository.isTemporaryStore, allowed else { return }
    for (key, text) in pending where tasks[key] == nil {
      let token = UUID()
      tokens[key] = token
      tasks[key] = Task {
        defer {
          if tokens[key] == token {
            tasks[key] = nil
            tokens[key] = nil
          }
        }
        do {
          let mode = try repository.preferences().taggingMode
          guard mode != .suggest else {
            pending.removeValue(forKey: key)
            return
          }
          let before = try repository.tagDraft(for: key)
          let suggestions = await service.suggestions(
            text: text, catalog: before.catalog,
            locale: Bundle.main.preferredLocalizations.first ?? Locale.current.identifier)
          guard !Task.isCancelled, allowed, try repository.textForRecord(key) == text,
            try repository.preferences().taggingMode == mode
          else { return }
          let current = try repository.tagDraft(for: key)
          let draft = current.applying(suggestions, mode: mode)
          if draft.selected.sorted() != current.selected.sorted() {
            try repository.saveTagDraft(draft, key: key)
            undo = (key, current, draft)
            message = L("已在本机整理标签")
          }
          if tokens[key] == token { pending.removeValue(forKey: key) }
        } catch { if tokens[key] == token { pending.removeValue(forKey: key) } }
      }
    }
  }
  func undoLast() {
    guard let (key, before, after) = undo else { return }
    do {
      let current = try repository.tagDraft(for: key)
      guard Set(current.selected) == Set(after.selected) else {
        undo = nil
        message = nil
        return
      }
      var draft = before
      draft.catalog = current.catalog
      try repository.saveTagDraft(draft, key: key)
      undo = nil
      message = nil
    } catch { message = L("撤销失败，请重试") }
  }
}
