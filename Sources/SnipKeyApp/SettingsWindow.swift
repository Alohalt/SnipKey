import Cocoa
import SwiftUI
import SnipKeyCore

class SettingsWindow {
    private var window: NSWindow?
    private var hostingController: NSHostingController<SettingsView>?
    private let store: SnippetStore
    private let clipboardHistoryStore: ClipboardHistoryStore
    private let coordinator = SettingsCoordinator()

    init(store: SnippetStore, clipboardHistoryStore: ClipboardHistoryStore) {
        self.store = store
        self.clipboardHistoryStore = clipboardHistoryStore
    }

    func show(showOnboarding: Bool = false, selecting snippetId: UUID? = nil, showingClipboardHistory: Bool = false) {
        if showOnboarding, let hostingController {
            hostingController.rootView = makeSettingsView(initiallyShowsOnboarding: true)
        }

        if let window, window.isVisible {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            if let snippetId {
                coordinator.focusSnippet(snippetId)
            }
            if showingClipboardHistory {
                coordinator.showClipboardHistory()
            }
            return
        }

        let settingsView = makeSettingsView(initiallyShowsOnboarding: showOnboarding)
        let hostingController = NSHostingController(rootView: settingsView)
        self.hostingController = hostingController

        let w = NSWindow(contentViewController: hostingController)
        w.title = "SnipKey"
        w.setContentSize(NSSize(width: 980, height: 620))
        w.minSize = NSSize(width: 920, height: 580)
        w.styleMask = [.titled, .closable, .resizable, .miniaturizable, .fullSizeContentView]
        w.toolbarStyle = .unifiedCompact
        w.titleVisibility = .hidden
        w.titlebarAppearsTransparent = true
        w.titlebarSeparatorStyle = .none
        w.isMovableByWindowBackground = true
        w.isReleasedWhenClosed = false
        w.center()
        w.setFrameAutosaveName("SnipKeySettings")
        w.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        window = w

        if let snippetId {
            coordinator.focusSnippet(snippetId)
        }
        if showingClipboardHistory {
            coordinator.showClipboardHistory()
        }
    }

    func close() {
        window?.close()
    }

    private func makeSettingsView(initiallyShowsOnboarding: Bool) -> SettingsView {
        SettingsView(
            store: store,
            clipboardHistoryStore: clipboardHistoryStore,
            coordinator: coordinator,
            initiallyShowsOnboarding: initiallyShowsOnboarding
        )
    }
}
