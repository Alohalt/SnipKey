import Foundation
import SnipKeyCore

enum ClipboardSnippetFactory {
    static func makeSnippet(from content: String, existingSnippets: [Snippet]) -> Snippet {
        Snippet(
            trigger: uniqueTrigger(for: content, existingSnippets: existingSnippets),
            replacement: content
        )
    }

    private static func uniqueTrigger(for content: String, existingSnippets: [Snippet]) -> String {
        let existingTriggers = Set(existingSnippets.map { $0.trigger.lowercased() })
        let base = suggestedTriggerBase(for: content)

        if existingTriggers.contains(base.lowercased()) == false {
            return base
        }

        var index = 2
        while true {
            let candidate = "\(base)\(index)"
            if existingTriggers.contains(candidate.lowercased()) == false {
                return candidate
            }
            index += 1
        }
    }

    private static func suggestedTriggerBase(for content: String) -> String {
        let collapsed = content
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let tokens = collapsed.lowercased().split { character in
            character.isLetter == false && character.isNumber == false
        }
        var candidate = String(tokens.joined().prefix(18))

        if candidate.isEmpty {
            let nonWhitespace = collapsed.filter { $0.isWhitespace == false }
            candidate = String(nonWhitespace.prefix(8))
        }

        if candidate.isEmpty {
            candidate = "clip"
        }

        if candidate.first?.isNumber == true {
            candidate = String(("clip" + candidate).prefix(18))
        }

        return candidate
    }
}