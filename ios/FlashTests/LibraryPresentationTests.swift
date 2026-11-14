import XCTest
import SwiftUI
import FlashCore
@testable import Flash

/// Real SwiftUI mounting catches missing environment/model registration and saves
/// rendered artifacts; it is not a substitute for manual VoiceOver or touch QA.
final class LibraryPresentationTests: XCTestCase {
    @MainActor func testLibraryScreensInLightDarkAndAccessibleRTL() async throws {
        let container = FlashDatabase.makeContainer(inMemory:true)
        let repository = FlashRepository(container:container)
        let id = UUID().uuidString
        try repository.addLog(id:id,content:"Fictional reading idea — a long entry for text wrapping",colorTag:.idea,category:.idea,recordDate:Calendar.current.date(byAdding:.year,value:-1,to:Date()))
        try repository.setLogFavorite(id:id,true)
        var library = PersonalLibrary(); let tag = PersonalTag(name:"阅读 Reading"); library.tags = [tag]; library.links["log:"+id] = [tag.id]
        var filter = LibraryFilter(); filter.name = "Reading"; filter.tagIDs = [tag.id]; library.filters = [filter]
        try repository.savePersonalLibrary(library)
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let previous = scene.windows.first(where: \.isKeyWindow)
        for (name,mode) in [("history",PersonalLibraryScreen.Mode.history),("filters",.filters),("tags",.tags),("reminders",.reminders)] {
            for dark in [false,true] {
                let view = NavigationStack { PersonalLibraryScreen(mode:mode) }
                    .environment(AppState()).environment(\.flashRepository,repository).modelContainer(container)
                    .environment(\.layoutDirection,dark ? .rightToLeft : .leftToRight)
                    .environment(\.dynamicTypeSize,dark ? .accessibility3 : .large)
                let controller = UIHostingController(rootView:view)
                let window = UIWindow(windowScene:scene); window.rootViewController = controller
                window.overrideUserInterfaceStyle = dark ? .dark : .light
                window.makeKeyAndVisible(); controller.view.layoutIfNeeded()
                try await Task.sleep(for:.milliseconds(250))
                XCTAssertNotNil(controller.view.window)
                let image = UIGraphicsImageRenderer(bounds:controller.view.bounds).image { _ in controller.view.drawHierarchy(in:controller.view.bounds,afterScreenUpdates:true) }
                let attachment = XCTAttachment(image:image); attachment.name = name + (dark ? "-dark-AX3-RTL" : "-light"); attachment.lifetime = .keepAlways
                add(attachment)
                window.isHidden = true; window.rootViewController = nil
            }
        }
        previous?.makeKey()
    }
}
