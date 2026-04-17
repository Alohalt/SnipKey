import XCTest
@testable import SnipKeyCore

final class ClipboardHistoryStoreTests: XCTestCase {
    private var store: ClipboardHistoryStore!
    private var tempURL: URL!
    private var currentDate: Date!

    override func setUp() {
        super.setUp()
        tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("json")
        currentDate = Date(timeIntervalSince1970: 1_000)
        store = ClipboardHistoryStore(fileURL: tempURL, now: { [unowned self] in
            currentDate
        })
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempURL)
        currentDate = nil
        store = nil
        super.tearDown()
    }

    func testRecordCopyAddsAndIncrementsExistingRecord() {
        let firstRecord = store.recordCopy("hello")
        currentDate = currentDate.addingTimeInterval(5)
        let secondRecord = store.recordCopy("hello")

        XCTAssertEqual(store.records.count, 1)
        XCTAssertEqual(firstRecord?.copyCount, 1)
        XCTAssertEqual(secondRecord?.copyCount, 2)
        XCTAssertEqual(store.records.first?.lastCopiedAt, currentDate)
    }

    func testShouldSuggestAtThresholdAndAgainAfterAnotherThresholdWindow() {
        var record = store.recordCopy("hello")
        XCTAssertFalse(store.shouldSuggestKey(for: record!))

        currentDate = currentDate.addingTimeInterval(1)
        record = store.recordCopy("hello")
        XCTAssertFalse(store.shouldSuggestKey(for: record!))

        currentDate = currentDate.addingTimeInterval(1)
        record = store.recordCopy("hello")
        XCTAssertTrue(store.shouldSuggestKey(for: record!))

        store.markPrompted(for: record!.id)
        XCTAssertFalse(store.shouldSuggestKey(for: store.records.first!))

        currentDate = currentDate.addingTimeInterval(1)
        _ = store.recordCopy("hello")
        currentDate = currentDate.addingTimeInterval(1)
        _ = store.recordCopy("hello")
        currentDate = currentDate.addingTimeInterval(1)
        record = store.recordCopy("hello")

        XCTAssertTrue(store.shouldSuggestKey(for: record!))
    }

    func testMarkCreatedSnippetStopsFutureSuggestions() {
        currentDate = currentDate.addingTimeInterval(1)
        _ = store.recordCopy("hello")
        currentDate = currentDate.addingTimeInterval(1)
        let record = store.recordCopy("hello")
        let snippetID = UUID()

        store.markCreatedSnippet(for: record!.id, snippetID: snippetID)

        XCTAssertFalse(store.shouldSuggestKey(for: store.records.first!))
        XCTAssertNotNil(store.records.first?.snippetCreatedAt)
        XCTAssertEqual(store.records.first?.createdSnippetID, snippetID)
    }

    func testClearCreatedSnippetAssociationResetsCreatedStateForLinkedSnippet() {
        currentDate = currentDate.addingTimeInterval(1)
        let record = store.recordCopy("hello")
        let snippetID = UUID()

        store.markCreatedSnippet(for: record!.id, snippetID: snippetID)
        store.clearCreatedSnippetAssociation(for: snippetID)

        XCTAssertNil(store.records.first?.snippetCreatedAt)
        XCTAssertNil(store.records.first?.createdSnippetID)
    }

    func testClearCreatedSnippetAssociationResetsLegacyContentMatch() {
        currentDate = currentDate.addingTimeInterval(1)
        let legacyRecord = ClipboardRecord(
            content: "hello",
            copyCount: 2,
            lastCopiedAt: currentDate,
            lastPromptedCopyCount: 2,
            snippetCreatedAt: currentDate,
            createdSnippetID: nil
        )
        let data = ClipboardHistoryData(records: [legacyRecord], settings: ClipboardSettings())
        let encoded = try! JSONEncoder().encode(data)
        try! encoded.write(to: tempURL, options: .atomic)

        let legacyStore = ClipboardHistoryStore(fileURL: tempURL, now: { [unowned self] in
            currentDate
        })
        legacyStore.clearCreatedSnippetAssociation(for: UUID(), matchingContent: "hello")

        XCTAssertNil(legacyStore.records.first?.snippetCreatedAt)
        XCTAssertNil(legacyStore.records.first?.createdSnippetID)
    }

    func testUpdateSettingsPersists() {
        store.updateSettings(ClipboardSettings(isMonitoringEnabled: false, suggestionThreshold: 5))

        let reloadedStore = ClipboardHistoryStore(fileURL: tempURL)
        reloadedStore.load()

        XCTAssertEqual(reloadedStore.settings, ClipboardSettings(isMonitoringEnabled: false, suggestionThreshold: 5))
    }

        func testRecordDecodesLegacyFirstCopiedAtIntoLastCopiedAt() throws {
        let id = UUID()
        let json = """
        {
                    \"id\": \"\(id.uuidString)\",
          \"content\": \"hello\",
          \"copyCount\": 2,
                    \"firstCopiedAt\": 100
        }
        """
        .replacingOccurrences(of: "\n        ", with: "\n")
        .data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        let record = try decoder.decode(ClipboardRecord.self, from: json)

        XCTAssertEqual(record.id, id)
        XCTAssertEqual(record.lastCopiedAt, Date(timeIntervalSince1970: 100))
        XCTAssertEqual(record.lastPromptedCopyCount, 0)
        XCTAssertNil(record.snippetCreatedAt)
        XCTAssertNil(record.createdSnippetID)
    }
}