# SnipKey for Mac - Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a macOS menu bar app that monitors global keyboard input and expands `#trigger` shortcuts into configured text snippets, with a floating autocomplete popup.

**Architecture:** Swift Package Manager project with two targets: `SnipKeyCore` (library, all testable logic) and `SnipKeyApp` (executable, UI and system integration). CGEvent Tap for keyboard monitoring, NSPanel for completion popup, SwiftUI for settings UI.

**Tech Stack:** Swift 5.9+, SwiftUI, AppKit, CoreGraphics (CGEvent), XCTest

---

## Project Structure

```
SnipKey/
├── Package.swift
├── Sources/
│   ├── SnipKeyCore/
│   │   ├── Models.swift              # Snippet, SnippetGroup
│   │   ├── SnippetStore.swift        # CRUD + persistence
│   │   ├── SnippetEngine.swift       # Matching logic
│   │   └── VariableResolver.swift    # {date}, {time}, {clipboard}
│   └── SnipKeyApp/
│       ├── SnipKeyApp.swift        # @main entry, App lifecycle
│       ├── AppDelegate.swift         # NSApplicationDelegate, setup
│       ├── MenuBarController.swift   # Status item + menu
│       ├── KeyboardMonitor.swift     # CGEvent Tap wrapper
│       ├── TextReplacer.swift        # Backspace + paste logic
│       ├── CompletionPanel.swift     # NSPanel setup
│       ├── CompletionView.swift      # SwiftUI completion list
│       ├── SettingsWindow.swift      # Settings window controller
│       ├── SettingsView.swift        # SwiftUI settings UI
│       └── AccessibilityHelper.swift # Permission checks
├── Tests/
│   └── SnipKeyCoreTests/
│       ├── ModelsTests.swift
│       ├── SnippetStoreTests.swift
│       ├── SnippetEngineTests.swift
│       └── VariableResolverTests.swift
├── Resources/
│   └── Info.plist
└── Makefile
```

---

### Task 1: Project Scaffolding

**Files:**
- Create: `Package.swift`
- Create: `Sources/SnipKeyCore/Models.swift`
- Create: `Sources/SnipKeyApp/SnipKeyApp.swift` (placeholder)
- Create: `Tests/SnipKeyCoreTests/ModelsTests.swift`
- Create: `Makefile`
- Create: `Resources/Info.plist`

**Step 1: Create Package.swift**

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SnipKey",
    platforms: [.macOS(.v13)],
    targets: [
        .target(
            name: "SnipKeyCore",
            path: "Sources/SnipKeyCore"
        ),
        .executableTarget(
            name: "SnipKeyApp",
            dependencies: ["SnipKeyCore"],
            path: "Sources/SnipKeyApp"
        ),
        .testTarget(
            name: "SnipKeyCoreTests",
            dependencies: ["SnipKeyCore"],
            path: "Tests/SnipKeyCoreTests"
        ),
    ]
)
```

**Step 2: Create Models.swift with Snippet and SnippetGroup**

```swift
import Foundation

public struct Snippet: Codable, Identifiable, Equatable {
    public let id: UUID
    public var trigger: String
    public var replacement: String
    public var groupId: UUID?

    public init(id: UUID = UUID(), trigger: String, replacement: String, groupId: UUID? = nil) {
        self.id = id
        self.trigger = trigger
        self.replacement = replacement
        self.groupId = groupId
    }
}

public struct SnippetGroup: Codable, Identifiable, Equatable {
    public let id: UUID
    public var name: String

    public init(id: UUID = UUID(), name: String) {
        self.id = id
        self.name = name
    }
}

public struct SnippetData: Codable, Equatable {
    public var snippets: [Snippet]
    public var groups: [SnippetGroup]

    public init(snippets: [Snippet] = [], groups: [SnippetGroup] = []) {
        self.snippets = snippets
        self.groups = groups
    }
}
```

**Step 3: Create placeholder app entry point**

```swift
// Sources/SnipKeyApp/SnipKeyApp.swift
import AppKit

// Minimal placeholder - will be replaced in Task 7
let app = NSApplication.shared
app.run()
```

**Step 4: Create ModelsTests.swift**

```swift
import XCTest
@testable import SnipKeyCore

final class ModelsTests: XCTestCase {
    func testSnippetCreation() {
        let snippet = Snippet(trigger: "account", replacement: "account1")
        XCTAssertEqual(snippet.trigger, "account")
        XCTAssertEqual(snippet.replacement, "account1")
        XCTAssertNil(snippet.groupId)
    }

    func testSnippetGroupCreation() {
        let group = SnippetGroup(name: "Work")
        XCTAssertEqual(group.name, "Work")
    }

    func testSnippetCodable() throws {
        let snippet = Snippet(trigger: "email", replacement: "test@example.com")
        let data = try JSONEncoder().encode(snippet)
        let decoded = try JSONDecoder().decode(Snippet.self, from: data)
        XCTAssertEqual(snippet, decoded)
    }

    func testSnippetDataCodable() throws {
        let group = SnippetGroup(name: "Personal")
        let snippet = Snippet(trigger: "addr", replacement: "123 Main St", groupId: group.id)
        let snippetData = SnippetData(snippets: [snippet], groups: [group])
        let data = try JSONEncoder().encode(snippetData)
        let decoded = try JSONDecoder().decode(SnippetData.self, from: data)
        XCTAssertEqual(snippetData, decoded)
    }
}
```

**Step 5: Create Info.plist**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>SnipKey</string>
    <key>CFBundleIdentifier</key>
    <string>com.snipkey.app</string>
    <key>CFBundleVersion</key>
    <string>1.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSAccessibilityUsageDescription</key>
    <string>SnipKey needs accessibility access to monitor keyboard input and expand text snippets.</string>
</dict>
</plist>
```

**Step 6: Create Makefile**

