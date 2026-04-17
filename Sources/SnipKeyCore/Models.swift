import Foundation

public struct Snippet: Codable, Identifiable, Equatable {
    public let id: UUID
    public var trigger: String
    public var replacement: String
    public var groupId: UUID?
    public var acceptanceCount: Int

    enum CodingKeys: String, CodingKey {
        case id
        case trigger
        case replacement
        case groupId
        case acceptanceCount
    }

    public init(
        id: UUID = UUID(),
        trigger: String,
        replacement: String,
        groupId: UUID? = nil,
        acceptanceCount: Int = 0
    ) {
        self.id = id
        self.trigger = trigger
        self.replacement = replacement
        self.groupId = groupId
        self.acceptanceCount = max(0, acceptanceCount)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        trigger = try container.decode(String.self, forKey: .trigger)
        replacement = try container.decode(String.self, forKey: .replacement)
        groupId = try container.decodeIfPresent(UUID.self, forKey: .groupId)
        acceptanceCount = max(0, try container.decodeIfPresent(Int.self, forKey: .acceptanceCount) ?? 0)
    }
}

public struct SnippetGroup: Codable, Identifiable, Equatable {
    public let id: UUID
    public var name: String

    public init(id: UUID = UUID(), name: String) {
        self.id = id
        self.name = name
    }
}

public struct SnippetData: Codable, Equatable {
    public var snippets: [Snippet]
    public var groups: [SnippetGroup]

    public init(snippets: [Snippet] = [], groups: [SnippetGroup] = []) {
        self.snippets = snippets
        self.groups = groups
    }
}
