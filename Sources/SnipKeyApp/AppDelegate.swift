import Cocoa
import Combine
import SnipKeyCore

class AppDelegate: NSObject, NSApplicationDelegate {
    private let hasShownOnboardingGuideKey = "SnipKey.hasShownOnboardingGuide"
    private let store = SnippetStore()
    private let clipboardHistoryStore = ClipboardHistoryStore()
    private let engine = SnippetEngine()
    private let keyboardMonitor = KeyboardMonitor()
    private lazy var clipboardMonitor = ClipboardMonitor(historyStore: clipboardHistoryStore)
    private let textReplacer = TextReplacer()
    private lazy var completionPanel: CompletionPanel = {
        let panel = CompletionPanel()
        panel.onConfirmSelection = { [weak self] snippet in
            self?.confirmCompletionSelection(snippet)
        }
        return panel
    }()
    private let menuBarController = MenuBarController()
    private lazy var settingsWindow = SettingsWindow(store: store, clipboardHistoryStore: clipboardHistoryStore)
    private var cancellables = Set<AnyCancellable>()

    private var accessibilityCheckTimer: Timer?
    private var lastKnownCursorPosition: NSPoint?
    private var isPresentingClipboardSuggestion = false
    private var globalMouseMonitor: Any?
    private var localMouseMonitor: Any?

    @objc func openSettingsFromAppMenu(_ sender: Any?) {
        settingsWindow.show()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        print("[SnipKey] === App Launch Diagnostics ===")
        print("[SnipKey] Bundle ID: \(Bundle.main.bundleIdentifier ?? "nil")")
        print("[SnipKey] Accessibility enabled: \(AccessibilityHelper.isAccessibilityEnabled)")
        print("[SnipKey] Snippets loaded from store: \(store.snippets.count)")
        for s in store.snippets {
            print("[SnipKey]   trigger='\(s.trigger)' replacement='\(s.replacement)'")
        }

        // Setup engine with current snippets
        engine.updateSnippets(store.snippets)

        // Observe snippet changes
        store.$snippets
            .receive(on: RunLoop.main)
            .sink { [weak self] snippets in
                print("[SnipKey] Snippets changed, count=\(snippets.count)")
                self?.engine.updateSnippets(snippets)
            }
            .store(in: &cancellables)

        // Setup keyboard monitor
        keyboardMonitor.delegate = self
        startKeyboardMonitorWithAccessibilityCheck()
        startOutsidePanelClickMonitoring()

        clipboardMonitor.delegate = self
        clipboardMonitor.start()

        textReplacer.onClipboardWrite = { [weak self] content in
            self?.clipboardMonitor.ignoreNextCopy(of: content)
        }

        // Setup menu bar
        menuBarController.delegate = self
        menuBarController.setup()

        showOnboardingIfNeeded()

        print("[SnipKey] === Launch complete ===")
    }

    private func showOnboardingIfNeeded() {
        let defaults = UserDefaults.standard
        guard defaults.bool(forKey: hasShownOnboardingGuideKey) == false else { return }

        defaults.set(true, forKey: hasShownOnboardingGuideKey)
        DispatchQueue.main.async { [weak self] in
            self?.settingsWindow.show(showOnboarding: true)
        }
    }

    private func startKeyboardMonitorWithAccessibilityCheck() {
        print("[SnipKey] Attempting to start keyboard monitor...")
        print("[SnipKey] Process path: \(Bundle.main.executablePath ?? "unknown")")

        // Try to create event tap directly — don't gate on AXIsProcessTrusted
        // as it may report false on macOS 26 even when permission is granted.
        keyboardMonitor.start()

        if keyboardMonitor.isRunning {
            print("[SnipKey] Keyboard monitor started successfully!")
            accessibilityCheckTimer?.invalidate()
            accessibilityCheckTimer = nil
            return
        }

        // Event tap failed — prompt user and poll for retry
        print("[SnipKey] Event tap creation failed. Prompting for keyboard access if needed...")
        AccessibilityHelper.requestAccessibilityIfNeeded()

        accessibilityCheckTimer?.invalidate()
        var pollCount = 0
        accessibilityCheckTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] timer in
            guard let self else { timer.invalidate(); return }
            pollCount += 1

