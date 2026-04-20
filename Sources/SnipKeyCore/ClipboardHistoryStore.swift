import Combine
import CryptoKit
import Foundation

private func clipboardContentHash(_ content: String) -> String {
    let digest = SHA256.hash(data: Data(content.utf8))
    return digest.map { String(format: "%02x", $0) }.joined()
}

private func mergedSuggestionStat(_ lhs: ClipboardSuggestionStat, _ rhs: ClipboardSuggestionStat) -> ClipboardSuggestionStat {
    var merged = lhs.lastCopiedAt >= rhs.lastCopiedAt ? lhs : rhs
    merged.copyCount = max(lhs.copyCount, rhs.copyCount)
    merged.lastPromptedCopyCount = max(lhs.lastPromptedCopyCount, rhs.lastPromptedCopyCount)

    switch (lhs.snippetCreatedAt, rhs.snippetCreatedAt) {
    case let (left?, right?) where right > left:
        merged.snippetCreatedAt = right
        merged.createdSnippetID = rhs.createdSnippetID
    case let (left?, _):
        merged.snippetCreatedAt = left
        merged.createdSnippetID = lhs.createdSnippetID
    case let (_, right?):
        merged.snippetCreatedAt = right
        merged.createdSnippetID = rhs.createdSnippetID
    default:
        merged.snippetCreatedAt = nil
        merged.createdSnippetID = nil
    }

    return merged
}

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

public struct ClipboardSuggestionStat: Codable, Equatable {
    public let contentHash: String
    public var copyCount: Int
    public var lastCopiedAt: Date
    public var lastPromptedCopyCount: Int
    public var snippetCreatedAt: Date?
    public var createdSnippetID: UUID?

    enum CodingKeys: String, CodingKey {
        case contentHash
        case copyCount
        case lastCopiedAt
        case lastPromptedCopyCount
        case snippetCreatedAt
        case createdSnippetID
    }

    public init(
        contentHash: String,
        copyCount: Int = 1,
        lastCopiedAt: Date = Date(),
        lastPromptedCopyCount: Int = 0,
        snippetCreatedAt: Date? = nil,
        createdSnippetID: UUID? = nil
    ) {
        self.contentHash = contentHash
        self.copyCount = max(1, copyCount)
        self.lastCopiedAt = lastCopiedAt
        self.lastPromptedCopyCount = max(0, lastPromptedCopyCount)
        self.snippetCreatedAt = snippetCreatedAt
        self.createdSnippetID = createdSnippetID
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        contentHash = try container.decode(String.self, forKey: .contentHash)
        copyCount = max(1, try container.decodeIfPresent(Int.self, forKey: .copyCount) ?? 1)
        lastCopiedAt = try container.decodeIfPresent(Date.self, forKey: .lastCopiedAt) ?? Date.distantPast
        lastPromptedCopyCount = max(0, try container.decodeIfPresent(Int.self, forKey: .lastPromptedCopyCount) ?? 0)
        snippetCreatedAt = try container.decodeIfPresent(Date.self, forKey: .snippetCreatedAt)
        createdSnippetID = try container.decodeIfPresent(UUID.self, forKey: .createdSnippetID)
    }
}

public struct ClipboardHistoryData: Codable, Equatable {
    public var records: [ClipboardRecord]
    public var settings: ClipboardSettings
    public var suggestionStats: [ClipboardSuggestionStat]

    enum CodingKeys: String, CodingKey {
        case records
        case settings
        case suggestionStats
    }

    public init(
        records: [ClipboardRecord] = [],
        settings: ClipboardSettings = ClipboardSettings(),
        suggestionStats: [ClipboardSuggestionStat] = []
    ) {
        self.records = records
        self.settings = settings
        self.suggestionStats = suggestionStats
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let decodedRecords = try container.decodeIfPresent([ClipboardRecord].self, forKey: .records) ?? []
        let decodedSettings = try container.decodeIfPresent(ClipboardSettings.self, forKey: .settings) ?? ClipboardSettings()
        let decodedSuggestionStats = try container.decodeIfPresent([ClipboardSuggestionStat].self, forKey: .suggestionStats)
            ?? Self.makeSuggestionStats(from: decodedRecords)

        records = decodedRecords
        settings = decodedSettings
        suggestionStats = decodedSuggestionStats
    }

    private static func makeSuggestionStats(from records: [ClipboardRecord]) -> [ClipboardSuggestionStat] {
        var statsByHash: [String: ClipboardSuggestionStat] = [:]

        for record in records {
            let contentHash = clipboardContentHash(record.content)
            let candidate = ClipboardSuggestionStat(
                contentHash: contentHash,
                copyCount: record.copyCount,
                lastCopiedAt: record.lastCopiedAt,
                lastPromptedCopyCount: record.lastPromptedCopyCount,
                snippetCreatedAt: record.snippetCreatedAt,
                createdSnippetID: record.createdSnippetID
            )

            if let existing = statsByHash[contentHash] {
                statsByHash[contentHash] = mergedSuggestionStat(existing, candidate)
            } else {
                statsByHash[contentHash] = candidate
            }
        }

        return Array(statsByHash.values)
    }
}

