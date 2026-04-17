import XCTest
@testable import SnipKeyCore

final class SnippetTriggerSuggesterTests: XCTestCase {
    func testShortensIdentifierToFourCharactersByDefault() {
        let trigger = SnippetTriggerSuggester.suggestTrigger(for: "Account-Reset")
        XCTAssertEqual(trigger, "acco")
    }

    func testUsesEmailLocalPartPrefix() {
        let trigger = SnippetTriggerSuggester.suggestTrigger(for: "john.doe@example.com")
        XCTAssertEqual(trigger, "john")
    }

    func testUsesUrlCandidateWithFourCharacterDefaultLength() {
        let trigger = SnippetTriggerSuggester.suggestTrigger(for: "https://docs.github.com/en/actions")
        XCTAssertEqual(trigger, "gith")
    }

    func testUsesPathStemWithFourCharacterDefaultLength() {
        let trigger = SnippetTriggerSuggester.suggestTrigger(for: "~/Desktop/Quarterly Report.pdf")
        XCTAssertEqual(trigger, "quar")
    }

    func testUsesPinyinInitialsForChineseText() {
        let trigger = SnippetTriggerSuggester.suggestTrigger(for: "邮箱地址")
        XCTAssertEqual(trigger, "yxdz")
    }

    func testUsesEnglishWordInitialsForPhrase() {
        let trigger = SnippetTriggerSuggester.suggestTrigger(for: "Reset your password link")
        XCTAssertEqual(trigger, "rypl")
    }

    func testExpandsPrefixByOneCharacterWhenConflictOccurs() {
        let trigger = SnippetTriggerSuggester.suggestTrigger(
            for: "Account-Reset",
            existingTriggers: ["acco"]
        )
        XCTAssertEqual(trigger, "accou")
    }

    func testPureCodeUsesLastFourCharacters() {
        let trigger = SnippetTriggerSuggester.suggestTrigger(
            for: "B76006240919K0003"
        )
        XCTAssertEqual(trigger, "0003")
    }

    func testPureCodeExpandsSuffixByOneCharacterWhenConflictOccurs() {
        let trigger = SnippetTriggerSuggester.suggestTrigger(
            for: "B76006240919K0003",
            existingTriggers: ["0003"]
        )
        XCTAssertEqual(trigger, "k0003")
    }

    func testFallsBackToNumericSuffixWhenNoMoreSourceCharactersRemain() {
        let trigger = SnippetTriggerSuggester.suggestTrigger(
            for: "Reset your password link",
            existingTriggers: ["rypl"]
        )
        XCTAssertEqual(trigger, "rypl2")
    }

    func testFallsBackToClipForSymbolOnlyContent() {
        let trigger = SnippetTriggerSuggester.suggestTrigger(for: "!!! ###")
        XCTAssertEqual(trigger, "clip")
    }
}