```makefile
.PHONY: build test run clean bundle

build:
	swift build

test:
	swift test

run:
	swift run SnipKeyApp

clean:
	swift package clean

bundle: build
	mkdir -p .build/SnipKey.app/Contents/MacOS
	mkdir -p .build/SnipKey.app/Contents/Resources
	cp .build/debug/SnipKeyApp .build/SnipKey.app/Contents/MacOS/SnipKey
	cp Resources/Info.plist .build/SnipKey.app/Contents/
	@echo "App bundle created at .build/SnipKey.app"
```

**Step 7: Run tests to verify setup**

Run: `cd "/Users/liutao130/workspace/SnipKey" && swift test`
Expected: All 4 tests PASS

**Step 8: Commit**

```bash
git init
git add -A
git commit -m "feat: project scaffolding with models and tests"
```

---

### Task 2: SnippetStore (Persistence Layer)

**Files:**
- Create: `Sources/SnipKeyCore/SnippetStore.swift`
- Create: `Tests/SnipKeyCoreTests/SnippetStoreTests.swift`

**Step 1: Write the failing tests**

```swift
import XCTest
@testable import SnipKeyCore

final class SnippetStoreTests: XCTestCase {
    var store: SnippetStore!
    var tempURL: URL!

    override func setUp() {
        super.setUp()
        tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("json")
        store = SnippetStore(fileURL: tempURL)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempURL)
        super.tearDown()
    }

    func testAddSnippet() {
        let snippet = Snippet(trigger: "email", replacement: "test@example.com")
        store.addSnippet(snippet)
        XCTAssertEqual(store.snippets.count, 1)
        XCTAssertEqual(store.snippets.first?.trigger, "email")
    }

    func testUpdateSnippet() {
        var snippet = Snippet(trigger: "email", replacement: "old@example.com")
        store.addSnippet(snippet)
        snippet.replacement = "new@example.com"
        store.updateSnippet(snippet)
        XCTAssertEqual(store.snippets.first?.replacement, "new@example.com")
    }

    func testDeleteSnippet() {
        let snippet = Snippet(trigger: "email", replacement: "test@example.com")
        store.addSnippet(snippet)
        store.deleteSnippet(id: snippet.id)
        XCTAssertTrue(store.snippets.isEmpty)
    }

    func testAddGroup() {
        let group = SnippetGroup(name: "Work")
        store.addGroup(group)
        XCTAssertEqual(store.groups.count, 1)
        XCTAssertEqual(store.groups.first?.name, "Work")
    }

    func testDeleteGroupRemovesGroupIdFromSnippets() {
        let group = SnippetGroup(name: "Work")
        store.addGroup(group)
        let snippet = Snippet(trigger: "email", replacement: "work@co.com", groupId: group.id)
        store.addSnippet(snippet)
        store.deleteGroup(id: group.id)
        XCTAssertTrue(store.groups.isEmpty)
        XCTAssertNil(store.snippets.first?.groupId)
    }

    func testPersistenceRoundTrip() {
        let snippet = Snippet(trigger: "addr", replacement: "123 Main St")
        store.addSnippet(snippet)
        store.save()

        let store2 = SnippetStore(fileURL: tempURL)
        store2.load()
        XCTAssertEqual(store2.snippets.count, 1)
        XCTAssertEqual(store2.snippets.first?.trigger, "addr")
    }

    func testSnippetsForGroup() {
        let group = SnippetGroup(name: "Work")
        store.addGroup(group)
        store.addSnippet(Snippet(trigger: "a", replacement: "1", groupId: group.id))
        store.addSnippet(Snippet(trigger: "b", replacement: "2", groupId: nil))
        XCTAssertEqual(store.snippets(forGroup: group.id).count, 1)
    }

    func testUngroupedSnippets() {
        let group = SnippetGroup(name: "Work")
        store.addGroup(group)
        store.addSnippet(Snippet(trigger: "a", replacement: "1", groupId: group.id))
        store.addSnippet(Snippet(trigger: "b", replacement: "2"))
        XCTAssertEqual(store.ungroupedSnippets.count, 1)
        XCTAssertEqual(store.ungroupedSnippets.first?.trigger, "b")
    }

    func testExportImport() throws {
        store.addSnippet(Snippet(trigger: "x", replacement: "y"))
        let exportURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("export-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: exportURL) }

        try store.exportData(to: exportURL)

        let store2 = SnippetStore(fileURL: tempURL)
        try store2.importData(from: exportURL)
        XCTAssertEqual(store2.snippets.count, 1)
        XCTAssertEqual(store2.snippets.first?.trigger, "x")
    }
}
```

**Step 2: Run tests to verify they fail**

Run: `swift test --filter SnippetStoreTests 2>&1 | head -30`
Expected: FAIL (SnippetStore not defined)

**Step 3: Implement SnippetStore**

