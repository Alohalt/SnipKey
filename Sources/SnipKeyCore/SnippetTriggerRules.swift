import Foundation

public enum SnippetTriggerRules {
    public static let defaultBase = "key"

    public enum ValidationError: Equatable {
        case empty
        case invalidCharacters
        case duplicate
    }

    public static func sanitize(_ trigger: String) -> String {
        String(trigger.filter(isAllowedCharacter))
    }

    public static func validationError(
        for trigger: String,
        existingTriggers: [String]
    ) -> ValidationError? {
        guard trigger.isEmpty == false else {
            return .empty
        }

        guard sanitize(trigger) == trigger else {
            return .invalidCharacters
        }

        let normalizedTrigger = trigger.lowercased()
        if existingTriggers.contains(where: { $0.lowercased() == normalizedTrigger }) {
            return .duplicate
        }

        return nil
    }

    public static func nextAvailableTrigger(
        existingTriggers: [String],
        base: String = defaultBase
    ) -> String {
        normalizedTrigger(from: base, existingTriggers: existingTriggers)
    }

    public static func normalizedTrigger(
        from trigger: String,
        existingTriggers: [String],
        fallbackBase: String = defaultBase
    ) -> String {
        let sanitized = sanitize(trigger)
        let base = sanitized.isEmpty ? sanitize(fallbackBase) : sanitized
        let resolvedBase = base.isEmpty ? defaultBase : base
        let normalizedExisting = Set(existingTriggers.map { $0.lowercased() })

        if normalizedExisting.contains(resolvedBase.lowercased()) == false {
            return resolvedBase
        }

        let separator = resolvedBase.hasSuffix("_") ? "" : "_"
        var suffix = 2
        while true {
            let candidate = resolvedBase + separator + String(suffix)
            if normalizedExisting.contains(candidate.lowercased()) == false {
                return candidate
            }
            suffix += 1
        }
    }

    public static func isAllowedCharacter(_ character: Character) -> Bool {
        if character == "_" {
            return true
        }

        guard character.unicodeScalars.count == 1,
              let scalar = character.unicodeScalars.first,
              scalar.isASCII else {
            return false
        }

        return CharacterSet.alphanumerics.contains(scalar)
    }
}