import Foundation

public enum SnippetTriggerSuggester {
    public static let defaultPreferredLength = 4

    private static let defaultBase = "clip"
    private static let genericHostLabels: Set<String> = ["www", "m", "mobile", "app"]
    private static let genericSecondLevelDomains: Set<String> = ["ac", "co", "com", "edu", "gov", "net", "org"]
    private static let emailRegex = try? NSRegularExpression(
        pattern: "^[A-Z0-9._%+-]+@[A-Z0-9.-]+\\.[A-Z]{2,}$",
        options: [.caseInsensitive]
    )
    private static let linkDetector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)

    public static func suggestTrigger(
        for content: String,
        existingTriggers: [String] = [],
        preferredLength: Int = defaultPreferredLength
    ) -> String {
        let resolvedPreferredLength = max(1, preferredLength)
        let normalizedExisting = Set(existingTriggers.map { $0.lowercased() })

        for candidate in candidates(for: content) {
            let sanitized = sanitize(candidate.rawValue)
            guard sanitized.isEmpty == false else { continue }
            return makeUnique(
                base: sanitized,
                direction: candidate.direction,
                existingTriggers: normalizedExisting,
                preferredLength: resolvedPreferredLength
            )
        }

        return makeUnique(
            base: defaultBase,
            direction: .prefix,
            existingTriggers: normalizedExisting,
            preferredLength: resolvedPreferredLength
        )
    }

    private static func candidates(for content: String) -> [TriggerCandidate] {
        let collapsed = collapseWhitespace(in: content)
        guard collapsed.isEmpty == false else {
            return [TriggerCandidate(rawValue: defaultBase, direction: .prefix)]
        }

        var candidates: [TriggerCandidate] = []

        if let code = codeCandidate(from: collapsed) {
            candidates.append(TriggerCandidate(rawValue: code, direction: .suffix))
        }

        if let email = emailCandidate(from: collapsed) {
            candidates.append(TriggerCandidate(rawValue: email, direction: .prefix))
        }

        candidates.append(contentsOf: urlCandidates(from: collapsed).map {
            TriggerCandidate(rawValue: $0, direction: .prefix)
        })

        if let filePath = pathCandidate(from: collapsed) {
            candidates.append(TriggerCandidate(rawValue: filePath, direction: .prefix))
        }

        if let englishPhrase = englishPhraseCandidate(from: collapsed) {
            candidates.append(TriggerCandidate(rawValue: englishPhrase, direction: .prefix))
        }

        if containsCJK(in: collapsed), let initials = cjkInitialsCandidate(from: collapsed) {
            candidates.append(TriggerCandidate(rawValue: initials, direction: .prefix))
        }

        if let identifier = identifierCandidate(from: collapsed) {
            candidates.append(TriggerCandidate(rawValue: identifier, direction: .prefix))
        }

        candidates.append(TriggerCandidate(rawValue: defaultBase, direction: .prefix))
        return deduplicated(candidates)
    }

    private static func codeCandidate(from content: String) -> String? {
        guard content.isEmpty == false else { return nil }
        guard content.unicodeScalars.contains(where: { $0.isASCII && CharacterSet.alphanumerics.contains($0) }) else { return nil }
        guard content.unicodeScalars.allSatisfy({ scalar in
            scalar.isASCII && CharacterSet.alphanumerics.contains(scalar)
        }) else {
            return nil
        }

        let letters = content.filter(\.isLetter).count
        let digits = content.filter(\.isNumber).count
        let hasUppercaseLetter = content.contains { $0.isUppercase }

        guard content.count >= 6 else { return nil }
        guard digits >= 4 else { return nil }
        guard hasUppercaseLetter || letters == 0 || digits >= letters * 2 else { return nil }

        return content.lowercased()
    }

    private static func emailCandidate(from content: String) -> String? {
        guard isLikelyEmail(content) else { return nil }
        let localPart = content.split(separator: "@", maxSplits: 1).first.map(String.init) ?? ""
        return identifierCandidate(from: localPart)
    }

    private static func isLikelyEmail(_ content: String) -> Bool {
        guard let emailRegex else {
            return false
        }

        let range = NSRange(content.startIndex..., in: content)
        return emailRegex.firstMatch(in: content, options: [], range: range)?.range == range
    }

    private static func urlCandidates(from content: String) -> [String] {
        guard let linkDetector else {
            return []
        }

        let fullRange = NSRange(content.startIndex..., in: content)
        guard let match = linkDetector.firstMatch(in: content, options: [], range: fullRange),
              match.range == fullRange,
              let url = match.url,
              url.scheme?.lowercased() != "mailto",
              let host = url.host else {
            return []
        }

        let hostTokens = host
            .lowercased()
            .split(separator: ".")
            .map(String.init)
            .filter { genericHostLabels.contains($0) == false }

        guard let domain = preferredDomainLabel(from: hostTokens) else { return [] }

        var candidates = [domain]
        if let pathToken = preferredURLPathToken(from: url.path) {
            candidates.insert(domain + pathToken, at: 0)
        }

        return candidates.compactMap(identifierCandidate(from:))
    }

    private static func preferredDomainLabel(from hostTokens: [String]) -> String? {
        guard hostTokens.isEmpty == false else { return nil }
        if hostTokens.count == 1 { return hostTokens[0] }

        let labelsBeforeTLD = hostTokens.dropLast().reversed()
        for label in labelsBeforeTLD where genericSecondLevelDomains.contains(label) == false {
            return label
        }

        return hostTokens.dropLast().last
    }

    private static func preferredURLPathToken(from path: String) -> String? {
        let components = path
            .split(separator: "/")
            .map(String.init)
            .filter { $0.isEmpty == false }

        for component in components.reversed() {
            if let candidate = identifierCandidate(from: component), candidate.count >= 3 {
                return candidate
            }
        }

        return nil
    }

    private static func pathCandidate(from content: String) -> String? {
        guard looksLikePath(content) else { return nil }

        let resolvedPath: String
        if content.lowercased().hasPrefix("file://"), let url = URL(string: content), url.isFileURL {
            resolvedPath = url.path
        } else {
            resolvedPath = (content as NSString).expandingTildeInPath
        }

        let lastPathComponent = (resolvedPath as NSString).lastPathComponent
        let stem = (lastPathComponent as NSString).deletingPathExtension
        return identifierCandidate(from: stem)
    }

    private static func looksLikePath(_ content: String) -> Bool {
        if content.hasPrefix("/") || content.hasPrefix("~/") || content.lowercased().hasPrefix("file://") {
            return true
        }

        return content.contains("/") && content.contains(where: { $0.isWhitespace }) == false && content.contains("://") == false
    }

    private static func englishPhraseCandidate(from content: String) -> String? {
        guard containsCJK(in: content) == false else { return nil }
        guard content.contains(where: { $0.isWhitespace }) else { return nil }

        let tokens = wordTokens(from: transliteratedASCII(from: content)).filter { token in
            token.isEmpty == false && token.allSatisfy({ $0.isNumber }) == false
        }

        guard tokens.count > 1 else { return nil }

        let initials = tokens.compactMap(\.first)
        guard initials.isEmpty == false else { return nil }
        return String(initials)
    }

    private static func identifierCandidate(from content: String) -> String? {
        let normalized = transliteratedASCII(from: content).filter { $0.isLetter || $0.isNumber }
        return normalized.isEmpty ? nil : normalized
    }

    private static func cjkInitialsCandidate(from content: String) -> String? {
        var initials = ""

        for character in content {
            let transliterated = transliteratedASCII(from: String(character))
            guard let initial = transliterated.first(where: { $0.isLetter || $0.isNumber }) else {
                continue
            }

            initials.append(initial)
        }

        return initials.isEmpty ? nil : initials
    }

    private static func collapseWhitespace(in content: String) -> String {
        content
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { $0.isEmpty == false }
            .joined(separator: " ")
    }

    private static func transliteratedASCII(from content: String) -> String {
        let mutable = NSMutableString(string: content) as CFMutableString
        CFStringTransform(mutable, nil, kCFStringTransformToLatin, false)
        CFStringTransform(mutable, nil, kCFStringTransformStripCombiningMarks, false)
        return (mutable as String).lowercased()
    }

    private static func wordTokens(from content: String) -> [String] {
        content.split { character in
            character.isLetter == false && character.isNumber == false
        }.map(String.init)
    }

    private static func sanitize(_ candidate: String) -> String {
        let transliterated = transliteratedASCII(from: candidate)
        let result = transliterated.filter { $0.isLetter || $0.isNumber }
        return result
    }

    private static func makeUnique(
        base: String,
        direction: TriggerDirection,
        existingTriggers: Set<String>,
        preferredLength: Int
    ) -> String {
        let resolvedLength = min(max(1, preferredLength), base.count)

        for length in resolvedLength...base.count {
            let candidate = candidateSlice(from: base, direction: direction, length: length)
            if existingTriggers.contains(candidate.lowercased()) == false {
                return candidate
            }
        }

        return makeNumericUnique(
            from: candidateSlice(from: base, direction: direction, length: resolvedLength),
            existingTriggers: existingTriggers
        )
    }

    private static func candidateSlice(from base: String, direction: TriggerDirection, length: Int) -> String {
        switch direction {
        case .prefix:
            return String(base.prefix(length))
        case .suffix:
            return String(base.suffix(length))
        }
    }

    private static func makeNumericUnique(from base: String, existingTriggers: Set<String>) -> String {
        var index = 2
        while true {
            let candidate = base + String(index)
            if existingTriggers.contains(candidate.lowercased()) == false {
                return candidate
            }
            index += 1
        }
    }

    private static func deduplicated(_ candidates: [TriggerCandidate]) -> [TriggerCandidate] {
        var seen = Set<String>()
        var result: [TriggerCandidate] = []

        for candidate in candidates {
            let key = candidate.direction.rawValue + ":" + candidate.rawValue.lowercased()
            if seen.insert(key).inserted {
                result.append(candidate)
            }
        }

        return result
    }

    private static func containsCJK(in content: String) -> Bool {
        content.unicodeScalars.contains { scalar in
            switch scalar.value {
            case 0x3400...0x4DBF, 0x4E00...0x9FFF, 0xF900...0xFAFF:
                return true
            default:
                return false
            }
        }
    }

    private struct TriggerCandidate {
        let rawValue: String
        let direction: TriggerDirection
    }

    private enum TriggerDirection: String {
        case prefix
        case suffix
    }
}