```swift
import Foundation

public class SnippetStore: ObservableObject {
    @Published public var snippets: [Snippet] = []
    @Published public var groups: [SnippetGroup] = []

    private let fileURL: URL

    public init(fileURL: URL? = nil) {
        if let fileURL {
            self.fileURL = fileURL
        } else {
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            let dir = appSupport.appendingPathComponent("SnipKey")
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            self.fileURL = dir.appendingPathComponent("snippets.json")
        }
        load()
    }

    // MARK: - Snippet CRUD

    public func addSnippet(_ snippet: Snippet) {
        snippets.append(snippet)
        save()
    }

    public func updateSnippet(_ snippet: Snippet) {
        if let index = snippets.firstIndex(where: { $0.id == snippet.id }) {
            snippets[index] = snippet
            save()
        }
    }

    public func deleteSnippet(id: UUID) {
        snippets.removeAll { $0.id == id }
        save()
    }

    // MARK: - Group CRUD

    public func addGroup(_ group: SnippetGroup) {
        groups.append(group)
        save()
    }

    public func updateGroup(_ group: SnippetGroup) {
        if let index = groups.firstIndex(where: { $0.id == group.id }) {
            groups[index] = group
            save()
        }
    }

    public func deleteGroup(id: UUID) {
        groups.removeAll { $0.id == id }
        for i in snippets.indices where snippets[i].groupId == id {
            snippets[i].groupId = nil
        }
        save()
    }

    // MARK: - Queries

    public func snippets(forGroup groupId: UUID) -> [Snippet] {
        snippets.filter { $0.groupId == groupId }
    }

    public var ungroupedSnippets: [Snippet] {
        snippets.filter { $0.groupId == nil }
    }

    // MARK: - Persistence

    public func save() {
        let data = SnippetData(snippets: snippets, groups: groups)
        do {
            let encoded = try JSONEncoder().encode(data)
            try encoded.write(to: fileURL, options: .atomic)
        } catch {
            print("Failed to save snippets: \(error)")
        }
    }

    public func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        do {
            let data = try Data(contentsOf: fileURL)
            let decoded = try JSONDecoder().decode(SnippetData.self, from: data)
            snippets = decoded.snippets
            groups = decoded.groups
        } catch {
            print("Failed to load snippets: \(error)")
        }
    }

    // MARK: - Import/Export

    public func exportData(to url: URL) throws {
        let data = SnippetData(snippets: snippets, groups: groups)
        let encoded = try JSONEncoder().encode(data)
        try encoded.write(to: url, options: .atomic)
    }

    public func importData(from url: URL) throws {
        let data = try Data(contentsOf: url)
        let decoded = try JSONDecoder().decode(SnippetData.self, from: data)
        snippets = decoded.snippets
        groups = decoded.groups
        save()
    }
}
```

**Step 4: Run tests to verify they pass**

Run: `swift test --filter SnippetStoreTests`
Expected: All 9 tests PASS

**Step 5: Commit**

```bash
git add Sources/SnipKeyCore/SnippetStore.swift Tests/SnipKeyCoreTests/SnippetStoreTests.swift
git commit -m "feat: add SnippetStore with CRUD, persistence, import/export"
```

---

### Task 3: SnippetEngine (Matching Logic)

**Files:**
- Create: `Sources/SnipKeyCore/SnippetEngine.swift`
- Create: `Tests/SnipKeyCoreTests/SnippetEngineTests.swift`

**Step 1: Write the failing tests**

```swift
import XCTest
@testable import SnipKeyCore

final class SnippetEngineTests: XCTestCase {
    var engine: SnippetEngine!

    override func setUp() {
        super.setUp()
        let snippets = [
            Snippet(trigger: "account", replacement: "account1"),
            Snippet(trigger: "email", replacement: "test@example.com"),
            Snippet(trigger: "addr", replacement: "123 Main St"),
            Snippet(trigger: "address", replacement: "456 Oak Ave"),
        ]
        engine = SnippetEngine(snippets: snippets)
    }

    func testExactMatch() {
        let results = engine.match(query: "account")
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.trigger, "account")
    }

    func testPrefixMatch() {
        let results = engine.match(query: "acc")
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.trigger, "account")
    }

    func testMultipleMatches() {
        let results = engine.match(query: "addr")
        XCTAssertEqual(results.count, 2)
    }

    func testEmptyQueryReturnsAll() {
        let results = engine.match(query: "")
        XCTAssertEqual(results.count, 4)
    }

    func testNoMatch() {
        let results = engine.match(query: "zzz")
        XCTAssertTrue(results.isEmpty)
    }

    func testCaseInsensitiveMatch() {
        let results = engine.match(query: "ACC")
        XCTAssertEqual(results.count, 1)
    }

    func testIsExactMatch() {
        XCTAssertTrue(engine.isExactMatch("account"))
        XCTAssertFalse(engine.isExactMatch("acc"))
        XCTAssertFalse(engine.isExactMatch("zzz"))
    }

    func testFindByTrigger() {
        let snippet = engine.findExact(trigger: "email")
        XCTAssertNotNil(snippet)
        XCTAssertEqual(snippet?.replacement, "test@example.com")
    }

    func testUpdateSnippets() {
        engine.updateSnippets([Snippet(trigger: "new", replacement: "value")])
        XCTAssertEqual(engine.match(query: "").count, 1)
    }
}
```

**Step 2: Run tests to verify they fail**

Run: `swift test --filter SnippetEngineTests 2>&1 | head -20`
Expected: FAIL (SnippetEngine not defined)

**Step 3: Implement SnippetEngine**

```swift
import Foundation

public class SnippetEngine {
    private var snippets: [Snippet]

    public init(snippets: [Snippet] = []) {
        self.snippets = snippets
    }

    public func updateSnippets(_ snippets: [Snippet]) {
        self.snippets = snippets
    }

    /// Returns snippets whose trigger starts with the query (case-insensitive).
    /// Empty query returns all snippets.
    public func match(query: String) -> [Snippet] {
        if query.isEmpty { return snippets }
        let lower = query.lowercased()
        return snippets.filter { $0.trigger.lowercased().hasPrefix(lower) }
    }

    /// Returns true if query exactly matches a trigger.
    public func isExactMatch(_ query: String) -> Bool {
        let lower = query.lowercased()
        return snippets.contains { $0.trigger.lowercased() == lower }
    }

    /// Finds a snippet by exact trigger match (case-insensitive).
    public func findExact(trigger: String) -> Snippet? {
        let lower = trigger.lowercased()
        return snippets.first { $0.trigger.lowercased() == lower }
    }
}
```

**Step 4: Run tests to verify they pass**

Run: `swift test --filter SnippetEngineTests`
Expected: All 9 tests PASS

**Step 5: Commit**

