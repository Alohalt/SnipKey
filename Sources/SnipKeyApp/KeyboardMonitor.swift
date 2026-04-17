import Cocoa
import CoreGraphics
import SnipKeyCore

protocol KeyboardMonitorDelegate: AnyObject {
    func keyboardMonitor(_ monitor: KeyboardMonitor, didUpdateBuffer buffer: String)
    func keyboardMonitor(_ monitor: KeyboardMonitor, didCompleteTrigger trigger: String, deletionCount: Int)
    func keyboardMonitorDidCancel(_ monitor: KeyboardMonitor)
    func keyboardMonitor(_ monitor: KeyboardMonitor, didRequestSelection direction: KeyboardMonitor.SelectionDirection)
    func keyboardMonitorDidConfirmSelection(_ monitor: KeyboardMonitor)
}

class KeyboardMonitor {
    enum SelectionDirection { case up, down }

    weak var delegate: KeyboardMonitorDelegate?

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private(set) var buffer: String = ""
    private var isCapturing: Bool = false
    private let triggerPrefix: Character = "#"
    private let currentProcessID = ProcessInfo.processInfo.processIdentifier

    var isRunning: Bool { eventTap != nil }

    var currentBufferLength: Int { buffer.count }
    var currentQuery: String { isCapturing ? String(buffer.dropFirst()) : "" }

    func start() {
        guard eventTap == nil else { return }

        let eventMask: CGEventMask = (1 << CGEventType.keyDown.rawValue)

        let userInfo = Unmanaged.passUnretained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: { (proxy, type, event, userInfo) -> Unmanaged<CGEvent>? in
                guard let userInfo else { return Unmanaged.passUnretained(event) }
                let monitor = Unmanaged<KeyboardMonitor>.fromOpaque(userInfo).takeUnretainedValue()
                return monitor.handleEvent(proxy: proxy, type: type, event: event)
            },
            userInfo: userInfo
        ) else {
            print("[SnipKey] CGEvent.tapCreate returned nil")
            return
        }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        print("[SnipKey] Event tap created and enabled successfully!")
    }

    func stop() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            if let source = runLoopSource {
                CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
            }
        }
        eventTap = nil
        runLoopSource = nil
        resetBuffer()
    }

    func resetBuffer() {
        buffer = ""
        isCapturing = false
    }

    private func handleEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return Unmanaged.passUnretained(event)
        }

        guard type == .keyDown else { return Unmanaged.passUnretained(event) }

        if isCurrentAppFrontmost {
            if isCapturing {
                cancelCapture(notifyDelegate: true)
            }
            return Unmanaged.passUnretained(event)
        }

        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let flags = event.flags

        if hasShortcutModifiers(flags) {
            if isCapturing {
                cancelCapture(notifyDelegate: true)
            }
            return Unmanaged.passUnretained(event)
        }

        // Get the character from the event
        var length = 0
        event.keyboardGetUnicodeString(maxStringLength: 0, actualStringLength: &length, unicodeString: nil)
        var chars = [UniChar](repeating: 0, count: 4)
        event.keyboardGetUnicodeString(maxStringLength: 4, actualStringLength: &length, unicodeString: &chars)
        let character = length > 0 ? String(utf16CodeUnits: chars, count: length) : ""

        // Handle special keys during capture
        if isCapturing {
            // Escape - cancel
            if keyCode == 53 {
                resetBuffer()
                DispatchQueue.main.async { self.delegate?.keyboardMonitorDidCancel(self) }
                return Unmanaged.passUnretained(event)
            }

            // Tab or Enter - confirm selection
            if keyCode == 48 || keyCode == 36 {
                DispatchQueue.main.async { self.delegate?.keyboardMonitorDidConfirmSelection(self) }
                return nil // Consume the event
            }

            // Up arrow
            if keyCode == 126 {
                DispatchQueue.main.async { self.delegate?.keyboardMonitor(self, didRequestSelection: .up) }
                return nil
            }

            // Down arrow
            if keyCode == 125 {
                DispatchQueue.main.async { self.delegate?.keyboardMonitor(self, didRequestSelection: .down) }
                return nil
            }

            // Backspace
            if keyCode == 51 {
                if buffer.count > 1 {
                    buffer.removeLast()
                    DispatchQueue.main.async { self.delegate?.keyboardMonitor(self, didUpdateBuffer: String(self.buffer.dropFirst())) }
                } else {
                    cancelCapture(notifyDelegate: true)
                }
                return Unmanaged.passUnretained(event)
            }

            // Space or punctuation ends capture and finalizes exact matches.
            if keyCode == 49 || isTriggerTerminator(character) {
                let completedTrigger = String(buffer.dropFirst())
                let deletionCount = buffer.count + 1
                resetBuffer()

                if completedTrigger.isEmpty {
                    DispatchQueue.main.async { self.delegate?.keyboardMonitorDidCancel(self) }
                } else {
                    DispatchQueue.main.async {
                        self.delegate?.keyboardMonitor(self, didCompleteTrigger: completedTrigger, deletionCount: deletionCount)
                    }
                }
                return Unmanaged.passUnretained(event)
            }

            // Regular character - append to buffer
            if !character.isEmpty {
                buffer.append(character)
                let query = String(buffer.dropFirst()) // Remove # prefix
                DispatchQueue.main.async { self.delegate?.keyboardMonitor(self, didUpdateBuffer: query) }
            }
            return Unmanaged.passUnretained(event)
        }

        // Not capturing - check for trigger prefix
        if character == String(triggerPrefix) {
            isCapturing = true
            buffer = String(triggerPrefix)
            DispatchQueue.main.async { self.delegate?.keyboardMonitor(self, didUpdateBuffer: "") }
        }

        return Unmanaged.passUnretained(event)
    }

    deinit {
        stop()
    }

    private var isCurrentAppFrontmost: Bool {
        NSWorkspace.shared.frontmostApplication?.processIdentifier == currentProcessID
    }

    private func hasShortcutModifiers(_ flags: CGEventFlags) -> Bool {
        // Note: do NOT include .maskSecondaryFn — arrow keys carry that flag
        let shortcutFlags: CGEventFlags = [.maskCommand, .maskControl, .maskAlternate]
        return !flags.intersection(shortcutFlags).isEmpty
    }

    private func isTriggerTerminator(_ character: String) -> Bool {
        guard let firstCharacter = character.first else { return false }
        return !firstCharacter.isLetter && !firstCharacter.isNumber && firstCharacter != "_" && firstCharacter != "-"
    }

    private func cancelCapture(notifyDelegate: Bool) {
        resetBuffer()

        guard notifyDelegate else { return }
        DispatchQueue.main.async { self.delegate?.keyboardMonitorDidCancel(self) }
    }
}