            // Try creating the tap again directly
            self.keyboardMonitor.start()

            if self.keyboardMonitor.isRunning {
                timer.invalidate()
                self.accessibilityCheckTimer = nil
                print("[SnipKey] Poll #\(pollCount): Event tap created! Keyboard monitor running.")
            } else {
                print("[SnipKey] Poll #\(pollCount): Event tap still failing...")
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        accessibilityCheckTimer?.invalidate()
        stopOutsidePanelClickMonitoring()
        keyboardMonitor.stop()
        clipboardMonitor.stop()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            settingsWindow.show()
        }
        return true
    }
}

// MARK: - ClipboardMonitorDelegate

extension AppDelegate: ClipboardMonitorDelegate {
    func clipboardMonitor(_ monitor: ClipboardMonitor, didRecord record: ClipboardRecord) {
        if let existingSnippet = store.snippets.first(where: { $0.replacement == record.content }) {
            clipboardHistoryStore.markCreatedSnippet(for: record.id, snippetID: existingSnippet.id)
            print("[SnipKey] Clipboard content already exists as snippet '\(existingSnippet.trigger)'.")
            return
        }

        guard clipboardHistoryStore.shouldSuggestKey(for: record) else { return }
        guard isPresentingClipboardSuggestion == false else { return }

        clipboardHistoryStore.markPrompted(for: record.id)
        isPresentingClipboardSuggestion = true

        DispatchQueue.main.async { [weak self] in
            self?.presentClipboardSuggestion(for: record)
        }
    }
}

// MARK: - KeyboardMonitorDelegate

extension AppDelegate: KeyboardMonitorDelegate {
    func keyboardMonitor(_ monitor: KeyboardMonitor, didUpdateBuffer buffer: String) {
        guard buffer == monitor.currentQuery else { return }

        let matches = engine.match(query: buffer)

        if let cursorPosition = AccessibilityHelper.getCursorScreenPosition() {
            lastKnownCursorPosition = cursorPosition
        }
        completionPanel.show(snippets: matches, near: lastKnownCursorPosition)
    }

    func keyboardMonitor(_ monitor: KeyboardMonitor, didCompleteTrigger trigger: String, deletionCount: Int) {
        print("[SnipKey] didCompleteTrigger: '\(trigger)'")
        hideCompletionPanel()

        guard let snippet = engine.findExact(trigger: trigger) else {
            print("[SnipKey]   No exact match found for '\(trigger)'")
            return
        }

        print("[SnipKey]   Match found! replacement='\(snippet.replacement)', deleteCount=\(deletionCount)")
        store.recordAcceptance(for: snippet.id)
        textReplacer.replace(deleteCount: deletionCount, replacement: snippet.replacement)
        monitor.resetBuffer()
    }

    func keyboardMonitorDidCancel(_ monitor: KeyboardMonitor) {
        print("[SnipKey] didCancel")
        finishCompletionInteractionCleanup()
    }

    func keyboardMonitor(_ monitor: KeyboardMonitor, didRequestSelection direction: KeyboardMonitor.SelectionDirection) {
        switch direction {
        case .up: completionPanel.moveSelectionUp()
        case .down: completionPanel.moveSelectionDown()
        }
    }

    func keyboardMonitorDidConfirmSelection(_ monitor: KeyboardMonitor) {
        guard let snippet = completionPanel.selectedSnippet else { return }
        confirmCompletionSelection(snippet)
    }
}

// MARK: - MenuBarControllerDelegate

extension AppDelegate: MenuBarControllerDelegate {
    func menuBarDidToggleEnabled(_ enabled: Bool) {
        if enabled {
            startKeyboardMonitorWithAccessibilityCheck()
            clipboardMonitor.start()
        } else {
            accessibilityCheckTimer?.invalidate()
            accessibilityCheckTimer = nil
            keyboardMonitor.stop()
            clipboardMonitor.stop()
            finishCompletionInteractionCleanup()
        }
    }

