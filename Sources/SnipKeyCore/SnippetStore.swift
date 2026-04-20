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

    @discardableResult
    public func addSnippet(_ snippet: Snippet) -> Bool {
        guard validationError(for: snippet.trigger) == nil else {
            print("Failed to add snippet: invalid or duplicate trigger '\(snippet.trigger)'")
            return false
        }

        snippets.append(snippet)
        save()
        return true
    }

    @discardableResult
    public func updateSnippet(_ snippet: Snippet) -> Bool {
        guard validationError(for: snippet.trigger, excluding: snippet.id) == nil else {
            print("Failed to update snippet: invalid or duplicate trigger '\(snippet.trigger)'")
            return false
        }

        if let index = snippets.firstIndex(where: { $0.id == snippet.id }) {
            snippets[index] = snippet
            save()
            return true
        }

        return false
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

    public func validationError(for trigger: String, excluding snippetID: UUID? = nil) -> SnippetTriggerRules.ValidationError? {
        let existingTriggers = snippets
            .filter { $0.id != snippetID }
            .map(\.trigger)
        return SnippetTriggerRules.validationError(for: trigger, existingTriggers: existingTriggers)
    }

    public func nextAvailableTrigger(base: String = SnippetTriggerRules.defaultBase) -> String {
        SnippetTriggerRules.nextAvailableTrigger(existingTriggers: snippets.map(\.trigger), base: base)
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
            let normalized = normalizedSnippets(decoded.snippets)
            snippets = normalized.snippets
            groups = decoded.groups
            if normalized.didChange {
                save()
            }
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
        snippets = normalizedSnippets(decoded.snippets).snippets
        groups = decoded.groups
        save()
    }

    private func normalizedSnippets(_ rawSnippets: [Snippet]) -> (snippets: [Snippet], didChange: Bool) {
        var normalizedTriggers: [String] = []
        var normalizedSnippets: [Snippet] = []
        var didChange = false

        for var snippet in rawSnippets {
            let normalizedTrigger = SnippetTriggerRules.normalizedTrigger(
                from: snippet.trigger,
                existingTriggers: normalizedTriggers
            )

            if snippet.trigger != normalizedTrigger {
                snippet.trigger = normalizedTrigger
                didChange = true
            }

            normalizedTriggers.append(snippet.trigger)
            normalizedSnippets.append(snippet)
        }

        return (normalizedSnippets, didChange)
    }
}