public final class ClipboardHistoryStore: ObservableObject {
    public static let defaultMaxRecordCount = 50

    private static let currentAppSupportDirectoryName = "SnipKey"

    @Published public private(set) var records: [ClipboardRecord] = []
    @Published public private(set) var settings: ClipboardSettings = ClipboardSettings()

    private let fileURL: URL
    private let maxRecordCount: Int
    private let now: () -> Date
    private var suggestionStats: [ClipboardSuggestionStat] = []

    public init(
        fileURL: URL? = nil,
        maxRecordCount: Int = ClipboardHistoryStore.defaultMaxRecordCount,
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
        let existingRecord = records.first(where: { $0.content == content })
        let suggestionStat = registerCopy(for: content, at: timestamp, fallbackRecord: existingRecord)

        if let index = records.firstIndex(where: { $0.content == content }) {
            let existing = records.remove(at: index)
            let record = synchronizedRecord(existing, with: suggestionStat)
            records.insert(record, at: 0)
            trimRecordsIfNeeded()
            save()
            return record
        }

        let record = makeRecord(content: content, using: suggestionStat)
        records.insert(record, at: 0)
        trimRecordsIfNeeded()
        save()
        return record
    }

    public func shouldSuggestKey(for record: ClipboardRecord) -> Bool {
        guard settings.isMonitoringEnabled else { return false }

        let suggestionStat = suggestionStat(for: record.content)
        let snippetCreatedAt = suggestionStat?.snippetCreatedAt ?? record.snippetCreatedAt
        let copyCount = suggestionStat?.copyCount ?? record.copyCount
        let lastPromptedCopyCount = suggestionStat?.lastPromptedCopyCount ?? record.lastPromptedCopyCount

        guard snippetCreatedAt == nil else { return false }
        return copyCount - lastPromptedCopyCount >= settings.suggestionThreshold
    }

    public func markPrompted(for id: UUID) {
        guard let record = records.first(where: { $0.id == id }) else { return }

        let updatedStat = updateSuggestionStat(for: record.content, fallbackRecord: record) { suggestionStat in
            suggestionStat.lastPromptedCopyCount = suggestionStat.copyCount
        }

        applySuggestionStat(updatedStat, toRecordsMatching: record.content)
        save()
    }

    public func markCreatedSnippet(for id: UUID, snippetID: UUID) {
        guard let record = records.first(where: { $0.id == id }) else { return }

        let timestamp = now()
        let updatedStat = updateSuggestionStat(for: record.content, fallbackRecord: record) { suggestionStat in
            suggestionStat.snippetCreatedAt = timestamp
            suggestionStat.createdSnippetID = snippetID
            suggestionStat.lastPromptedCopyCount = suggestionStat.copyCount
        }

        applySuggestionStat(updatedStat, toRecordsMatching: record.content)
        save()
    }

