# SnipKey for Mac - Design Document

**Date**: 2026-04-15
**Platform**: macOS (Mac优先，后续Windows)
**Tech Stack**: Swift + SwiftUI + CGEvent Tap

---

## Overview

A system-wide text expansion tool for macOS. Users define snippets with trigger keys; typing `#trigger` anywhere on the system expands it to the configured replacement text. A floating completion window appears near the cursor for autocomplete.

## Trigger Prefix

- Prefix: `#`
- Example: typing `#account` replaces with `account1`

## Architecture

### Application Type

macOS Menu Bar App (no Dock icon). Runs as a background service with a menu bar icon for quick access to settings.

### Core Components

| Component | Responsibility | Technology |
|-----------|---------------|------------|
| **KeyboardMonitor** | Global keyboard listening, input buffer management | CGEvent Tap |
| **SnippetEngine** | Trigger matching, text replacement execution | Simulated backspace + clipboard paste |
| **CompletionWindow** | Floating autocomplete UI near cursor | NSPanel + SwiftUI |
| **SnippetStore** | CRUD operations, group management, persistence | JSON file + Codable |
| **SettingsWindow** | Configuration management UI | SwiftUI |
| **VariableResolver** | Dynamic variable parsing and resolution | Regex + template engine |

### Data Flow

```
Keyboard input → CGEvent Tap intercepts
  → Input buffer appends character
  → Detects "#" prefix
  → Fuzzy match snippet list
  → Show completion window (NSPanel)
  → User selects / completes trigger word
  → Backspace to delete trigger → Paste replacement text
```

## Text Replacement Mechanism

### Trigger Flow

1. User types `#` → start capturing to buffer
2. Buffer appends subsequent characters, real-time snippet matching
3. On full match (e.g., `#account` matches snippet `account`), Tab/Enter to confirm
4. Replacement: simulate backspace keys to delete `#account` (N characters) → paste replacement via clipboard

### Completion Window Behavior

- Appears immediately after `#` is typed, showing all snippets
- Filters in real-time as each character is typed
- Up/Down arrows to select, Tab/Enter to confirm, Esc to dismiss
- Auto-hides when no matches found

## Data Model

```swift
struct Snippet: Codable, Identifiable {
    let id: UUID
    var trigger: String        // e.g. "account"
    var replacement: String    // Supports multi-line, supports dynamic variables
    var groupId: UUID?         // Group reference
}

struct SnippetGroup: Codable, Identifiable {
    let id: UUID
    var name: String
}
```

### Dynamic Variables

| Variable | Description |
|----------|-------------|
| `{date}` | Current date (localized format) |
| `{time}` | Current time |
| `{clipboard}` | Current clipboard content |
| `{cursor}` | Cursor position after expansion |

## Storage

- **Path**: `~/Library/Application Support/SnipKey/snippets.json`
- **Format**: JSON (Codable serialization)
- **Import/Export**: Full JSON file import/export for backup and sharing

## Permissions

- **Accessibility Permission**: Required for CGEvent Tap (global keyboard monitoring)
- App will prompt user to grant permission on first launch
- Guide user to System Settings → Privacy & Security → Accessibility

## UI Screens

### 1. Menu Bar
- Status icon in menu bar
- Dropdown: Enable/Disable, Open Settings, Quit

### 2. Settings Window (SwiftUI)
- **Sidebar**: Snippet groups (folders)
- **Main area**: Snippet list with trigger and preview
- **Detail panel**: Edit trigger, replacement text, group assignment
- **Toolbar**: Add/Delete snippet, Import/Export buttons

### 3. Completion Popup (NSPanel)
- Borderless, floating, always-on-top
- Shows matching snippets with trigger and preview
- Keyboard navigable (up/down/enter/esc)
- Positioned near text cursor using Accessibility API for cursor position

## Future Considerations (not in v1)

- Windows version (C# / WPF)
- Cloud sync across devices
- Rich text / HTML snippet support
- Per-application snippet activation rules
