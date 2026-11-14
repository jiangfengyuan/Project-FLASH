import XCTest
import SwiftUI
import FlashCore
@testable import Flash

final class LockedCaptureDraftTests: XCTestCase {
    @MainActor func testLockedCaptureNeverConstructsOrExposesPrivateDraft() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let suiteName = UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName:suiteName))
        defer { defaults.removePersistentDomain(forName:suiteName); try? FileManager.default.removeItem(at:directory) }
        let store = QuickCaptureDraftStore(defaults:defaults,directory:directory)
        let original = QuickCaptureDraft(text:"SYNTHETIC PRIVATE DRAFT",category:.log)
        store.save(original)
        // A legacy draft is also protected from constructor-driven migration.
        let legacy = try JSONEncoder().encode(original)
        defaults.set(legacy,forKey:"quickCaptureDraft")
        var constructions = 0
        let factory = { constructions += 1; return QuickCaptureDraftStore(defaults:defaults,directory:directory) }
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let previous = scene.windows.first(where: \.isKeyWindow)
        let container = FlashDatabase.makeContainer(inMemory:true)
        let repo = FlashRepository(container:container)
        for persistent in [false,true] {
            let sheet = QuickCaptureSheet(initialCategory:.idea,preservesPrivateDraft:persistent,draftStoreFactory:factory)
                .environment(\.flashRepository,repo)
            let controller = UIHostingController(rootView:sheet)
            let window = UIWindow(windowScene:scene); window.rootViewController = controller; window.makeKeyAndVisible()
            try await Task.sleep(for:.milliseconds(350))
            func texts(_ view:UIView) -> [String] {
                if let field = view as? UITextField { return [field.text ?? ""] }
                if let field = view as? UITextView { return [field.text ?? ""] }
                return view.subviews.flatMap(texts)
            }
            XCTAssertEqual(texts(controller.view).contains(original.text),persistent)
            XCTAssertEqual(constructions,persistent ? 1 : 0)
            if !persistent { XCTAssertEqual(defaults.data(forKey:"quickCaptureDraft"),legacy) }
            window.isHidden = true; window.rootViewController = nil
            try await Task.sleep(for:.milliseconds(60))
            XCTAssertEqual(store.load()?.text,original.text)
        }
        previous?.makeKey()
    }
}
