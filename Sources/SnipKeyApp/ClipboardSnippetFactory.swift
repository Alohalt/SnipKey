import Foundation
import SnipKeyCore

enum ClipboardSnippetFactory {
    static func makeSnippet(from content: String, existingSnippets: [Snippet]) -> Snippet {
        Snippet(
            trigger: SnippetTriggerSuggester.suggestTrigger(
                for: content,
                existingTriggers: existingSnippets.map(\ .trigger)
            ),
            replacement: content
        )
    }
}