```bash
git add Sources/SnipKeyCore/SnippetEngine.swift Tests/SnipKeyCoreTests/SnippetEngineTests.swift
git commit -m "feat: add SnippetEngine with prefix matching"
```

---

### Task 4: VariableResolver (Dynamic Variables)

**Files:**
- Create: `Sources/SnipKeyCore/VariableResolver.swift`
- Create: `Tests/SnipKeyCoreTests/VariableResolverTests.swift`

**Step 1: Write the failing tests**

```swift
import XCTest
@testable import SnipKeyCore

final class VariableResolverTests: XCTestCase {
    var resolver: VariableResolver!

    override func setUp() {
        super.setUp()
        resolver = VariableResolver()
    }

    func testPlainTextUnchanged() {
        XCTAssertEqual(resolver.resolve("hello world"), "hello world")
    }

    func testDateVariable() {
        let result = resolver.resolve("{date}")
        // Should contain current date components (year)
        let year = Calendar.current.component(.year, from: Date())
        XCTAssertTrue(result.contains(String(year)), "Expected result to contain year \(year), got: \(result)")
    }

    func testTimeVariable() {
        let result = resolver.resolve("{time}")
        XCTAssertTrue(result.contains(":"), "Expected time format with ':', got: \(result)")
    }

    func testClipboardVariable() {
        // Inject a known clipboard value for testing
        resolver = VariableResolver(clipboardProvider: { "clipboard-content" })
        let result = resolver.resolve("pasted: {clipboard}")
        XCTAssertEqual(result, "pasted: clipboard-content")
    }

    func testCursorVariable() {
        // {cursor} should be stripped (cursor positioning handled by caller)
        let result = resolver.resolve("Hello {cursor} World")
        XCTAssertEqual(result.text, "Hello  World")
        XCTAssertEqual(result.cursorOffset, 6)
    }

    func testMultipleVariables() {
        resolver = VariableResolver(clipboardProvider: { "CB" })
        let result = resolver.resolve("Date: {date}, Clip: {clipboard}")
        XCTAssertTrue(result.contains("Clip: CB"))
        XCTAssertTrue(result.contains("Date:"))
    }

    func testUnknownVariableLeftAsIs() {
        XCTAssertEqual(resolver.resolve("{unknown}"), "{unknown}")
    }

    func testMixedTextAndVariables() {
        resolver = VariableResolver(clipboardProvider: { "X" })
        let result = resolver.resolve("start {clipboard} end")
        XCTAssertEqual(result, "start X end")
    }
}
```

**Step 2: Run test to verify it fails**

Run: `swift test --filter VariableResolverTests 2>&1 | head -20`
Expected: FAIL (VariableResolver not defined)

**Step 3: Implement VariableResolver**

```swift
import Foundation

public struct ResolvedText {
    public let text: String
    public let cursorOffset: Int?  // nil if no {cursor} variable

    public init(text: String, cursorOffset: Int? = nil) {
        self.text = text
        self.cursorOffset = cursorOffset
    }
}

// Allow ResolvedText to be compared with String for convenience
extension ResolvedText: Equatable {}
extension ResolvedText: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self.text = value
        self.cursorOffset = nil
    }
}

// Allow XCTAssertEqual and string comparisons
extension ResolvedText: CustomStringConvertible {
    public var description: String { text }
}

public class VariableResolver {
    private let clipboardProvider: () -> String
    private let dateFormatter: DateFormatter
    private let timeFormatter: DateFormatter

    public init(clipboardProvider: @escaping () -> String = VariableResolver.systemClipboard) {
        self.clipboardProvider = clipboardProvider

        dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .none

        timeFormatter = DateFormatter()
        timeFormatter.dateStyle = .none
        timeFormatter.timeStyle = .short
    }

    public func resolve(_ template: String) -> ResolvedText {
        var result = template
        var cursorOffset: Int? = nil

        // Replace {date}
        result = result.replacingOccurrences(of: "{date}", with: dateFormatter.string(from: Date()))

        // Replace {time}
        result = result.replacingOccurrences(of: "{time}", with: timeFormatter.string(from: Date()))

        // Replace {clipboard}
        if result.contains("{clipboard}") {
            result = result.replacingOccurrences(of: "{clipboard}", with: clipboardProvider())
        }

        // Handle {cursor} - find position then remove
        if let range = result.range(of: "{cursor}") {
            cursorOffset = result.distance(from: result.startIndex, to: range.lowerBound)
            result = result.replacingOccurrences(of: "{cursor}", with: "")
        }

        return ResolvedText(text: result, cursorOffset: cursorOffset)
    }

    static func systemClipboard() -> String {
        #if canImport(AppKit)
        return NSPasteboard.general.string(forType: .string) ?? ""
        #else
        return ""
        #endif
    }
}
```

Note: The tests use `resolver.resolve(...)` which returns `ResolvedText`. For tests that compare with `String` directly (like `XCTAssertEqual(resolver.resolve("hello world"), "hello world")`), the `ExpressibleByStringLiteral` conformance handles this. For tests that use `.contains()`, we need to access `.text` property or make it conform to appropriate protocols. Let me adjust — the tests should use `.text` for string operations:

Update test expectations to use `.text` where needed:
- `resolver.resolve("hello world").text` for string equality
- `result.text.contains(...)` for contains checks

The `testCursorVariable` test already uses `.text` and `.cursorOffset`.

**Step 4: Run tests to verify they pass**

Run: `swift test --filter VariableResolverTests`
Expected: All 8 tests PASS

**Step 5: Commit**

```bash
git add Sources/SnipKeyCore/VariableResolver.swift Tests/SnipKeyCoreTests/VariableResolverTests.swift
git commit -m "feat: add VariableResolver with date, time, clipboard, cursor support"
```

---

### Task 5: AccessibilityHelper + KeyboardMonitor

