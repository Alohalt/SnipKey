import Foundation

public class SnippetStore: ObservableObject {
    private static let currentAppSupportDirectoryName = "SnipKey"

    @Published public var snippets: [Snippet] = []
    @Published public var groups: [SnippetGroup] = []

    private let fileURL: URL

    public init(fileURL: URL? = nil) {
        if let fileURL {
            self.fileURL = fileURL
        } else {
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            let dir = appSupport.appendingPathComponent(Self.currentAppSupportDirectoryName)
            let currentFileURL = dir.appendingPathComponent("snippets.json")

            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            self.fileURL = currentFileURL
        }
        load()
    }

    // MARK: - Snippet CRUD

    public func addSnippet(_ snippet: Snippet) {
        snippets.append(snippet)
        save()
    }

    public func updateSnippet(_ snippet: Snippet) {
        if let index = snippets.firstIndex(where: { $0.id == snippet.id }) {
            snippets[index] = snippet
            save()
        }
    }

    public func deleteSnippet(id: UUID) {
        snippets.removeAll { $0.id == id }
        save()
    }

    public func recordAcceptance(for id: UUID) {
        guard let index = snippets.firstIndex(where: { $0.id == id }) else { return }
        snippets[index].acceptanceCount += 1
        save()
    }

    // MARK: - Group CRUD

    public func addGroup(_ group: SnippetGroup) {
        groups.append(group)
        save()
    }

    public func updateGroup(_ group: SnippetGroup) {
        if let index = groups.firstIndex(where: { $0.id == group.id }) {
            groups[index] = group
            save()
        }
    }

    public func deleteGroup(id: UUID) {
        groups.removeAll { $0.id == id }
        for i in snippets.indices where snippets[i].groupId == id {
            snippets[i].groupId = nil
        }
        save()
    }

    // MARK: - Queries

    public func snippets(forGroup groupId: UUID) -> [Snippet] {
        snippets.filter { $0.groupId == groupId }
    }

    public var ungroupedSnippets: [Snippet] {
        snippets.filter { $0.groupId == nil }
    }

    // MARK: - Persistence

    public func save() {
        let data = SnippetData(snippets: snippets, groups: groups)
        do {
            let encoded = try JSONEncoder().encode(data)
            try encoded.write(to: fileURL, options: .atomic)
        } catch {
            print("Failed to save snippets: \(error)")
        }
    }

    public func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        do {
            let data = try Data(contentsOf: fileURL)
            let decoded = try JSONDecoder().decode(SnippetData.self, from: data)
            snippets = decoded.snippets
            groups = decoded.groups
        } catch {
            print("Failed to load snippets: \(error)")
        }
    }

    // MARK: - Import/Export

    public func exportData(to url: URL) throws {
        let data = SnippetData(snippets: snippets, groups: groups)
        let encoded = try JSONEncoder().encode(data)
        try encoded.write(to: url, options: .atomic)
    }

    public func importData(from url: URL) throws {
        let data = try Data(contentsOf: url)
        let decoded = try JSONDecoder().decode(SnippetData.self, from: data)
        snippets = decoded.snippets
        groups = decoded.groups
        save()
    }
}
