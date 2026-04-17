import XCTest
@testable import SnipKeyCore

final class VariableResolverTests: XCTestCase {
    var resolver: VariableResolver!

    override func setUp() {
        super.setUp()
        resolver = VariableResolver()
    }

    func testPlainTextUnchanged() {
        XCTAssertEqual(resolver.resolve("hello world").text, "hello world")
    }

    func testDateVariable() {
        let result = resolver.resolve("{date}")
        let year = Calendar.current.component(.year, from: Date())
        XCTAssertTrue(result.text.contains(String(year)), "Expected result to contain year \(year), got: \(result.text)")
    }

    func testTimeVariable() {
        let result = resolver.resolve("{time}")
        XCTAssertTrue(result.text.contains(":"), "Expected time format with ':', got: \(result.text)")
    }

    func testClipboardVariable() {
        resolver = VariableResolver(clipboardProvider: { "clipboard-content" })
        let result = resolver.resolve("pasted: {clipboard}")
        XCTAssertEqual(result.text, "pasted: clipboard-content")
    }

    func testCursorVariable() {
        let result = resolver.resolve("Hello {cursor} World")
        XCTAssertEqual(result.text, "Hello  World")
        XCTAssertEqual(result.cursorOffset, 6)
    }

    func testMultipleVariables() {
        resolver = VariableResolver(clipboardProvider: { "CB" })
        let result = resolver.resolve("Date: {date}, Clip: {clipboard}")
        XCTAssertTrue(result.text.contains("Clip: CB"))
        XCTAssertTrue(result.text.contains("Date:"))
    }

    func testUnknownVariableLeftAsIs() {
        XCTAssertEqual(resolver.resolve("{unknown}").text, "{unknown}")
    }

    func testMixedTextAndVariables() {
        resolver = VariableResolver(clipboardProvider: { "X" })
        let result = resolver.resolve("start {clipboard} end")
        XCTAssertEqual(result.text, "start X end")
    }
}
