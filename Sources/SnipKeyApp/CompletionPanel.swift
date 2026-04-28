import Cocoa
import SwiftUI
import SnipKeyCore

final class CompletionPanel {
    private let panelCornerRadius: CGFloat = 18
    private let screenPadding: CGFloat = 8

    private var panel: CompletionFloatingPanel?
    private var hostingView: CompletionHostingView?
    private var shouldAutoScrollSelection = false
    private let languageStore: AppLanguageStore

    private(set) var matchedSnippets: [Snippet] = []
    private(set) var selectedIndex: Int = 0
    var onConfirmSelection: ((Snippet) -> Void)?

    init(languageStore: AppLanguageStore) {
        self.languageStore = languageStore
    }

    var selectedSnippet: Snippet? {
        guard !matchedSnippets.isEmpty, selectedIndex < matchedSnippets.count else { return nil }
        return matchedSnippets[selectedIndex]
    }

    func show(snippets: [Snippet], near position: NSPoint?) {
        matchedSnippets = snippets
        selectedIndex = 0
        shouldAutoScrollSelection = false

        if snippets.isEmpty {
            hide()
            return
        }

        let view = makeView()

        if panel == nil {
            let p = CompletionFloatingPanel(
                contentRect: .zero,
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: true
            )
            p.level = .floating
            p.isOpaque = false
            p.backgroundColor = .clear
            p.hasShadow = false
            p.hidesOnDeactivate = false
            p.becomesKeyOnlyIfNeeded = true
            p.acceptsMouseMovedEvents = true
            p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            panel = p
        }

        if let hostingView {
            hostingView.rootView = view
            hostingView.invalidateIntrinsicContentSize()
            hostingView.layoutSubtreeIfNeeded()
            panel?.setContentSize(hostingView.fittingSize)
        } else {
            let hosting = CompletionHostingView(rootView: view)
            hosting.frame.size = hosting.fittingSize
            panel?.contentView = hosting
            panel?.setContentSize(hosting.fittingSize)
            hostingView = hosting
        }

        let contentSize = hostingView?.fittingSize ?? .zero

        if let origin = panelOrigin(near: position, contentSize: contentSize) {
            panel?.setFrameOrigin(origin)
        }

        if panel?.isVisible != true {
            panel?.orderFront(nil)
        }
    }

    func updateView() {
        let view = makeView()
        if let hostingView {
            hostingView.rootView = view
            hostingView.invalidateIntrinsicContentSize()
            hostingView.layoutSubtreeIfNeeded()
        } else {
            let hosting = CompletionHostingView(rootView: view)
            hosting.frame.size = hosting.fittingSize
            panel?.contentView = hosting
            panel?.setContentSize(hosting.fittingSize)
            hostingView = hosting
        }
    }

    func updateLanguage() {
        guard isVisible else { return }
        updateView()
    }

    func hide() {
        panel?.orderOut(nil)
        matchedSnippets = []
        selectedIndex = 0
    }

    func moveSelectionUp() {
        guard !matchedSnippets.isEmpty else { return }
        selectedIndex = (selectedIndex - 1 + matchedSnippets.count) % matchedSnippets.count
        shouldAutoScrollSelection = true
        updateView()
    }

    func moveSelectionDown() {
        guard !matchedSnippets.isEmpty else { return }
        selectedIndex = (selectedIndex + 1) % matchedSnippets.count
        shouldAutoScrollSelection = true
        updateView()
    }

    var isVisible: Bool {
        panel?.isVisible ?? false
    }

    func containsScreenPoint(_ point: NSPoint) -> Bool {
        panel?.frame.contains(point) ?? false
    }

    private func panelOrigin(near position: NSPoint?, contentSize: NSSize) -> NSPoint? {
        if let position {
            guard let screen = screenContaining(position) ?? NSScreen.main else { return nil }
            let visibleFrame = screen.visibleFrame
            let minX = visibleFrame.minX + screenPadding
            let maxX = visibleFrame.maxX - contentSize.width - screenPadding
            let minY = visibleFrame.minY + screenPadding
            let maxY = visibleFrame.maxY - contentSize.height - screenPadding

            let preferredBelowY = position.y - contentSize.height - 4
            let preferredAboveY = position.y + 4
            let originY: CGFloat

            if preferredBelowY >= minY {
                originY = preferredBelowY
            } else if preferredAboveY <= maxY {
                originY = preferredAboveY
            } else {
                originY = clamped(preferredBelowY, min: minY, max: maxY)
            }

            return NSPoint(
                x: clamped(position.x, min: minX, max: maxX),
                y: originY
            )
        }

        guard let screen = NSScreen.main else { return nil }
        let visibleFrame = screen.visibleFrame
        let minX = visibleFrame.minX + screenPadding
        let maxX = visibleFrame.maxX - contentSize.width - screenPadding
        let minY = visibleFrame.minY + screenPadding
        let maxY = visibleFrame.maxY - contentSize.height - screenPadding

        return NSPoint(
            x: clamped(visibleFrame.midX - contentSize.width / 2, min: minX, max: maxX),
            y: clamped(visibleFrame.midY - contentSize.height / 2, min: minY, max: maxY)
        )
    }

    private func screenContaining(_ point: NSPoint) -> NSScreen? {
        NSScreen.screens.first { $0.frame.insetBy(dx: -1, dy: -1).contains(point) }
    }

    private func clamped(_ value: CGFloat, min minimum: CGFloat, max maximum: CGFloat) -> CGFloat {
        guard maximum >= minimum else { return minimum }
        return Swift.min(Swift.max(value, minimum), maximum)
    }

    private func makeView() -> CompletionView {
        CompletionView(
            snippets: matchedSnippets,
            selectedIndex: selectedIndex,
            shouldAutoScrollSelection: shouldAutoScrollSelection,
            languageStore: languageStore,
            onHoverSelection: { [weak self] index in
                self?.selectSnippet(at: index)
            },
            onConfirmSelection: { [weak self] index in
                self?.confirmSnippet(at: index)
            }
        )
    }

    private func selectSnippet(at index: Int) {
        guard matchedSnippets.indices.contains(index), selectedIndex != index else { return }
        selectedIndex = index
        shouldAutoScrollSelection = false
        updateView()
    }

    private func confirmSnippet(at index: Int) {
        guard matchedSnippets.indices.contains(index) else { return }
        selectedIndex = index
        onConfirmSelection?(matchedSnippets[index])
    }
}

private final class CompletionFloatingPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

private final class CompletionHostingView: NSHostingView<CompletionView> {
    required init(rootView: CompletionView) {
        super.init(rootView: rootView)
        configureAppearance()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    private func configureAppearance() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        layer?.cornerRadius = 18
        layer?.cornerCurve = .continuous
        layer?.masksToBounds = true
    }
}
