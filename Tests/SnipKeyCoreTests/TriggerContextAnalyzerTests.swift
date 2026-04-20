import XCTest
@testable import SnipKeyCore

final class TriggerContextAnalyzerTests: XCTestCase {
    func testActiveQuerySupportsLettersDigitsAndUnderscores() {
        XCTAssertEqual(TriggerContextAnalyzer.activeQuery(in: "请填写#email_key2"), "email_key2")
    }

    func testActiveQuerySupportsEmptyQueryAfterPrefix() {
        XCTAssertEqual(TriggerContextAnalyzer.activeQuery(in: "请填写#"), "")
    }

    func testCompletedTriggerSupportsUnderscoreAfterSpaceCommit() {
        let result = TriggerContextAnalyzer.completedTrigger(in: "请填写#email_key ")

        XCTAssertEqual(result?.trigger, "email_key")
        XCTAssertEqual(result?.deletionCount, 11)
    }

    func testCompletedTriggerSupportsPunctuationTerminators() {
        let result = TriggerContextAnalyzer.completedTrigger(in: "请填写#addr,")

        XCTAssertEqual(result?.trigger, "addr")
        XCTAssertEqual(result?.deletionCount, 6)
    }

    func testCompletedTriggerRejectsHyphenatedTriggers() {
        XCTAssertNil(TriggerContextAnalyzer.completedTrigger(in: "请填写#mail-key "))
    }

    func testCompletedTriggerIgnoresTrailingPlainTextWithoutPrefix() {
        XCTAssertNil(TriggerContextAnalyzer.completedTrigger(in: "请填写邮箱 "))
    }
}