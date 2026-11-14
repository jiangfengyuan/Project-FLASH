import Foundation
import SwiftData

@Model public final class PersonalLibraryEntity {
    @Attribute(.unique) public var id: String
    public var payload: Data
    public init(payload: Data) { id = "personal-library"; self.payload = payload }
}
public enum FlashSchemaV3: VersionedSchema, Sendable {
    public static let versionIdentifier = Schema.Version(3, 0, 0)
    public static var models: [any PersistentModel.Type] { FlashSchemaV2.models + [PersonalLibraryEntity.self] }
}
