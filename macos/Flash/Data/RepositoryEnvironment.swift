import SwiftUI

private struct FlashRepositoryKey: EnvironmentKey {
    nonisolated(unsafe) static let defaultValue: FlashRepository? = nil
}

extension EnvironmentValues {
    var flashRepository: FlashRepository? {
        get { self[FlashRepositoryKey.self] }
        set { self[FlashRepositoryKey.self] = newValue }
    }
}
