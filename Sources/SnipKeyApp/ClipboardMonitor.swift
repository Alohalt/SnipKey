import AppKit
import Foundation
import SnipKeyCore

protocol ClipboardMonitorDelegate: AnyObject {
    func clipboardMonitor(_ monitor: ClipboardMonitor, didRecord record: ClipboardRecord)
}

final class ClipboardMonitor {
    private struct IgnoredMutation {
        let content: String
        let expiresAt: Date
    }

    weak var delegate: ClipboardMonitorDelegate?

    private let historyStore: ClipboardHistoryStore
    private let pasteboard: NSPasteboard
    private let pollInterval: TimeInterval
    private let ignoredDuration: TimeInterval

    private var timer: Timer?
    private var lastKnownChangeCount: Int
    private var ignoredMutations: [IgnoredMutation] = []

    init(
        historyStore: ClipboardHistoryStore,
        pasteboard: NSPasteboard = .general,
        pollInterval: TimeInterval = 0.75,
        ignoredDuration: TimeInterval = 2.0
    ) {
        self.historyStore = historyStore
        self.pasteboard = pasteboard
        self.pollInterval = pollInterval
        self.ignoredDuration = ignoredDuration
        lastKnownChangeCount = pasteboard.changeCount
    }

    var isRunning: Bool {
        timer != nil
    }

    func start() {
        guard timer == nil else { return }

        lastKnownChangeCount = pasteboard.changeCount
        timer = Timer.scheduledTimer(withTimeInterval: pollInterval, repeats: true) { [weak self] _ in
            self?.pollPasteboard()
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        ignoredMutations.removeAll()
    }

    func ignoreNextCopy(of content: String?) {
        guard let content, content.isEmpty == false else { return }
        pruneIgnoredMutations()
        ignoredMutations.append(IgnoredMutation(content: content, expiresAt: Date().addingTimeInterval(ignoredDuration)))
    }

    private func pollPasteboard() {
        guard historyStore.settings.isMonitoringEnabled else {
            lastKnownChangeCount = pasteboard.changeCount
            return
        }

        let currentChangeCount = pasteboard.changeCount
        guard currentChangeCount != lastKnownChangeCount else { return }
        lastKnownChangeCount = currentChangeCount

        let content = pasteboard.string(forType: .string) ?? ""
        guard shouldRecord(content) else { return }
        guard let record = historyStore.recordCopy(content) else { return }
        delegate?.clipboardMonitor(self, didRecord: record)
    }

    private func shouldRecord(_ content: String) -> Bool {
        guard content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else { return false }

        pruneIgnoredMutations()
        if let index = ignoredMutations.firstIndex(where: { $0.content == content }) {
            ignoredMutations.remove(at: index)
            return false
        }

        return true
    }

    private func pruneIgnoredMutations() {
        let now = Date()
        ignoredMutations.removeAll { $0.expiresAt <= now }
    }
}