    public func clearCreatedSnippetAssociation(for snippetID: UUID, matchingContent content: String? = nil) {
        var didChange = false
        let legacyContentHash = content.map(clipboardContentHash)

        for index in suggestionStats.indices {
            let matchesLinkedSnippet = suggestionStats[index].createdSnippetID == snippetID
            let matchesLegacyContent = legacyContentHash.map {
                suggestionStats[index].contentHash == $0 && suggestionStats[index].snippetCreatedAt != nil
            } ?? false
            guard matchesLinkedSnippet || matchesLegacyContent else { continue }

            suggestionStats[index].snippetCreatedAt = nil
            suggestionStats[index].createdSnippetID = nil
            didChange = true
        }

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
        suggestionStats.removeAll()
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
        let data = ClipboardHistoryData(records: records, settings: settings, suggestionStats: suggestionStats)

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
            suggestionStats = decoded.suggestionStats

            let didRecoverMissingStats = recoverMissingSuggestionStatsIfNeeded()
            let didSynchronizeRecords = synchronizeRecordsWithSuggestionStats()
            let didTrimRecords = trimRecordsIfNeeded()

            if didRecoverMissingStats || didSynchronizeRecords || didTrimRecords {
                save()
            }
        } catch {
            print("Failed to load clipboard history: \(error)")
        }
    }

    private func registerCopy(
        for content: String,
        at timestamp: Date,
        fallbackRecord: ClipboardRecord?
    ) -> ClipboardSuggestionStat {
        let contentHash = clipboardContentHash(content)

        if let index = suggestionStats.firstIndex(where: { $0.contentHash == contentHash }) {
            var suggestionStat = suggestionStats[index]
            suggestionStat.copyCount += 1
            suggestionStat.lastCopiedAt = timestamp
            suggestionStats[index] = suggestionStat
            return suggestionStat
        }

        let suggestionStat: ClipboardSuggestionStat
        if let fallbackRecord {
            suggestionStat = ClipboardHistoryStore.makeSuggestionStat(from: fallbackRecord, contentHash: contentHash)
        } else {
            suggestionStat = ClipboardSuggestionStat(contentHash: contentHash, copyCount: 1, lastCopiedAt: timestamp)
            suggestionStats.append(suggestionStat)
            return suggestionStat
        }

        var incrementedSuggestionStat = suggestionStat
        incrementedSuggestionStat.copyCount += 1
        incrementedSuggestionStat.lastCopiedAt = timestamp
        suggestionStats.append(incrementedSuggestionStat)
        return incrementedSuggestionStat
    }

    private func suggestionStat(for content: String) -> ClipboardSuggestionStat? {
        let contentHash = clipboardContentHash(content)
        return suggestionStats.first { $0.contentHash == contentHash }
    }

    private func updateSuggestionStat(
        for content: String,
        fallbackRecord: ClipboardRecord?,
        transform: (inout ClipboardSuggestionStat) -> Void
    ) -> ClipboardSuggestionStat {
        let contentHash = clipboardContentHash(content)

        if let index = suggestionStats.firstIndex(where: { $0.contentHash == contentHash }) {
            var suggestionStat = suggestionStats[index]
            transform(&suggestionStat)
            suggestionStats[index] = suggestionStat
            return suggestionStat
        }

        let baseSuggestionStat = fallbackRecord.map {
            ClipboardHistoryStore.makeSuggestionStat(from: $0, contentHash: contentHash)
        } ?? ClipboardSuggestionStat(contentHash: contentHash, copyCount: 1, lastCopiedAt: now())

        var suggestionStat = baseSuggestionStat
        transform(&suggestionStat)
        suggestionStats.append(suggestionStat)
        return suggestionStat
    }

    private func applySuggestionStat(_ suggestionStat: ClipboardSuggestionStat, toRecordsMatching content: String) {
        for index in records.indices where records[index].content == content {
            records[index] = synchronizedRecord(records[index], with: suggestionStat)
        }
        records.sort { $0.lastCopiedAt > $1.lastCopiedAt }
    }

    private func recoverMissingSuggestionStatsIfNeeded() -> Bool {
        var didChange = false

        for record in records {
            guard suggestionStat(for: record.content) == nil else { continue }
            suggestionStats.append(Self.makeSuggestionStat(from: record))
            didChange = true
        }

        return didChange
    }

    private func synchronizeRecordsWithSuggestionStats() -> Bool {
        var didChange = false

        for index in records.indices {
            guard let suggestionStat = suggestionStat(for: records[index].content) else { continue }

            let synchronized = synchronizedRecord(records[index], with: suggestionStat)
            guard synchronized != records[index] else { continue }

            records[index] = synchronized
            didChange = true
        }

        if didChange {
            records.sort { $0.lastCopiedAt > $1.lastCopiedAt }
        }

        return didChange
    }

    private func synchronizedRecord(_ record: ClipboardRecord, with suggestionStat: ClipboardSuggestionStat) -> ClipboardRecord {
        var synchronized = record
        synchronized.copyCount = suggestionStat.copyCount
        synchronized.lastCopiedAt = suggestionStat.lastCopiedAt
        synchronized.lastPromptedCopyCount = suggestionStat.lastPromptedCopyCount
        synchronized.snippetCreatedAt = suggestionStat.snippetCreatedAt
        synchronized.createdSnippetID = suggestionStat.createdSnippetID
        return synchronized
    }

    private func makeRecord(content: String, using suggestionStat: ClipboardSuggestionStat, id: UUID = UUID()) -> ClipboardRecord {
        ClipboardRecord(
            id: id,
            content: content,
            copyCount: suggestionStat.copyCount,
            lastCopiedAt: suggestionStat.lastCopiedAt,
            lastPromptedCopyCount: suggestionStat.lastPromptedCopyCount,
            snippetCreatedAt: suggestionStat.snippetCreatedAt,
            createdSnippetID: suggestionStat.createdSnippetID
        )
    }

    private static func makeSuggestionStat(from record: ClipboardRecord, contentHash: String? = nil) -> ClipboardSuggestionStat {
        ClipboardSuggestionStat(
            contentHash: contentHash ?? clipboardContentHash(record.content),
            copyCount: record.copyCount,
            lastCopiedAt: record.lastCopiedAt,
            lastPromptedCopyCount: record.lastPromptedCopyCount,
            snippetCreatedAt: record.snippetCreatedAt,
            createdSnippetID: record.createdSnippetID
        )
    }

    @discardableResult
    private func trimRecordsIfNeeded() -> Bool {
        guard records.count > maxRecordCount else { return false }
        records.removeLast(records.count - maxRecordCount)
        return true
    }

    private static func defaultFileURL() -> URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let currentDirectory = appSupport.appendingPathComponent(currentAppSupportDirectoryName)
        let currentFileURL = currentDirectory.appendingPathComponent("clipboard-history.json")

        try? FileManager.default.createDirectory(at: currentDirectory, withIntermediateDirectories: true)
        return currentFileURL
    }
}