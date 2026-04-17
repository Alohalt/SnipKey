import Cocoa
import CoreGraphics
import SnipKeyCore

class TextReplacer {
    private let variableResolver: VariableResolver
    var onClipboardWrite: ((String?) -> Void)?

    init(variableResolver: VariableResolver = VariableResolver()) {
        self.variableResolver = variableResolver
    }

    /// Replace the trigger text with the snippet replacement.
    /// - Parameters:
    ///   - deleteCount: Number of typed characters to delete before inserting the replacement
    ///   - replacement: The replacement template string
    func replace(deleteCount: Int, replacement: String) {
        let resolved = variableResolver.resolve(replacement)

        // Step 1: Simulate backspace keys to delete the typed trigger text.
        simulateBackspaces(count: deleteCount)

        // Step 2: Small delay for backspaces to register
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            // Step 3: Paste the replacement text via clipboard
            self.pasteText(resolved.text)

            // Step 4: Handle cursor positioning if {cursor} was used
            if let offset = resolved.cursorOffset {
                let charsToMoveBack = resolved.text.count - offset
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    self.simulateLeftArrows(count: charsToMoveBack)
                }
            }
        }
    }

    private func simulateBackspaces(count: Int) {
        for _ in 0..<count {
            simulateKey(keyCode: 51) // backspace
        }
    }

    private func simulateLeftArrows(count: Int) {
        for _ in 0..<count {
            simulateKey(keyCode: 123) // left arrow
        }
    }

    private func simulateKey(keyCode: CGKeyCode) {
        let keyDown = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: false)
        keyDown?.post(tap: .cgAnnotatedSessionEventTap)
        keyUp?.post(tap: .cgAnnotatedSessionEventTap)
    }

    private func pasteText(_ text: String) {
        // Save current clipboard
        let pasteboard = NSPasteboard.general
        let previousContents = pasteboard.string(forType: .string)

        // Set new content
        onClipboardWrite?(text)
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        // Simulate Cmd+V
        let source = CGEventSource(stateID: .combinedSessionState)
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: true) // 'v'
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: false)
        keyDown?.flags = .maskCommand
        keyUp?.flags = .maskCommand
        keyDown?.post(tap: .cgAnnotatedSessionEventTap)
        keyUp?.post(tap: .cgAnnotatedSessionEventTap)

        // Restore previous clipboard after a delay
        if let previous = previousContents {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.onClipboardWrite?(previous)
                pasteboard.clearContents()
                pasteboard.setString(previous, forType: .string)
            }
        }
    }
}
