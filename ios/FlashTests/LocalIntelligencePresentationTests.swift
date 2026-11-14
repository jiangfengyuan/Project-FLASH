import FlashCore
import FoundationModels
import SwiftUI
import XCTest

@testable import Flash
@testable import FlashDesign

final class LocalIntelligencePresentationTests: XCTestCase {
  @MainActor func testReviewRangesAndNewScreensRender() async throws {
    let container = FlashDatabase.makeContainer(inMemory: true)
    let repo = FlashRepository(container: container)
    for offset in 0..<95 where offset % 3 == 0 {
      try repo.addLog(
        content: "Fictional reading entry \(offset)", colorTag: .daily,
        recordDate: Calendar.current.date(byAdding: .day, value: -offset, to: Date()))
    }
    try repo.addLog(
      content: "A recently deleted reading note, ready to restore.", colorTag: .idea,
      category: .idea)
    _ = try repo.moveToTrash(["log:" + XCTUnwrap(repo.allLogs().first?.id)])
    let scene = try XCTUnwrap(
      UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
    let previous = scene.windows.first(where: \.isKeyWindow)
    let appState = AppState()
    let screens: [(String, AnyView)] =
      ReviewWindow.allCases.map { ($0.rawValue, AnyView(StatsView(initialWindow: $0))) } + [
        ("trash", AnyView(TrashScreen())), ("tag-settings", AnyView(TaggingSettingsScreen())),
        ("record-templates", AnyView(ExploreScreen())),
        (
          "reading-editor",
          AnyView(
            LogEditSheet(
              log: LogItem(
                id: UUID().uuidString, content: RecordTemplate.reading.body, colorTag: .daily,
                category: .log, importance: 1, createdAt: DateFormatting.isoNow(),
                recordDate: DateFormatting.today()), title: RecordTemplate.reading.title,
              onSave: { _ in }))
        ),
      ]
    for (name, screen) in screens {
      for dark in [false, true] {
        let root = NavigationStack { screen }.environment(appState).environment(
          appState.focusRouter
        )
        .environment(\.flashRepository, repo).modelContainer(container)
        .environment(\.layoutDirection, dark ? .rightToLeft : .leftToRight)
        .environment(\.dynamicTypeSize, dark ? .accessibility3 : .large)
        .tint(BrandColors.brandPrimary)
        let controller = UIHostingController(rootView: root)
        let window = UIWindow(windowScene: scene)
        window.rootViewController = controller
        window.overrideUserInterfaceStyle = dark ? .dark : .light
        window.makeKeyAndVisible()
        try await Task.sleep(for: .milliseconds(name == "reading-editor" ? 1000 : 450))
        controller.view.layoutIfNeeded()
        XCTAssertGreaterThan(controller.view.bounds.height, 0)
        let image = UIGraphicsImageRenderer(bounds: controller.view.bounds).image { _ in
          controller.view.drawHierarchy(in: controller.view.bounds, afterScreenUpdates: true)
        }
        let attachment = XCTAttachment(image: image)
        attachment.name = name + (dark ? "-dark-AX3-RTL" : "-light")
        attachment.lifetime = .keepAlways
        add(attachment)
        window.isHidden = true
        window.rootViewController = nil
      }
    }
    previous?.makeKey()
  }
  @MainActor func testMarkedTextIsDetectedUntilCommitted() throws {
    let scene = try XCTUnwrap(
      UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
    let previous = scene.windows.first(where: \.isKeyWindow)
    let controller = UIViewController()
    let field = UITextField(frame: CGRect(x: 20, y: 100, width: 240, height: 44))
    controller.view.addSubview(field)
    let window = UIWindow(windowScene: scene)
    window.rootViewController = controller
    window.makeKeyAndVisible()
    defer {
      field.resignFirstResponder()
      window.isHidden = true
      previous?.makeKey()
    }
    XCTAssertTrue(field.becomeFirstResponder())
    field.setMarkedText("阅读", selectedRange: NSRange(location: 2, length: 0))
    XCTAssertTrue(TextCompositionState.isComposing)
    field.unmarkText()
    XCTAssertFalse(TextCompositionState.isComposing)
  }

  @available(iOS 26, *) @MainActor func testLocalTagProviderAvailabilityAndFallback() async {
    let model = SystemLanguageModel(useCase: .contentTagging)
    let status = XCTAttachment(string: "contentTagging availability: \(model.availability)")
    status.name = "AFM-runtime-availability"
    status.lifetime = .keepAlways
    add(status)
    let catalog = [PersonalTag(name: "Reading")]
    let results = await LocalTagProvider().suggestions(
      for: "Reading a book and taking notes", catalog: catalog, locale: "en_US")
    XCTAssertFalse(results.isEmpty)
    XCTAssertLessThanOrEqual(results.count, 3)
    if !model.isAvailable { XCTAssertEqual(results.first?.existingID, catalog.first?.id) }
  }
  @MainActor func testTemplateTextCanBeSavedAndTaggedAtomically() throws {
    let repository = FlashRepository(container: FlashDatabase.makeContainer(inMemory: true))
    let date = DateFormatting.isoNow()
    let tag = PersonalTag(name: "Reading")
    let log = LogItem(
      id: UUID().uuidString, content: RecordTemplate.reading.body + "A useful passage",
      colorTag: .daily, category: .log, importance: 1, createdAt: date,
      recordDate: DateFormatting.today())
    var draft = TagDraft()
    draft.catalog = [tag]
    draft.selected = [tag.id]
    try repository.updateLog(log, tags: draft)
    XCTAssertEqual(try repository.allLogs().first?.content, log.content)
    XCTAssertEqual(try repository.tagDraft(for: "log:" + log.id).selected, [tag.id])
    try repository.deleteLogFromUI(id: log.id)
    XCTAssertEqual(try repository.trashItems().first?.tags, [tag])
  }
}
