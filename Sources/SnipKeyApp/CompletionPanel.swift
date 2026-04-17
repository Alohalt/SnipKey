import Cocoa
import SwiftUI
import SnipKeyCore

class CompletionPanel {
    private let screenPadding: CGFloat = 8

    private var panel: NSPanel?
    private var hostingView: NSHostingView<CompletionView>?

    private(set) var matchedSnippets: [Snippet] = []
    private(set) var selectedIndex: Int = 0

    var selectedSnippet: Snippet? {
        guard !matchedSnippets.isEmpty, selectedIndex < matchedSnippets.count else { return nil }
        return matchedSnippets[selectedIndex]
    }

    func show(snippets: [Snippet], near position: NSPoint?) {
        matchedSnippets = snippets
        selectedIndex = 0

        if snippets.isEmpty {
            hide()
            return
        }

        let view = CompletionView(snippets: snippets, selectedIndex: selectedIndex)

        if panel == nil {
            let p = NSPanel(
                contentRect: .zero,
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: true
            )
            p.level = .floating
            p.isOpaque = false
            p.backgroundColor = .clear
            p.hasShadow = false
            p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            panel = p
        }

        if let hostingView {
            hostingView.rootView = view
            hostingView.invalidateIntrinsicContentSize()
            hostingView.layoutSubtreeIfNeeded()
            panel?.setContentSize(hostingView.fittingSize)
        } else {
            let hosting = NSHostingView(rootView: view)
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
        let view = CompletionView(snippets: matchedSnippets, selectedIndex: selectedIndex)
        if let hostingView {
            hostingView.rootView = view
            hostingView.invalidateIntrinsicContentSize()
            hostingView.layoutSubtreeIfNeeded()
            panel?.setContentSize(hostingView.fittingSize)
        } else {
            let hosting = NSHostingView(rootView: view)
            hosting.frame.size = hosting.fittingSize
            panel?.contentView = hosting
            panel?.setContentSize(hosting.fittingSize)
            hostingView = hosting
        }
    }

    func hide() {
        panel?.orderOut(nil)
        matchedSnippets = []
        selectedIndex = 0
    }

    func moveSelectionUp() {
        guard !matchedSnippets.isEmpty else { return }
        selectedIndex = (selectedIndex - 1 + matchedSnippets.count) % matchedSnippets.count
        updateView()
    }

    func moveSelectionDown() {
        guard !matchedSnippets.isEmpty else { return }
        selectedIndex = (selectedIndex + 1) % matchedSnippets.count
        updateView()
    }

    var isVisible: Bool {
        panel?.isVisible ?? false
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
}
