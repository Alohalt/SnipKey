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
    private var pendingCompletionResolution: DispatchWorkItem?
    private let triggerPrefix: Character = "#"
    private let currentProcessID = ProcessInfo.processInfo.processIdentifier
    private let textContextProvider: (Int) -> String?

    var isRunning: Bool { eventTap != nil }

    var currentBufferLength: Int { buffer.count }
    var currentQuery: String { isCapturing ? String(buffer.dropFirst()) : "" }

    init(textContextProvider: @escaping (Int) -> String? = { maxLength in
        AccessibilityHelper.textBeforeCursor(maxLength: maxLength)
    }) {
        self.textContextProvider = textContextProvider
    }

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
        pendingCompletionResolution?.cancel()
        pendingCompletionResolution = nil
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

            // Tab or Enter confirm the highlighted completion.
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

            // Let terminators through first so committed text can land in the target app,
            // then prefer the actual text before the cursor. Fall back to the raw buffer.
            if keyCode == 49 || isTriggerTerminator(character) {
                scheduleCompletionResolution(
                    fallbackTrigger: String(buffer.dropFirst()),
                    fallbackDeletionCount: buffer.count + 1
                )
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
        return SnippetTriggerRules.isAllowedCharacter(firstCharacter) == false
    }

    private func scheduleCompletionResolution(
        fallbackTrigger: String,
        fallbackDeletionCount: Int,
        remainingRetries: Int = 4,
        delay: TimeInterval = 0.04
    ) {
        guard isCapturing else { return }

        pendingCompletionResolution?.cancel()

        let contextLength = max(buffer.count + 8, 64)
        let workItem = DispatchWorkItem { [weak self] in
            self?.resolveCompletedTrigger(
                withContextLength: contextLength,
                fallbackTrigger: fallbackTrigger,
                fallbackDeletionCount: fallbackDeletionCount,
                remainingRetries: remainingRetries,
                delay: delay
            )
        }
        pendingCompletionResolution = workItem

        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
    }

    private func resolveCompletedTrigger(
        withContextLength contextLength: Int,
        fallbackTrigger: String,
        fallbackDeletionCount: Int,
        remainingRetries: Int,
        delay: TimeInterval
    ) {
        pendingCompletionResolution = nil

        guard isCapturing, let textBeforeCursor = textContextProvider(contextLength) else {
            finishCompletionResolution(
                trigger: fallbackTrigger,
                deletionCount: fallbackDeletionCount,
                remainingRetries: remainingRetries,
                delay: delay
            )
            return
        }

        if let completedTrigger = TriggerContextAnalyzer.completedTrigger(
            in: textBeforeCursor,
            triggerPrefix: triggerPrefix
        ) {
            resetBuffer()
            DispatchQueue.main.async {
                self.delegate?.keyboardMonitor(
                    self,
                    didCompleteTrigger: completedTrigger.trigger,
                    deletionCount: completedTrigger.deletionCount
                )
            }
            return
        }

        finishCompletionResolution(
            trigger: fallbackTrigger,
            deletionCount: fallbackDeletionCount,
            remainingRetries: remainingRetries,
            delay: delay
        )
    }

    private func finishCompletionResolution(
        trigger: String,
        deletionCount: Int,
        remainingRetries: Int,
        delay: TimeInterval
    ) {
        guard isCapturing else { return }

        if remainingRetries > 0 {
            scheduleCompletionResolution(
                fallbackTrigger: trigger,
                fallbackDeletionCount: deletionCount,
                remainingRetries: remainingRetries - 1,
                delay: delay
            )
            return
        }

        resetBuffer()

        guard trigger.isEmpty == false else {
            DispatchQueue.main.async { self.delegate?.keyboardMonitorDidCancel(self) }
            return
        }

        DispatchQueue.main.async {
            self.delegate?.keyboardMonitor(self, didCompleteTrigger: trigger, deletionCount: deletionCount)
        }
    }

    private func cancelCapture(notifyDelegate: Bool) {
        resetBuffer()

        guard notifyDelegate else { return }
        DispatchQueue.main.async { self.delegate?.keyboardMonitorDidCancel(self) }
    }
}
