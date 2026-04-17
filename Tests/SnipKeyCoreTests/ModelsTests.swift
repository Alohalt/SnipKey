import XCTest
@testable import SnipKeyCore

final class ModelsTests: XCTestCase {
    func testSnippetCreation() {
        let snippet = Snippet(trigger: "account", replacement: "account1")
        XCTAssertEqual(snippet.trigger, "account")
        XCTAssertEqual(snippet.replacement, "account1")
        XCTAssertNil(snippet.groupId)
        XCTAssertEqual(snippet.acceptanceCount, 0)
    }

    func testSnippetGroupCreation() {
        let group = SnippetGroup(name: "Work")
        XCTAssertEqual(group.name, "Work")
    }

    func testSnippetCodable() throws {
        let snippet = Snippet(trigger: "email", replacement: "test@example.com")
        let data = try JSONEncoder().encode(snippet)
        let decoded = try JSONDecoder().decode(Snippet.self, from: data)
        XCTAssertEqual(snippet, decoded)
    }

    func testSnippetDataCodable() throws {
        let group = SnippetGroup(name: "Personal")
        let snippet = Snippet(trigger: "addr", replacement: "123 Main St", groupId: group.id)
        let snippetData = SnippetData(snippets: [snippet], groups: [group])
        let data = try JSONEncoder().encode(snippetData)
        let decoded = try JSONDecoder().decode(SnippetData.self, from: data)
        XCTAssertEqual(snippetData, decoded)
    }

    func testSnippetDecodesMissingAcceptanceCountAsZero() throws {
        let id = UUID()
        let json = """
        {
          \"id\": \"\(id.uuidString)\",
          \"trigger\": \"email\",
          \"replacement\": \"test@example.com\"
        }
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(Snippet.self, from: json)
        XCTAssertEqual(decoded.id, id)
        XCTAssertEqual(decoded.acceptanceCount, 0)
    }
}
