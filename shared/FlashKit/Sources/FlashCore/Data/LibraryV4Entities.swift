import Foundation
import SwiftData

@Model public final class LibraryTagEntity {
  @Attribute(.unique) public var id: String
  public var name: String
  public init(_ tag: PersonalTag) {
    id = tag.id
    name = tag.name
  }
  public func value() -> PersonalTag {
    var v = PersonalTag(name: name)
    v.id = id
    return v
  }
}
@Model public final class LibraryTagLinkEntity {
  @Attribute(.unique) public var id: String
  public var recordKey: String
  public var tagID: String
  public var automatic: Bool
  public init(recordKey: String, tagID: String, automatic: Bool = false) {
    id = recordKey + "|" + tagID
    self.recordKey = recordKey
    self.tagID = tagID
    self.automatic = automatic
  }
}
@Model public final class LibraryPreferencesEntity {
  @Attribute(.unique) public var id: String
  public var payload: Data
  public init(_ data: Data) {
    id = "preferences"
    payload = data
  }
}
@Model public final class TrashEntity {
  @Attribute(.unique) public var id: String
  public var deletedAt: Date
  public var expiresAt: Date?
  public var payload: Data
  public init(_ item: TrashItem) throws {
    id = item.id
    deletedAt = item.deletedAt
    expiresAt = item.expiresAt
    payload = try JSONEncoder().encode(item)
  }
}
public enum FlashSchemaV4: VersionedSchema, Sendable {
  public static let versionIdentifier = Schema.Version(4, 0, 0)
  public static var models: [any PersistentModel.Type] {
    FlashSchemaV3.models + [
      LibraryTagEntity.self, LibraryTagLinkEntity.self, LibraryPreferencesEntity.self,
      TrashEntity.self,
    ]
  }
  public static func migrate(_ context: ModelContext) throws {
    for entity in try context.fetch(FetchDescriptor<PersonalLibraryEntity>()) {
      var value = try JSONDecoder().decode(PersonalLibrary.self, from: entity.payload)
      for tag in value.tags { context.insert(LibraryTagEntity(tag)) }
      for (key, ids) in value.links {
        for id in ids { context.insert(LibraryTagLinkEntity(recordKey: key, tagID: id)) }
      }
      value.tags = []
      value.links = [:]
      entity.payload = try JSONEncoder().encode(value)
    }
    try context.save()
  }
}