**Files:**
- Create: `Sources/SnipKeyApp/AccessibilityHelper.swift`
- Create: `Sources/SnipKeyApp/KeyboardMonitor.swift`

**Step 1: Create AccessibilityHelper**

```swift
import Cocoa
import ApplicationServices

class AccessibilityHelper {
    /// Check if accessibility permission is granted
    static var isAccessibilityEnabled: Bool {
        AXIsProcessTrustedWithOptions(
            [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): false] as CFDictionary
        )
    }

    /// Prompt user to grant accessibility permission
    static func requestAccessibility() {
        AXIsProcessTrustedWithOptions(
            [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        )
    }

    /// Get the position of the focused text cursor using Accessibility API
    static func getCursorScreenPosition() -> NSPoint? {
        guard let focusedApp = NSWorkspace.shared.frontmostApplication else { return nil }
        let pid = focusedApp.processIdentifier
        let appElement = AXUIElementCreateApplication(pid)

        var focusedElement: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appElement, kAXFocusedUIElementAttribute as CFString, &focusedElement) == .success else {
            return nil
        }

        var selectedRange: CFTypeRef?
        guard AXUIElementCopyAttributeValue(focusedElement as! AXUIElement, kAXSelectedTextRangeAttribute as CFString, &selectedRange) == .success else {
            return nil
        }

        var bounds: CFTypeRef?
        guard AXUIElementCopyParameterizedAttributeValue(
            focusedElement as! AXUIElement,
            kAXBoundsForRangeParameterizedAttribute as CFString,
            selectedRange!,
            &bounds
        ) == .success else {
            return nil
        }

        var rect = CGRect.zero
        AXValueGetValue(bounds as! AXValue, .cgRect, &rect)
        return NSPoint(x: rect.origin.x, y: rect.origin.y + rect.size.height)
    }
}
```

**Step 2: Create KeyboardMonitor**

```swift
import Cocoa
import CoreGraphics
import SnipKeyCore

protocol KeyboardMonitorDelegate: AnyObject {
    func keyboardMonitor(_ monitor: KeyboardMonitor, didUpdateBuffer buffer: String)
    func keyboardMonitor(_ monitor: KeyboardMonitor, didCompleteTrigger trigger: String)
    func keyboardMonitorDidCancel(_ monitor: KeyboardMonitor)
    func keyboardMonitorDidRequestSelection(_ monitor: KeyboardMonitor, direction: KeyboardMonitor.SelectionDirection)
    func keyboardMonitorDidConfirmSelection(_ monitor: KeyboardMonitor)
}

class KeyboardMonitor {
    enum SelectionDirection { case up, down }

    weak var delegate: KeyboardMonitorDelegate?

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var buffer: String = ""
    private var isCapturing: Bool = false
    private let triggerPrefix: Character = "#"

    var isRunning: Bool { eventTap != nil }

    func start() {
        guard eventTap == nil else { return }

        let eventMask: CGEventMask = (1 << CGEventType.keyDown.rawValue)

        // Store self as userInfo for the callback
        let userInfo = Unmanaged.passRetained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: { (proxy, type, event, userInfo) -> Unmanaged<CGEvent>? in
                guard let userInfo else { return Unmanaged.passRetained(event) }
                let monitor = Unmanaged<KeyboardMonitor>.fromOpaque(userInfo).takeUnretainedValue()
                return monitor.handleEvent(proxy: proxy, type: type, event: event)
            },
            userInfo: userInfo
        ) else {
            print("Failed to create event tap. Is accessibility permission granted?")
            return
        }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    func stop() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            if let source = runLoopSource {
                CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
            }
        }
        if let userInfo = eventTap.flatMap({ Unmanaged<KeyboardMonitor>.fromOpaque(UnsafeRawPointer($0)).takeRetainedValue() as? KeyboardMonitor }) {
            // Release retained self
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
        guard type == .keyDown else { return Unmanaged.passRetained(event) }

        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let flags = event.flags

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
                return Unmanaged.passRetained(event)
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
                    resetBuffer()
                    DispatchQueue.main.async { self.delegate?.keyboardMonitorDidCancel(self) }
                }
                return Unmanaged.passRetained(event)
            }

            // Space or non-alphanumeric (except underscore/dash) ends capture
            if keyCode == 49 || (!character.isEmpty && !character.first!.isLetter && !character.first!.isNumber && character != "_" && character != "-") {
                resetBuffer()
                DispatchQueue.main.async { self.delegate?.keyboardMonitorDidCancel(self) }
                return Unmanaged.passRetained(event)
            }

            // Regular character - append to buffer
            if !character.isEmpty {
                buffer.append(character)
                let query = String(buffer.dropFirst()) // Remove # prefix
                DispatchQueue.main.async { self.delegate?.keyboardMonitor(self, didUpdateBuffer: query) }
            }
            return Unmanaged.passRetained(event)
        }

        // Not capturing - check for trigger prefix
        if character == String(triggerPrefix) {
            isCapturing = true
            buffer = String(triggerPrefix)
            DispatchQueue.main.async { self.delegate?.keyboardMonitor(self, didUpdateBuffer: "") }
        }

        return Unmanaged.passRetained(event)
    }

    deinit {
        stop()
    }
}
```

**Step 3: Run build to verify compilation**

Run: `swift build 2>&1 | tail -5`
Expected: Build succeeds

**Step 4: Commit**

```bash
git add Sources/SnipKeyApp/AccessibilityHelper.swift Sources/SnipKeyApp/KeyboardMonitor.swift
git commit -m "feat: add KeyboardMonitor with CGEvent Tap and AccessibilityHelper"
```

---

### Task 6: TextReplacer (Backspace + Paste)

**Files:**
- Create: `Sources/SnipKeyApp/TextReplacer.swift`

**Step 1: Implement TextReplacer**