    func menuBarDidRequestPermissions() {
        AccessibilityHelper.requestAccessibilityIfNeeded(force: true)
        startKeyboardMonitorWithAccessibilityCheck()
    }

    func menuBarDidRequestSettings() {
        settingsWindow.show()
    }

    func menuBarDidRequestClipboardHistory() {
        settingsWindow.show(showingClipboardHistory: true)
    }

    func menuBarDidRequestQuit() {
        NSApp.terminate(nil)
    }
}

private extension AppDelegate {
    func presentClipboardSuggestion(for record: ClipboardRecord) {
        let alert = NSAlert()
        alert.messageText = "这段内容已经复制 \(record.copyCount) 次，要新建成 Key 吗？"
        alert.informativeText = "重复复制的内容很适合做成 Key，后续可以直接展开使用。\n\n\(clipboardPreview(for: record.content))"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "新建Key")
        alert.addButton(withTitle: "稍后")

        NSApp.activate(ignoringOtherApps: true)
        let response = alert.runModal()
        isPresentingClipboardSuggestion = false

        guard response == .alertFirstButtonReturn else { return }
        createSnippetFromClipboard(record)
    }

    func createSnippetFromClipboard(_ record: ClipboardRecord) {
        if let existingSnippet = store.snippets.first(where: { $0.replacement == record.content }) {
            clipboardHistoryStore.markCreatedSnippet(for: record.id, snippetID: existingSnippet.id)
            settingsWindow.show(selecting: existingSnippet.id)
            return
        }

        let snippet = ClipboardSnippetFactory.makeSnippet(from: record.content, existingSnippets: store.snippets)
        store.addSnippet(snippet)
        clipboardHistoryStore.markCreatedSnippet(for: record.id, snippetID: snippet.id)
        settingsWindow.show(selecting: snippet.id)
    }

    func clipboardPreview(for content: String) -> String {
        let flattened = content
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let preview = String(flattened.prefix(120))
        return flattened.count > preview.count ? preview + "…" : preview
    }

    func confirmCompletionSelection(_ snippet: Snippet) {
        hideCompletionPanel()
        store.recordAcceptance(for: snippet.id)
        textReplacer.replace(deleteCount: keyboardMonitor.currentBufferLength, replacement: snippet.replacement)
        keyboardMonitor.resetBuffer()
    }

    func startOutsidePanelClickMonitoring() {
        let eventMask: NSEvent.EventTypeMask = [.leftMouseDown, .rightMouseDown, .otherMouseDown]

        if globalMouseMonitor == nil {
            globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: eventMask) { [weak self] _ in
                self?.handleMonitoredMouseDown(at: NSEvent.mouseLocation)
            }
        }

        if localMouseMonitor == nil {
            localMouseMonitor = NSEvent.addLocalMonitorForEvents(matching: eventMask) { [weak self] event in
                self?.handleMonitoredMouseDown(at: self?.screenLocation(for: event) ?? NSEvent.mouseLocation)
                return event
            }
        }
    }

    func stopOutsidePanelClickMonitoring() {
        if let globalMouseMonitor {
            NSEvent.removeMonitor(globalMouseMonitor)
            self.globalMouseMonitor = nil
        }

        if let localMouseMonitor {
            NSEvent.removeMonitor(localMouseMonitor)
            self.localMouseMonitor = nil
        }
    }

    func handleMonitoredMouseDown(at screenPoint: NSPoint) {
        guard completionPanel.isVisible else { return }

        if completionPanel.containsScreenPoint(screenPoint) {
            return
        }

        print("[SnipKey] Completion cancelled after an outside click.")
        keyboardMonitor.resetBuffer()
        finishCompletionInteractionCleanup()
    }

    func screenLocation(for event: NSEvent) -> NSPoint {
        guard let window = event.window else { return NSEvent.mouseLocation }
        return window.convertPoint(toScreen: event.locationInWindow)
    }

    func hideCompletionPanel() {
        completionPanel.hide()
        lastKnownCursorPosition = nil
    }

    func finishCompletionInteractionCleanup() {
        hideCompletionPanel()
    }
}
