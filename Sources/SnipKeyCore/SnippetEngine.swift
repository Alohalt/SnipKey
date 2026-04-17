import Foundation

public class SnippetEngine {
    private var snippets: [Snippet]

    public init(snippets: [Snippet] = []) {
        self.snippets = snippets
    }

    public func updateSnippets(_ snippets: [Snippet]) {
        self.snippets = snippets
    }

    /// Returns snippets whose trigger starts with the query (case-insensitive).
    /// Empty query returns all snippets.
    public func match(query: String) -> [Snippet] {
        if query.isEmpty {
            return sortSnippets(snippets)
        }

        let lower = query.lowercased()
        let matches = snippets.filter { $0.trigger.lowercased().hasPrefix(lower) }
        return sortSnippets(matches, exactMatchQuery: lower)
    }

    /// Returns true if query exactly matches a trigger.
    public func isExactMatch(_ query: String) -> Bool {
        let lower = query.lowercased()
        return snippets.contains { $0.trigger.lowercased() == lower }
    }

    /// Finds a snippet by exact trigger match (case-insensitive).
    public func findExact(trigger: String) -> Snippet? {
        let lower = trigger.lowercased()
        let matches = snippets.filter { $0.trigger.lowercased() == lower }
        return sortSnippets(matches, exactMatchQuery: lower).first
    }

    private func sortSnippets(_ snippets: [Snippet], exactMatchQuery: String? = nil) -> [Snippet] {
        snippets.sorted { lhs, rhs in
            if let exactMatchQuery {
                let lhsExact = lhs.trigger.lowercased() == exactMatchQuery
                let rhsExact = rhs.trigger.lowercased() == exactMatchQuery
                if lhsExact != rhsExact {
                    return lhsExact
                }
            }

            if lhs.acceptanceCount != rhs.acceptanceCount {
                return lhs.acceptanceCount > rhs.acceptanceCount
            }

            let triggerOrder = lhs.trigger.localizedCaseInsensitiveCompare(rhs.trigger)
            if triggerOrder != .orderedSame {
                return triggerOrder == .orderedAscending
            }

            return lhs.id.uuidString < rhs.id.uuidString
        }
    }
}