```swift
import Cocoa
import CoreGraphics
import SnipKeyCore

class TextReplacer {
    private let variableResolver: VariableResolver

    init(variableResolver: VariableResolver = VariableResolver()) {
        self.variableResolver = variableResolver
    }

    /// Replace the trigger text with the snippet replacement.
    /// - Parameters:
    ///   - triggerLength: Number of characters to delete (including #)
    ///   - replacement: The replacement template string
    func replace(triggerLength: Int, replacement: String) {
        let resolved = variableResolver.resolve(replacement)

        // Step 1: Simulate backspace keys to delete the trigger
        simulateBackspaces(count: triggerLength)

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
                pasteboard.clearContents()
                pasteboard.setString(previous, forType: .string)
            }
        }
    }
}
```

**Step 2: Run build to verify compilation**

Run: `swift build 2>&1 | tail -5`
Expected: Build succeeds

**Step 3: Commit**

```bash
git add Sources/SnipKeyApp/TextReplacer.swift
git commit -m "feat: add TextReplacer with backspace + clipboard paste"
```

---

### Task 7: CompletionPanel + CompletionView (Floating Popup)

**Files:**
- Create: `Sources/SnipKeyApp/CompletionPanel.swift`
- Create: `Sources/SnipKeyApp/CompletionView.swift`

**Step 1: Create CompletionView (SwiftUI)**

```swift
import SwiftUI
import SnipKeyCore

struct CompletionView: View {
    let snippets: [Snippet]
    let selectedIndex: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if snippets.isEmpty {
                Text("No matches")
                    .foregroundColor(.secondary)
                    .padding(8)
            } else {
                ScrollViewReader { proxy in
                    ScrollView(.vertical, showsIndicators: true) {
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(Array(snippets.enumerated()), id: \.element.id) { index, snippet in
                                CompletionRow(
                                    snippet: snippet,
                                    isSelected: index == selectedIndex
                                )
                                .id(index)
                            }
                        }
                    }
                    .onChange(of: selectedIndex) { _, newValue in
                        withAnimation {
                            proxy.scrollTo(newValue, anchor: .center)
                        }
                    }
                }
            }
        }
        .frame(width: 320, height: min(CGFloat(snippets.count) * 44, 264))
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
    }
}

struct CompletionRow: View {
    let snippet: Snippet
    let isSelected: Bool

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("#\(snippet.trigger)")
                    .font(.system(.body, design: .monospaced))
                    .fontWeight(.medium)
                Text(snippet.replacement.prefix(60) + (snippet.replacement.count > 60 ? "..." : ""))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
        .contentShape(Rectangle())
    }
}
```

**Step 2: Create CompletionPanel (NSPanel)**

```swift
import Cocoa
import SwiftUI
import SnipKeyCore

class CompletionPanel {
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

        let hosting = NSHostingView(rootView: view)
        hosting.frame.size = hosting.fittingSize
        panel?.contentView = hosting
        panel?.setContentSize(hosting.fittingSize)
        hostingView = hosting

        // Position near cursor or center of screen
        if let pos = position {
            let origin = NSPoint(x: pos.x, y: pos.y - hosting.fittingSize.height - 4)
            panel?.setFrameOrigin(origin)
        } else if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let x = screenFrame.midX - hosting.fittingSize.width / 2
            let y = screenFrame.midY - hosting.fittingSize.height / 2
            panel?.setFrameOrigin(NSPoint(x: x, y: y))
        }

        panel?.orderFront(nil)
    }

    func updateView() {
        let view = CompletionView(snippets: matchedSnippets, selectedIndex: selectedIndex)
        let hosting = NSHostingView(rootView: view)
        hosting.frame.size = hosting.fittingSize
        panel?.contentView = hosting
        panel?.setContentSize(hosting.fittingSize)
        hostingView = hosting
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
}
```

**Step 3: Run build to verify compilation**

Run: `swift build 2>&1 | tail -5`
Expected: Build succeeds

**Step 4: Commit**

```bash
git add Sources/SnipKeyApp/CompletionPanel.swift Sources/SnipKeyApp/CompletionView.swift
git commit -m "feat: add CompletionPanel with floating SwiftUI popup"
```

---

### Task 8: Settings UI

**Files:**
- Create: `Sources/SnipKeyApp/SettingsView.swift`
- Create: `Sources/SnipKeyApp/SettingsWindow.swift`

**Step 1: Create SettingsView (SwiftUI)**

