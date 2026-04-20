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

    func testRecordCopyKeepsOnlyMostRecentRecordsUpToMaxCount() {
        let limitedStore = ClipboardHistoryStore(fileURL: tempURL, maxRecordCount: 3, now: { [unowned self] in
            currentDate
        })

        _ = limitedStore.recordCopy("one")
        currentDate = currentDate.addingTimeInterval(1)
        _ = limitedStore.recordCopy("two")
        currentDate = currentDate.addingTimeInterval(1)
        _ = limitedStore.recordCopy("three")
        currentDate = currentDate.addingTimeInterval(1)
        _ = limitedStore.recordCopy("four")

        XCTAssertEqual(limitedStore.records.map(\.content), ["four", "three", "two"])
    }

    func testEvictedRecordKeepsSuggestionCountForFutureCopies() {
        let limitedStore = ClipboardHistoryStore(fileURL: tempURL, maxRecordCount: 2, now: { [unowned self] in
            currentDate
        })

        _ = limitedStore.recordCopy("hello")
        currentDate = currentDate.addingTimeInterval(1)
        _ = limitedStore.recordCopy("hello")
        currentDate = currentDate.addingTimeInterval(1)
        _ = limitedStore.recordCopy("two")
        currentDate = currentDate.addingTimeInterval(1)
        _ = limitedStore.recordCopy("three")

        XCTAssertFalse(limitedStore.records.contains { $0.content == "hello" })

        currentDate = currentDate.addingTimeInterval(1)
        let record = limitedStore.recordCopy("hello")

        XCTAssertEqual(record?.copyCount, 3)
        XCTAssertEqual(limitedStore.records.map(\.content), ["hello", "three"])
        XCTAssertTrue(limitedStore.shouldSuggestKey(for: record!))
    }

    func testDeleteRecordKeepsSuggestionCountForFutureCopiesAfterReload() {
        currentDate = currentDate.addingTimeInterval(1)
        let record = store.recordCopy("hello")
        currentDate = currentDate.addingTimeInterval(1)
        _ = store.recordCopy("hello")

        store.deleteRecord(id: record!.id)

        let reloadedStore = ClipboardHistoryStore(fileURL: tempURL, now: { [unowned self] in
            currentDate
        })
        currentDate = currentDate.addingTimeInterval(1)
        let reloadedRecord = reloadedStore.recordCopy("hello")

        XCTAssertEqual(reloadedStore.records.count, 1)
        XCTAssertEqual(reloadedRecord?.copyCount, 3)
    }

    func testClearHistoryResetsSuggestionCount() {
        _ = store.recordCopy("hello")
        currentDate = currentDate.addingTimeInterval(1)
        _ = store.recordCopy("hello")

        store.clearHistory()

        currentDate = currentDate.addingTimeInterval(1)
        let record = store.recordCopy("hello")

        XCTAssertEqual(record?.copyCount, 1)
    }

    func testLoadTrimsOversizedHistoryAndCompactsPersistedFile() throws {
        let records = (0..<5).map { offset in
            ClipboardRecord(
                content: "item-\(offset)",
                lastCopiedAt: currentDate.addingTimeInterval(TimeInterval(offset))
            )
        }
        let data = ClipboardHistoryData(records: records, settings: ClipboardSettings())
        let encoded = try JSONEncoder().encode(data)
        try encoded.write(to: tempURL, options: .atomic)

        let limitedStore = ClipboardHistoryStore(fileURL: tempURL, maxRecordCount: 3, now: { [unowned self] in
            currentDate
        })
        let persisted = try JSONDecoder().decode(ClipboardHistoryData.self, from: Data(contentsOf: tempURL))

        XCTAssertEqual(limitedStore.records.map(\.content), ["item-4", "item-3", "item-2"])
        XCTAssertEqual(persisted.records.map(\.content), ["item-4", "item-3", "item-2"])
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