import Combine
import Foundation

public struct ClipboardRecord: Codable, Identifiable, Equatable {
    public let id: UUID
    public var content: String
    public var copyCount: Int
    public var lastCopiedAt: Date
    public var lastPromptedCopyCount: Int
    public var snippetCreatedAt: Date?
    public var createdSnippetID: UUID?

    enum CodingKeys: String, CodingKey {
        case id
        case content
        case copyCount
        case lastCopiedAt
        case lastPromptedCopyCount
        case snippetCreatedAt
        case createdSnippetID
    }

    private enum LegacyCodingKeys: String, CodingKey {
        case firstCopiedAt
    }

    public init(
        id: UUID = UUID(),
        content: String,
        copyCount: Int = 1,
        lastCopiedAt: Date = Date(),
        lastPromptedCopyCount: Int = 0,
        snippetCreatedAt: Date? = nil,
        createdSnippetID: UUID? = nil
    ) {
        self.id = id
        self.content = content
        self.copyCount = max(1, copyCount)
        self.lastCopiedAt = lastCopiedAt
        self.lastPromptedCopyCount = max(0, lastPromptedCopyCount)
        self.snippetCreatedAt = snippetCreatedAt
        self.createdSnippetID = createdSnippetID
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let legacyContainer = try decoder.container(keyedBy: LegacyCodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        content = try container.decode(String.self, forKey: .content)
        copyCount = max(1, try container.decodeIfPresent(Int.self, forKey: .copyCount) ?? 1)
        lastCopiedAt = try container.decodeIfPresent(Date.self, forKey: .lastCopiedAt)
            ?? legacyContainer.decodeIfPresent(Date.self, forKey: .firstCopiedAt)
            ?? Date.distantPast
        lastPromptedCopyCount = max(0, try container.decodeIfPresent(Int.self, forKey: .lastPromptedCopyCount) ?? 0)
        snippetCreatedAt = try container.decodeIfPresent(Date.self, forKey: .snippetCreatedAt)
        createdSnippetID = try container.decodeIfPresent(UUID.self, forKey: .createdSnippetID)
    }
}

public struct ClipboardSettings: Codable, Equatable {
    public var isMonitoringEnabled: Bool
    public var suggestionThreshold: Int

    enum CodingKeys: String, CodingKey {
        case isMonitoringEnabled
        case suggestionThreshold
    }

    public init(isMonitoringEnabled: Bool = true, suggestionThreshold: Int = 3) {
        self.isMonitoringEnabled = isMonitoringEnabled
        self.suggestionThreshold = max(2, suggestionThreshold)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        isMonitoringEnabled = try container.decodeIfPresent(Bool.self, forKey: .isMonitoringEnabled) ?? true
        suggestionThreshold = max(2, try container.decodeIfPresent(Int.self, forKey: .suggestionThreshold) ?? 3)
    }
}

public struct ClipboardHistoryData: Codable, Equatable {
    public var records: [ClipboardRecord]
    public var settings: ClipboardSettings

    public init(records: [ClipboardRecord] = [], settings: ClipboardSettings = ClipboardSettings()) {
        self.records = records
        self.settings = settings
    }
}

public final class ClipboardHistoryStore: ObservableObject {
    private static let currentAppSupportDirectoryName = "SnipKey"

    @Published public private(set) var records: [ClipboardRecord] = []
    @Published public private(set) var settings: ClipboardSettings = ClipboardSettings()

    private let fileURL: URL
    private let maxRecordCount: Int
    private let now: () -> Date

    public init(
        fileURL: URL? = nil,
        maxRecordCount: Int = 50,
        now: @escaping () -> Date = Date.init
    ) {
        self.fileURL = fileURL ?? Self.defaultFileURL()
        self.maxRecordCount = max(1, maxRecordCount)
        self.now = now
        load()
    }

    @discardableResult
    public func recordCopy(_ content: String) -> ClipboardRecord? {
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedContent.isEmpty == false else { return nil }

        let timestamp = now()

        if let index = records.firstIndex(where: { $0.content == content }) {
            var record = records.remove(at: index)
            record.copyCount += 1
            record.lastCopiedAt = timestamp
            records.insert(record, at: 0)
            trimRecordsIfNeeded()
            save()
            return record
        }

        let record = ClipboardRecord(
            content: content,
            copyCount: 1,
            lastCopiedAt: timestamp
        )
        records.insert(record, at: 0)
        trimRecordsIfNeeded()
        save()
        return record
    }

    public func shouldSuggestKey(for record: ClipboardRecord) -> Bool {
        guard settings.isMonitoringEnabled else { return false }
        guard record.snippetCreatedAt == nil else { return false }
        return record.copyCount - record.lastPromptedCopyCount >= settings.suggestionThreshold
    }

    public func markPrompted(for id: UUID) {
        updateRecord(id: id) { record in
            record.lastPromptedCopyCount = record.copyCount
        }
    }

    public func markCreatedSnippet(for id: UUID, snippetID: UUID) {
        updateRecord(id: id) { record in
            record.snippetCreatedAt = now()
            record.createdSnippetID = snippetID
            record.lastPromptedCopyCount = record.copyCount
        }
    }

    public func clearCreatedSnippetAssociation(for snippetID: UUID, matchingContent content: String? = nil) {
        var didChange = false

        for index in records.indices {
            let matchesLinkedSnippet = records[index].createdSnippetID == snippetID
            let matchesLegacyContent = content.map { records[index].content == $0 && records[index].snippetCreatedAt != nil } ?? false
            guard matchesLinkedSnippet || matchesLegacyContent else { continue }

            records[index].snippetCreatedAt = nil
            records[index].createdSnippetID = nil
            didChange = true
        }

        guard didChange else { return }
        save()
    }

    public func deleteRecord(id: UUID) {
        records.removeAll { $0.id == id }
        save()
    }

    public func clearHistory() {
        records.removeAll()
        save()
    }

    public func updateSettings(_ settings: ClipboardSettings) {
        self.settings = ClipboardSettings(
            isMonitoringEnabled: settings.isMonitoringEnabled,
            suggestionThreshold: settings.suggestionThreshold
        )
        save()
    }

    public func save() {
        let data = ClipboardHistoryData(records: records, settings: settings)

        do {
            let encoded = try JSONEncoder().encode(data)
            try encoded.write(to: fileURL, options: .atomic)
        } catch {
            print("Failed to save clipboard history: \(error)")
        }
    }

    public func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }

        do {
            let data = try Data(contentsOf: fileURL)
            let decoded = try JSONDecoder().decode(ClipboardHistoryData.self, from: data)
            records = decoded.records.sorted { $0.lastCopiedAt > $1.lastCopiedAt }
            settings = decoded.settings
            trimRecordsIfNeeded()
        } catch {
            print("Failed to load clipboard history: \(error)")
        }
    }

    private func updateRecord(id: UUID, transform: (inout ClipboardRecord) -> Void) {
        guard let index = records.firstIndex(where: { $0.id == id }) else { return }

        var record = records[index]
        transform(&record)
        records[index] = record
        records.sort { $0.lastCopiedAt > $1.lastCopiedAt }
        save()
    }

    private func trimRecordsIfNeeded() {
        guard records.count > maxRecordCount else { return }
        records.removeLast(records.count - maxRecordCount)
    }

    private static func defaultFileURL() -> URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let currentDirectory = appSupport.appendingPathComponent(currentAppSupportDirectoryName)
        let currentFileURL = currentDirectory.appendingPathComponent("clipboard-history.json")

        try? FileManager.default.createDirectory(at: currentDirectory, withIntermediateDirectories: true)
        return currentFileURL
    }
}