```swift
import SwiftUI
import SnipKeyCore

struct SettingsView: View {
    @ObservedObject var store: SnippetStore
    @State private var selectedGroupId: UUID? = nil
    @State private var selectedSnippetId: UUID? = nil
    @State private var editingTrigger: String = ""
    @State private var editingReplacement: String = ""
    @State private var editingGroupId: UUID? = nil

    var body: some View {
        NavigationSplitView {
            sidebar
        } content: {
            snippetList
        } detail: {
            snippetDetail
        }
        .frame(minWidth: 800, minHeight: 500)
        .onChange(of: selectedSnippetId) { _, newValue in
            if let id = newValue, let snippet = store.snippets.first(where: { $0.id == id }) {
                editingTrigger = snippet.trigger
                editingReplacement = snippet.replacement
                editingGroupId = snippet.groupId
            }
        }
    }

    // MARK: - Sidebar (Groups)

    private var sidebar: some View {
        List(selection: $selectedGroupId) {
            Label("All Snippets", systemImage: "tray.full")
                .tag(nil as UUID?)

            Section("Groups") {
                ForEach(store.groups) { group in
                    Label(group.name, systemImage: "folder")
                        .tag(group.id as UUID?)
                        .contextMenu {
                            Button("Delete Group") {
                                store.deleteGroup(id: group.id)
                            }
                        }
                }
            }
        }
        .listStyle(.sidebar)
        .frame(minWidth: 160)
        .toolbar {
            ToolbarItem {
                Button(action: addGroup) {
                    Label("Add Group", systemImage: "folder.badge.plus")
                }
            }
        }
    }

    // MARK: - Snippet List

    private var snippetList: some View {
        let filtered: [Snippet] = {
            if let groupId = selectedGroupId {
                return store.snippets(forGroup: groupId)
            }
            return store.snippets
        }()

        return List(filtered, selection: $selectedSnippetId) { snippet in
            VStack(alignment: .leading) {
                Text("#\(snippet.trigger)")
                    .font(.system(.body, design: .monospaced))
                    .fontWeight(.medium)
                Text(snippet.replacement.prefix(50) + (snippet.replacement.count > 50 ? "..." : ""))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            .tag(snippet.id)
            .contextMenu {
                Button("Delete") {
                    store.deleteSnippet(id: snippet.id)
                    if selectedSnippetId == snippet.id {
                        selectedSnippetId = nil
                    }
                }
            }
        }
        .frame(minWidth: 220)
        .toolbar {
            ToolbarItem {
                Button(action: addSnippet) {
                    Label("Add Snippet", systemImage: "plus")
                }
            }
            ToolbarItem {
                Button(action: exportSnippets) {
                    Label("Export", systemImage: "square.and.arrow.up")
                }
            }
            ToolbarItem {
                Button(action: importSnippets) {
                    Label("Import", systemImage: "square.and.arrow.down")
                }
            }
        }
    }

    // MARK: - Detail

    private var snippetDetail: some View {
        Group {
            if selectedSnippetId != nil {
                Form {
                    Section("Trigger") {
                        HStack {
                            Text("#")
                                .font(.system(.body, design: .monospaced))
                                .foregroundColor(.secondary)
                            TextField("trigger", text: $editingTrigger)
                                .font(.system(.body, design: .monospaced))
                                .onSubmit { saveEditing() }
                        }
                    }

                    Section("Replacement") {
                        TextEditor(text: $editingReplacement)
                            .font(.system(.body, design: .monospaced))
                            .frame(minHeight: 150)
                    }

                    Section("Group") {
                        Picker("Group", selection: $editingGroupId) {
                            Text("None").tag(nil as UUID?)
                            ForEach(store.groups) { group in
                                Text(group.name).tag(group.id as UUID?)
                            }
                        }
                    }

                    Section("Variables") {
                        Text("Available: {date} {time} {clipboard} {cursor}")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Button("Save") { saveEditing() }
                        .keyboardShortcut(.defaultAction)
                }
                .padding()
            } else {
                Text("Select a snippet to edit")
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - Actions

    private func addSnippet() {
        let snippet = Snippet(trigger: "new", replacement: "replacement text", groupId: selectedGroupId)
        store.addSnippet(snippet)
        selectedSnippetId = snippet.id
    }

    private func addGroup() {
        let group = SnippetGroup(name: "New Group")
        store.addGroup(group)
    }

    private func saveEditing() {
        guard let id = selectedSnippetId,
              var snippet = store.snippets.first(where: { $0.id == id }) else { return }
        snippet.trigger = editingTrigger
        snippet.replacement = editingReplacement
        snippet.groupId = editingGroupId
        store.updateSnippet(snippet)
    }

    private func exportSnippets() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "snipkey-snippets.json"
        if panel.runModal() == .OK, let url = panel.url {
            try? store.exportData(to: url)
        }
    }

    private func importSnippets() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        if panel.runModal() == .OK, let url = panel.url {
            try? store.importData(from: url)
        }
    }
}
```

**Step 2: Create SettingsWindow**

```swift
import Cocoa
import SwiftUI
import SnipKeyCore

class SettingsWindow {
    private var window: NSWindow?
    private let store: SnippetStore

    init(store: SnippetStore) {
        self.store = store
    }

    func show() {
        if let window, window.isVisible {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let settingsView = SettingsView(store: store)
        let hostingController = NSHostingController(rootView: settingsView)

        let w = NSWindow(contentViewController: hostingController)
        w.title = "SnipKey Settings"
        w.setContentSize(NSSize(width: 800, height: 500))
        w.styleMask = [.titled, .closable, .resizable, .miniaturizable]
        w.center()
        w.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        window = w
    }

    func close() {
        window?.close()
    }
}
```

**Step 3: Run build to verify compilation**

Run: `swift build 2>&1 | tail -5`
Expected: Build succeeds

**Step 4: Commit**

```bash
git add Sources/SnipKeyApp/SettingsView.swift Sources/SnipKeyApp/SettingsWindow.swift
git commit -m "feat: add SettingsView and SettingsWindow with full CRUD UI"
```

---

### Task 9: MenuBarController + AppDelegate

**Files:**
- Create: `Sources/SnipKeyApp/MenuBarController.swift`
- Create: `Sources/SnipKeyApp/AppDelegate.swift`
- Modify: `Sources/SnipKeyApp/SnipKeyApp.swift`

**Step 1: Create MenuBarController**

```swift
import Cocoa

protocol MenuBarControllerDelegate: AnyObject {
    func menuBarDidToggleEnabled(_ enabled: Bool)
    func menuBarDidRequestSettings()
    func menuBarDidRequestQuit()
}

class MenuBarController {
    weak var delegate: MenuBarControllerDelegate?

    private var statusItem: NSStatusItem?
    private var isEnabled = true

    func setup() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "text.cursor", accessibilityDescription: "SnipKey")
        }

        let menu = NSMenu()

        let toggleItem = NSMenuItem(title: "Enabled", action: #selector(toggleEnabled(_:)), keyEquivalent: "")
        toggleItem.target = self
        toggleItem.state = .on
        menu.addItem(toggleItem)

        menu.addItem(.separator())

        let settingsItem = NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit SnipKey", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem?.menu = menu
    }

    @objc private func toggleEnabled(_ sender: NSMenuItem) {
        isEnabled.toggle()
        sender.state = isEnabled ? .on : .off
        delegate?.menuBarDidToggleEnabled(isEnabled)
    }

    @objc private func openSettings() {
        delegate?.menuBarDidRequestSettings()
    }

    @objc private func quit() {
        delegate?.menuBarDidRequestQuit()
    }
}
```

