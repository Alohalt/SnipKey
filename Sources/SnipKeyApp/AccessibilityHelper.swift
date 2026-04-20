import Cocoa
import ApplicationServices

class AccessibilityHelper {
    private static let promptIdentityKey = "SnipKey.keyboardAccessPrompt.identity"
    private static let promptDateKey = "SnipKey.keyboardAccessPrompt.date"
    private static let promptCooldown: TimeInterval = 12 * 60 * 60
    private static let cursorLogThrottle: TimeInterval = 5

    private enum CursorAnchorSource: String {
        case selectionBounds = "selectionBounds"
        case nextCharacterBounds = "nextCharacterBounds"
        case previousCharacterBounds = "previousCharacterBounds"
        case focusedElementFrame = "focusedElementFrame"
        case mouseLocation = "mouseLocation"
    }

    private struct CursorAnchor {
        let point: NSPoint
        let source: CursorAnchorSource
    }

    private static var lastLoggedCursorAnchorSource: CursorAnchorSource?
    private static var lastCursorLogDate = Date.distantPast

    /// Check if accessibility permission is granted
    static var isAccessibilityEnabled: Bool {
        AXIsProcessTrustedWithOptions(
            [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): false] as CFDictionary
        )
    }

    /// Prompt user to grant keyboard-related permissions when we have not done so
    /// recently for the current executable identity.
    @discardableResult
    static func requestAccessibilityIfNeeded(force: Bool = false) -> Bool {
        if !force && !shouldAutoPromptForCurrentExecutable() {
            return isAccessibilityEnabled
        }

        recordPromptAttempt()
        let trusted = AXIsProcessTrustedWithOptions(
            [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        )
        if !trusted {
            showAccessibilityAlert()
        }
        return trusted
    }

    static func openAccessibilitySettings() {
        NSWorkspace.shared.open(
            URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        )
    }

    /// Show a user-friendly alert explaining how to grant permission
    private static func showAccessibilityAlert() {
        let alert = NSAlert()
        alert.messageText = "需要键盘访问权限"
        alert.informativeText = """
            SnipKey 需要键盘相关权限，才能监听触发词并展开Key。

            1. 打开“系统设置” → “隐私与安全性” → “辅助功能”
            2. 勾选“SnipKey”（或你当前启动它的应用，例如 Xcode / Terminal）
            3. 如果“输入监控”里也出现 SnipKey，请一并启用
            4. 尽量从同一个应用路径启动 SnipKey，便于 macOS 稳定保留授权
            """
        alert.alertStyle = .warning
        alert.addButton(withTitle: "打开系统设置")
        alert.addButton(withTitle: "稍后")

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            openAccessibilitySettings()
        }
    }

    /// Get the position of the focused text cursor using Accessibility API
    static func getCursorScreenPosition() -> NSPoint? {
        let anchor = resolvedCursorAnchor()
        debugLogCursorAnchor(anchor)
        return anchor?.point
    }

    static func textBeforeCursor(maxLength: Int = 128) -> String? {
        guard let focusedElement = focusedUIElement(),
              let selectedRange = selectedTextRange(of: focusedElement) else {
            return nil
        }

        let cursorLocation = max(0, selectedRange.location)
        let startLocation = max(0, cursorLocation - maxLength)
        let targetRange = CFRange(location: startLocation, length: cursorLocation - startLocation)

        if let rangeText = string(for: targetRange, in: focusedElement) {
            return rangeText
        }

        guard let value = stringAttribute(kAXValueAttribute as CFString, on: focusedElement) else {
            return nil
        }

        let text = value as NSString
        let boundedCursorLocation = max(0, min(selectedRange.location, text.length))
        let fallbackStartLocation = max(0, boundedCursorLocation - maxLength)
        let range = NSRange(location: fallbackStartLocation, length: boundedCursorLocation - fallbackStartLocation)
        return text.substring(with: range)
    }

    private static func resolvedCursorAnchor() -> CursorAnchor? {
        guard let focusedElement = focusedUIElement() else {
            return CursorAnchor(point: NSEvent.mouseLocation, source: .mouseLocation)
        }

        if let selectedRange = selectedTextRange(of: focusedElement) {
            if let rect = bounds(for: selectedRange, in: focusedElement) {
                return CursorAnchor(point: anchorPoint(for: rect), source: .selectionBounds)
            }

            if let nextRange = nextCharacterRange(after: selectedRange, in: focusedElement),
               let rect = bounds(for: nextRange, in: focusedElement) {
                return CursorAnchor(point: anchorPoint(for: rect), source: .nextCharacterBounds)
            }

            if let previousRange = previousCharacterRange(before: selectedRange),
               let rect = bounds(for: previousRange, in: focusedElement) {
                return CursorAnchor(point: anchorPoint(for: rect, usesTrailingEdge: true), source: .previousCharacterBounds)
            }
        }

        if let frame = frame(of: focusedElement) {
            return CursorAnchor(point: approximateAnchorPoint(for: frame), source: .focusedElementFrame)
        }

        return CursorAnchor(point: NSEvent.mouseLocation, source: .mouseLocation)
    }

    private static func focusedUIElement() -> AXUIElement? {
        guard let focusedApp = NSWorkspace.shared.frontmostApplication else { return nil }
        let appElement = AXUIElementCreateApplication(focusedApp.processIdentifier)

        var focusedElement: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appElement, kAXFocusedUIElementAttribute as CFString, &focusedElement) == .success,
              let focusedElement else {
            return nil
        }

        return (focusedElement as! AXUIElement)
    }

    private static func selectedTextRange(of element: AXUIElement) -> CFRange? {
        var selectedRangeValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, &selectedRangeValue) == .success,
              let selectedRangeValue else {
            return nil
        }

        let axValue = selectedRangeValue as! AXValue

        var selectedRange = CFRange()
        guard AXValueGetValue(axValue, .cfRange, &selectedRange) else { return nil }
        return selectedRange
    }

    private static func nextCharacterRange(after selectedRange: CFRange, in element: AXUIElement) -> CFRange? {
        guard selectedRange.length == 0,
              let characterCount = numberOfCharacters(in: element),
              selectedRange.location < characterCount else {
            return nil
        }

        return CFRange(location: selectedRange.location, length: 1)
    }

    private static func previousCharacterRange(before selectedRange: CFRange) -> CFRange? {
        guard selectedRange.length == 0, selectedRange.location > 0 else { return nil }
        return CFRange(location: selectedRange.location - 1, length: 1)
    }

    private static func numberOfCharacters(in element: AXUIElement) -> Int? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXNumberOfCharactersAttribute as CFString, &value) == .success,
              let number = value as? NSNumber else {
            return nil
        }

        return number.intValue
    }

    private static func bounds(for range: CFRange, in element: AXUIElement) -> CGRect? {
        var mutableRange = range
        guard let rangeValue = AXValueCreate(.cfRange, &mutableRange) else { return nil }

        var boundsValue: CFTypeRef?
        guard AXUIElementCopyParameterizedAttributeValue(
            element,
            kAXBoundsForRangeParameterizedAttribute as CFString,
            rangeValue,
            &boundsValue
        ) == .success,
        let boundsValue else {
            return nil
        }

        let axValue = boundsValue as! AXValue

        var rect = CGRect.zero
        guard AXValueGetValue(axValue, .cgRect, &rect), rect.height > 0 else { return nil }
        return rect
    }

    private static func frame(of element: AXUIElement) -> CGRect? {
        guard let position = pointAttribute(kAXPositionAttribute as CFString, on: element),
              let size = sizeAttribute(kAXSizeAttribute as CFString, on: element) else {
            return nil
        }

        return CGRect(origin: position, size: size)
    }

    private static func pointAttribute(_ attribute: CFString, on element: AXUIElement) -> CGPoint? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute, &value) == .success,
              let value else {
            return nil
        }

        let axValue = value as! AXValue

        var point = CGPoint.zero
        guard AXValueGetValue(axValue, .cgPoint, &point) else { return nil }
        return point
    }

    private static func sizeAttribute(_ attribute: CFString, on element: AXUIElement) -> CGSize? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute, &value) == .success,
              let value else {
            return nil
        }

        let axValue = value as! AXValue

        var size = CGSize.zero
        guard AXValueGetValue(axValue, .cgSize, &size) else { return nil }
        return size
    }

    private static func stringAttribute(_ attribute: CFString, on element: AXUIElement) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute, &value) == .success,
              let value else {
            return nil
        }

        if let string = value as? String {
            return string
        }

        if let attributedString = value as? NSAttributedString {
            return attributedString.string
        }

        return nil
    }

    private static func string(for range: CFRange, in element: AXUIElement) -> String? {
        var mutableRange = range
        guard let rangeValue = AXValueCreate(.cfRange, &mutableRange) else { return nil }

        var value: CFTypeRef?
        guard AXUIElementCopyParameterizedAttributeValue(
            element,
            kAXStringForRangeParameterizedAttribute as CFString,
            rangeValue,
            &value
        ) == .success,
        let value else {
            return nil
        }

        if let string = value as? String {
            return string
        }

        if let attributedString = value as? NSAttributedString {
            return attributedString.string
        }

        return nil
    }

    private static func anchorPoint(for rect: CGRect, usesTrailingEdge: Bool = false) -> NSPoint {
        NSPoint(x: usesTrailingEdge ? rect.maxX : rect.minX, y: rect.maxY)
    }

    private static func approximateAnchorPoint(for frame: CGRect) -> NSPoint {
        let horizontalInset = min(max(frame.width * 0.05, 14), 28)
        let verticalInset = min(max(frame.height * 0.2, 12), 24)
        return NSPoint(x: frame.minX + horizontalInset, y: frame.maxY - verticalInset)
    }

    private static func debugLogCursorAnchor(_ anchor: CursorAnchor?) {
        #if DEBUG
        let source = anchor?.source
        let now = Date()
        guard source != lastLoggedCursorAnchorSource || now.timeIntervalSince(lastCursorLogDate) >= cursorLogThrottle else {
            return
        }

        lastLoggedCursorAnchorSource = source
        lastCursorLogDate = now

        if let anchor {
            print("[SnipKey][Cursor] Using \(anchor.source.rawValue) at (\(Int(anchor.point.x)), \(Int(anchor.point.y)))")
        } else {
            print("[SnipKey][Cursor] Unable to resolve cursor anchor")
        }
        #endif
    }

    private static func shouldAutoPromptForCurrentExecutable(now: Date = Date()) -> Bool {
        let defaults = UserDefaults.standard
        let currentIdentity = executableIdentity

        guard
            defaults.string(forKey: promptIdentityKey) == currentIdentity,
            let lastPrompt = defaults.object(forKey: promptDateKey) as? Date
        else {
            return true
        }

        return now.timeIntervalSince(lastPrompt) >= promptCooldown
    }

    private static func recordPromptAttempt(now: Date = Date()) {
        let defaults = UserDefaults.standard
        defaults.set(executableIdentity, forKey: promptIdentityKey)
        defaults.set(now, forKey: promptDateKey)
    }

    private static var executableIdentity: String {
        let bundlePath = Bundle.main.bundlePath
        let executablePath = Bundle.main.executablePath ?? ProcessInfo.processInfo.arguments.first ?? "unknown"
        return "\(bundlePath)|\(executablePath)"
    }
}
