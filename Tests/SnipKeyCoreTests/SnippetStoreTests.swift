import XCTest
@testable import SnipKeyCore

final class SnippetStoreTests: XCTestCase {
    var store: SnippetStore!
    var tempURL: URL!

    override func setUp() {
        super.setUp()
        tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("json")
        store = SnippetStore(fileURL: tempURL)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempURL)
        super.tearDown()
    }

    func testAddSnippet() {
        let snippet = Snippet(trigger: "email", replacement: "test@example.com")
        store.addSnippet(snippet)
        XCTAssertEqual(store.snippets.count, 1)
        XCTAssertEqual(store.snippets.first?.trigger, "email")
    }

    func testUpdateSnippet() {
        var snippet = Snippet(trigger: "email", replacement: "old@example.com")
        store.addSnippet(snippet)
        snippet.replacement = "new@example.com"
        store.updateSnippet(snippet)
        XCTAssertEqual(store.snippets.first?.replacement, "new@example.com")
    }

    func testDeleteSnippet() {
        let snippet = Snippet(trigger: "email", replacement: "test@example.com")
        store.addSnippet(snippet)
        store.deleteSnippet(id: snippet.id)
        XCTAssertTrue(store.snippets.isEmpty)
    }

    func testRecordAcceptancePersistsCount() {
        let snippet = Snippet(trigger: "email", replacement: "test@example.com")
        store.addSnippet(snippet)

        store.recordAcceptance(for: snippet.id)
        store.recordAcceptance(for: snippet.id)

        XCTAssertEqual(store.snippets.first?.acceptanceCount, 2)

        let reloadedStore = SnippetStore(fileURL: tempURL)
        reloadedStore.load()
        XCTAssertEqual(reloadedStore.snippets.first?.acceptanceCount, 2)
    }

    func testAddGroup() {
        let group = SnippetGroup(name: "Work")
        store.addGroup(group)
        XCTAssertEqual(store.groups.count, 1)
        XCTAssertEqual(store.groups.first?.name, "Work")
    }

    func testUpdateGroup() {
        var group = SnippetGroup(name: "Work")
        store.addGroup(group)

        group.name = "Personal"
        store.updateGroup(group)

        XCTAssertEqual(store.groups.first?.name, "Personal")
    }

    func testDeleteGroupRemovesGroupIdFromSnippets() {
        let group = SnippetGroup(name: "Work")
        store.addGroup(group)
        let snippet = Snippet(trigger: "email", replacement: "work@co.com", groupId: group.id)
        store.addSnippet(snippet)
        store.deleteGroup(id: group.id)
        XCTAssertTrue(store.groups.isEmpty)
        XCTAssertNil(store.snippets.first?.groupId)
    }

    func testPersistenceRoundTrip() {
        let snippet = Snippet(trigger: "addr", replacement: "123 Main St")
        store.addSnippet(snippet)
        store.save()

        let store2 = SnippetStore(fileURL: tempURL)
        store2.load()
        XCTAssertEqual(store2.snippets.count, 1)
        XCTAssertEqual(store2.snippets.first?.trigger, "addr")
    }

    func testSnippetsForGroup() {
        let group = SnippetGroup(name: "Work")
        store.addGroup(group)
        store.addSnippet(Snippet(trigger: "a", replacement: "1", groupId: group.id))
        store.addSnippet(Snippet(trigger: "b", replacement: "2", groupId: nil))
        XCTAssertEqual(store.snippets(forGroup: group.id).count, 1)
    }

    func testUngroupedSnippets() {
        let group = SnippetGroup(name: "Work")
        store.addGroup(group)
        store.addSnippet(Snippet(trigger: "a", replacement: "1", groupId: group.id))
        store.addSnippet(Snippet(trigger: "b", replacement: "2"))
        XCTAssertEqual(store.ungroupedSnippets.count, 1)
        XCTAssertEqual(store.ungroupedSnippets.first?.trigger, "b")
    }

    func testExportImport() throws {
        store.addSnippet(Snippet(trigger: "x", replacement: "y"))
        let exportURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("export-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: exportURL) }

        try store.exportData(to: exportURL)

        let store2 = SnippetStore(fileURL: tempURL)
        try store2.importData(from: exportURL)
        XCTAssertEqual(store2.snippets.count, 1)
        XCTAssertEqual(store2.snippets.first?.trigger, "x")
    }
}