**Step 2: Create AppDelegate (the central coordinator)**

```swift
import Cocoa
import SnipKeyCore

class AppDelegate: NSObject, NSApplicationDelegate {
    private let store = SnippetStore()
    private let engine = SnippetEngine()
    private let keyboardMonitor = KeyboardMonitor()
    private let textReplacer = TextReplacer()
    private let completionPanel = CompletionPanel()
    private let menuBarController = MenuBarController()
    private lazy var settingsWindow = SettingsWindow(store: store)

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Check accessibility
        if !AccessibilityHelper.isAccessibilityEnabled {
            AccessibilityHelper.requestAccessibility()
        }

        // Setup engine with current snippets
        engine.updateSnippets(store.snippets)

        // Observe snippet changes
        store.$snippets
            .receive(on: RunLoop.main)
            .sink { [weak self] snippets in
                self?.engine.updateSnippets(snippets)
            }
            .store(in: &cancellables)

        // Setup keyboard monitor
        keyboardMonitor.delegate = self
        keyboardMonitor.start()

        // Setup menu bar
        menuBarController.delegate = self
        menuBarController.setup()
    }

    func applicationWillTerminate(_ notification: Notification) {
        keyboardMonitor.stop()
    }

    private var cancellables = Set<AnyCancellable>()
}

import Combine

extension AppDelegate: KeyboardMonitorDelegate {
    func keyboardMonitor(_ monitor: KeyboardMonitor, didUpdateBuffer buffer: String) {
        let matches = engine.match(query: buffer)
        let cursorPos = AccessibilityHelper.getCursorScreenPosition()
        completionPanel.show(snippets: matches, near: cursorPos)
    }

    func keyboardMonitor(_ monitor: KeyboardMonitor, didCompleteTrigger trigger: String) {
        if let snippet = engine.findExact(trigger: trigger) {
            completionPanel.hide()
            // +1 for the # prefix
            textReplacer.replace(triggerLength: trigger.count + 1, replacement: snippet.replacement)
            monitor.resetBuffer()
        }
    }

    func keyboardMonitorDidCancel(_ monitor: KeyboardMonitor) {
        completionPanel.hide()
    }

    func keyboardMonitor(_ monitor: KeyboardMonitor, didRequestSelection direction: KeyboardMonitor.SelectionDirection) {
        switch direction {
        case .up: completionPanel.moveSelectionUp()
        case .down: completionPanel.moveSelectionDown()
        }
    }

    func keyboardMonitorDidConfirmSelection(_ monitor: KeyboardMonitor) {
        guard let snippet = completionPanel.selectedSnippet else { return }
        completionPanel.hide()
        // Delete whatever is in the buffer + # prefix, replace with snippet
        // The buffer in the monitor includes what's typed after #
        textReplacer.replace(triggerLength: monitor.currentBufferLength, replacement: snippet.replacement)
        monitor.resetBuffer()
    }
}

extension AppDelegate: MenuBarControllerDelegate {
    func menuBarDidToggleEnabled(_ enabled: Bool) {
        if enabled {
            keyboardMonitor.start()
        } else {
            keyboardMonitor.stop()
            completionPanel.hide()
        }
    }

    func menuBarDidRequestSettings() {
        settingsWindow.show()
    }

    func menuBarDidRequestQuit() {
        NSApp.terminate(nil)
    }
}
```

Note: Need to expose `currentBufferLength` from KeyboardMonitor. Add this computed property:

```swift
// Add to KeyboardMonitor
var currentBufferLength: Int { buffer.count }
```

**Step 3: Update SnipKeyApp.swift entry point**

```swift
import Cocoa

let delegate = AppDelegate()
let app = NSApplication.shared
app.delegate = delegate
app.run()
```

**Step 4: Run build to verify compilation**

Run: `swift build 2>&1 | tail -10`
Expected: Build succeeds

**Step 5: Commit**

```bash
git add Sources/SnipKeyApp/
git commit -m "feat: add MenuBarController, AppDelegate, wire everything together"
```

---

### Task 10: Run All Tests + Integration Smoke Test

**Step 1: Run full test suite**

Run: `swift test`
Expected: All tests PASS (Models: 4, SnippetStore: 9, SnippetEngine: 9, VariableResolver: 8 = ~30 tests)

**Step 2: Build the app bundle**

Run: `make bundle`
Expected: App bundle created at `.build/SnipKey.app`

**Step 3: Manual smoke test**

Run: `open .build/SnipKey.app`
Expected:
- Menu bar icon appears
- Click "Settings..." opens settings window
- Can add a snippet (e.g., trigger: `account`, replacement: `account1`)
- Grant accessibility permission when prompted
- Type `#account` in any text field → completion popup appears → Tab/Enter replaces with `account1`

**Step 4: Final commit**

```bash
git add -A
git commit -m "feat: SnipKey v1.0 - complete Mac text expansion tool"
```

---

## Summary

| Task | Description | Tests |
|------|-------------|-------|
| 1 | Project scaffolding + Models | 4 |
| 2 | SnippetStore (persistence) | 9 |
| 3 | SnippetEngine (matching) | 9 |
| 4 | VariableResolver (dynamic vars) | 8 |
| 5 | AccessibilityHelper + KeyboardMonitor | build |
| 6 | TextReplacer (backspace + paste) | build |
| 7 | CompletionPanel + CompletionView | build |
| 8 | SettingsView + SettingsWindow | build |
| 9 | MenuBarController + AppDelegate | build |
| 10 | Full test suite + smoke test | all |
