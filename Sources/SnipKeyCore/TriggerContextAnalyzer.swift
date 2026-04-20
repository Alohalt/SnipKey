import Foundation

public enum TriggerContextAnalyzer {
    public struct CompletedTrigger: Equatable {
        public let trigger: String
        public let deletionCount: Int

        public init(trigger: String, deletionCount: Int) {
            self.trigger = trigger
            self.deletionCount = deletionCount
        }
    }

    public static func activeQuery(in textBeforeCursor: String, triggerPrefix: Character = "#") -> String? {
        let characters = Array(textBeforeCursor)

        if characters.last == triggerPrefix {
            return ""
        }

        guard let endIndex = lastTriggerCharacterIndex(in: characters) else {
            return nil
        }

        var startIndex = endIndex
        while startIndex > 0, isTriggerCharacter(characters[startIndex - 1]) {
            startIndex -= 1
        }

        guard startIndex > 0, characters[startIndex - 1] == triggerPrefix else {
            return nil
        }

        return String(characters[startIndex...endIndex])
    }

    public static func completedTrigger(in textBeforeCursor: String, triggerPrefix: Character = "#") -> CompletedTrigger? {
        let characters = Array(textBeforeCursor)
        guard let trailingCharacter = characters.last, isTriggerTerminator(trailingCharacter) else {
            return nil
        }

        let committedText = String(characters.dropLast())
        guard let query = activeQuery(in: committedText, triggerPrefix: triggerPrefix), !query.isEmpty else {
            return nil
        }

        return CompletedTrigger(trigger: query, deletionCount: query.count + 2)
    }

    private static func lastTriggerCharacterIndex(in characters: [Character]) -> Int? {
        guard let lastIndex = characters.indices.last, isTriggerCharacter(characters[lastIndex]) else {
            return nil
        }

        return lastIndex
    }

    private static func isTriggerCharacter(_ character: Character) -> Bool {
        SnippetTriggerRules.isAllowedCharacter(character)
    }

    private static func isTriggerTerminator(_ character: Character) -> Bool {
        !isTriggerCharacter(character) && character != "#"
    }
}