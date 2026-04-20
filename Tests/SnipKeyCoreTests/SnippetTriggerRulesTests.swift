import XCTest
@testable import SnipKeyCore

final class SnippetTriggerRulesTests: XCTestCase {
    func testSanitizeKeepsOnlyLettersNumbersAndUnderscores() {
        XCTAssertEqual(SnippetTriggerRules.sanitize("中Ab-c_1 !"), "Abc_1")
    }

    func testValidationRejectsDuplicateCaseInsensitively() {
        let error = SnippetTriggerRules.validationError(
            for: "EMAIL",
            existingTriggers: ["email", "addr"]
        )

        XCTAssertEqual(error, .duplicate)
    }

    func testValidationRejectsInvalidCharacters() {
        let error = SnippetTriggerRules.validationError(
            for: "mail-key",
            existingTriggers: []
        )

        XCTAssertEqual(error, .invalidCharacters)
    }

    func testNextAvailableTriggerAppendsNumericSuffix() {
        let trigger = SnippetTriggerRules.nextAvailableTrigger(
            existingTriggers: ["key", "key_2"],
            base: "key"
        )

        XCTAssertEqual(trigger, "key_3")
    }

    func testNormalizedTriggerFallsBackToDefaultBase() {
        let trigger = SnippetTriggerRules.normalizedTrigger(
            from: "中文",
            existingTriggers: []
        )

        XCTAssertEqual(trigger, "key")
    }
}