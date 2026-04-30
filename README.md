# SnipKey

English | [简体中文](README.zh-CN.md)

SnipKey is a macOS menu bar text expansion tool. Type `#trigger` in any app to open a completion panel or expand directly into preconfigured text.

A native Windows app now lives under `Windows/SnipKey.Windows`. It is implemented as a .NET 8 WPF tray app and keeps the same `snippets.json` data shape as the macOS app.

Project site: <https://alohalt.github.io/SnipKey/>. The content under `site/` is deployed through GitHub Actions, and the repository Pages source should be set to `GitHub Actions`.

## Current Capabilities

- Monitors keyboard input globally and captures triggers prefixed with `#` across the system.
- Shows a floating completion panel near the cursor with matching results, supporting arrow navigation, `Tab` or `Enter` to confirm, `Esc` to cancel, plus mouse hover highlight and click-to-insert.
- Cancels the current completion session immediately when clicking outside the panel, reducing the risk of inserting text into the wrong target.
- Runs from the menu bar and provides quick entry points for permission guidance, settings, and clipboard history.
- Includes a native three-column settings UI with grouping, search, create, edit, delete, and JSON import/export.
- Supports runtime UI language switching between English and Simplified Chinese. The default remains Simplified Chinese, and switching only affects UI copy, not existing Keys, groups, or clipboard data.
- Restricts triggers to letters, numbers, and underscores, with uniqueness validation enforced on save.
- Supports dynamic variables: `{date}`, `{time}`, `{clipboard}`, and `{cursor}`.
- Records clipboard history and suggests creating a new Key when content is copied repeatedly. The UI retains the latest 50 records while suggestion counters remain independent from the visible list.
- Sorts candidates by acceptance count so frequently used Keys appear earlier.

## Project Structure

```text
.
├── Sources/
│   ├── SnipKeyCore/      # Testable core logic: data models, matching, variable resolution, persistence
│   └── SnipKeyApp/       # macOS app layer: menu bar, permissions, keyboard monitoring, settings UI, completion panel
├── Windows/
│   └── SnipKey.Windows/  # Native Windows app: tray, keyboard hook, settings, clipboard history, completion popup
├── Tests/
│   └── SnipKeyCoreTests/ # Unit tests for the core layer
├── Resources/            # Info.plist, entitlements, app icon resources
├── Scripts/              # Helper scripts
└── docs/                 # Design notes, signing flow, and requirement history
```

## Requirements

- macOS 13+
- Swift 5.9+
- Xcode, recommended for signing and more stable permission behavior
- Accessibility permission

Windows requirements:

- Windows 10 19041+ or Windows 11
- .NET 8 SDK

## Quick Start

Running the signed development app bundle is recommended over `swift run`. This keeps macOS permissions attached to a stable app identity instead of a frequently rebuilt executable path.

```bash
make signing-help
make bootstrap-personal-team
make run
```

If an `Apple Development` certificate is already available on the machine, these two commands are usually enough:

```bash
make test
make run
```

Common commands:

```bash
make build        # Build with SwiftPM
make test         # Run unit tests
make run          # Install and launch the signed development app
make run-swift    # Run the Swift executable directly; not recommended for permission debugging
make windows-build # Build the Windows app on a Windows machine with .NET 8 SDK
make windows-run  # Run the Windows app on Windows
make windows-publish # Publish a win-x64 build into .build/windows-publish
make verify-dev   # Inspect the signed development bundle
make package-dmg  # Build a distributable DMG
```

For the full signing workflow, see [docs/development-signing.md](docs/development-signing.md).

## Usage

1. Launch the app and open Settings from the menu bar.
2. Create a new Key. For example, use `account` as the trigger and enter the text that should be inserted. Triggers support only letters, numbers, and underscores, and they must be unique.
3. Return to any text input field and type `#account`.
4. Use `Tab`, `Enter`, or a mouse click on the candidate item to confirm expansion. Clicking outside the hint panel cancels the current completion session.

The settings sidebar includes a language switcher for English and Simplified Chinese.

When expansion is confirmed, SnipKey deletes the typed trigger content and inserts the resolved replacement text.

If existing local data contains Chinese, invalid, or duplicate triggers, the app normalizes them during load or import into legal, unique triggers automatically.

## Data Storage

- Key data: `~/Library/Application Support/SnipKey/snippets.json`
- Clipboard history: `~/Library/Application Support/SnipKey/clipboard-history.json` — the UI keeps the latest 50 records, and clearing history also resets suggestion counters
- UI language preference: `SnipKey.appLanguage` in `UserDefaults`, stored separately from Key and clipboard JSON data

Windows stores the corresponding files under `%APPDATA%\SnipKey\`: `snippets.json`, `clipboard-history.json`, and `app-settings.json`.

## Testing

The repository currently focuses test coverage on `SnipKeyCore`:

- `SnippetStoreTests`
- `SnippetEngineTests`
- `VariableResolverTests`
- `ClipboardHistoryStoreTests`
- `ModelsTests`

AppKit and system-permission-related behavior is still validated primarily through manual testing.

## Related Documents

- [docs/development-signing.md](docs/development-signing.md)
- [docs/windows-input-compatibility.md](docs/windows-input-compatibility.md)
- [docs/windows-packaging.md](docs/windows-packaging.md)
- [docs/plans/2026-04-15-snipkey-mac-design.md](docs/plans/2026-04-15-snipkey-mac-design.md)
- [docs/plans/2026-04-15-snipkey-implementation.md](docs/plans/2026-04-15-snipkey-implementation.md)
- [docs/requirements-change-log.md](docs/requirements-change-log.md)
