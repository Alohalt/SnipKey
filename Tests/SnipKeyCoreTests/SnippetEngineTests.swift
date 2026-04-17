import XCTest
@testable import SnipKeyCore

final class SnippetEngineTests: XCTestCase {
    var engine: SnippetEngine!

    override func setUp() {
        super.setUp()
        let snippets = [
            Snippet(trigger: "account", replacement: "account1"),
            Snippet(trigger: "email", replacement: "test@example.com"),
            Snippet(trigger: "addr", replacement: "123 Main St"),
            Snippet(trigger: "address", replacement: "456 Oak Ave"),
        ]
        engine = SnippetEngine(snippets: snippets)
    }

    func testExactMatch() {
        let results = engine.match(query: "account")
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.trigger, "account")
    }

    func testPrefixMatch() {
        let results = engine.match(query: "acc")
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.trigger, "account")
    }

    func testMultipleMatches() {
        let results = engine.match(query: "addr")
        XCTAssertEqual(results.count, 2)
    }

    func testEmptyQueryReturnsAll() {
        let results = engine.match(query: "")
        XCTAssertEqual(results.count, 4)
    }

    func testNoMatch() {
        let results = engine.match(query: "zzz")
        XCTAssertTrue(results.isEmpty)
    }

    func testCaseInsensitiveMatch() {
        let results = engine.match(query: "ACC")
        XCTAssertEqual(results.count, 1)
    }

    func testMatchesSortByAcceptanceCount() {
        engine.updateSnippets([
            Snippet(trigger: "address", replacement: "456 Oak Ave", acceptanceCount: 8),
            Snippet(trigger: "addr", replacement: "123 Main St", acceptanceCount: 2),
            Snippet(trigger: "add-on", replacement: "extra", acceptanceCount: 5),
        ])

        let results = engine.match(query: "add")
        XCTAssertEqual(results.map(\.trigger), ["address", "add-on", "addr"])
    }

    func testExactMatchStaysFirstWhenQueryFullyMatchesTrigger() {
        engine.updateSnippets([
            Snippet(trigger: "addr", replacement: "123 Main St", acceptanceCount: 1),
            Snippet(trigger: "address", replacement: "456 Oak Ave", acceptanceCount: 10),
        ])

        let results = engine.match(query: "addr")
        XCTAssertEqual(results.map(\.trigger), ["addr", "address"])
    }

    func testIsExactMatch() {
        XCTAssertTrue(engine.isExactMatch("account"))
        XCTAssertFalse(engine.isExactMatch("acc"))
        XCTAssertFalse(engine.isExactMatch("zzz"))
    }

    func testFindByTrigger() {
        let snippet = engine.findExact(trigger: "email")
        XCTAssertNotNil(snippet)
        XCTAssertEqual(snippet?.replacement, "test@example.com")
    }

    func testUpdateSnippets() {
        engine.updateSnippets([Snippet(trigger: "new", replacement: "value")])
        XCTAssertEqual(engine.match(query: "").count, 1)
    }
}
