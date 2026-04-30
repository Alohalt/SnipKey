# SnipKey Windows

This directory contains the native Windows app for SnipKey.

## Scope

Implemented:

- Tray app with enable, keyboard help, settings, clipboard history, reload, about, and quit actions.
- Global low-level keyboard hook for `#trigger` capture.
- Completion popup with keyboard navigation and mouse confirmation.
- Outside-click cancellation for the active completion session.
- Text replacement through backspace simulation plus clipboard paste.
- Three-column settings window for group browsing, Key CRUD, group assignment, language switching, guide/about, and JSON import/export.
- Clipboard history with monitoring toggle, repeated-copy Key suggestions, recent-copy management, and one-click Key creation.
- English and Simplified Chinese UI language switching. The default is Simplified Chinese.
- Same `snippets.json` field names as the macOS app.

Known remaining productization work:

- Accessibility or UI Automation readback for IME/composition-aware trigger reconciliation.
- Final installer selection, signing, auto-start, and update packaging.

## Requirements

- Windows 10 19041+ or Windows 11
- .NET 8 SDK

## Build And Run

From the repository root on Windows:

```powershell
dotnet build .\Windows\SnipKey.Windows\SnipKey.Windows.csproj
dotnet run --project .\Windows\SnipKey.Windows\SnipKey.Windows.csproj
```

The Makefile wrappers are also available when `make` is installed:

```powershell
make windows-build
make windows-run
make windows-publish
```

## UI Development Notes

- The current Windows UI is code-only WPF. `SettingsWindow` and `CompletionWindow` build their layout in C# rather than XAML.
- Shared visual tokens and reusable control styles now live in `Windows/SnipKey.Windows/UI/UiTheme.cs`. Prefer extending that file instead of scattering new colors, corner radii, or button/text box styles across multiple windows.
- `SettingsWindow` uses a sidebar/browse/detail layout. The search field uses a lightweight placeholder overlay, and the trigger editor intentionally renders the `#` prefix outside the editable text so the field matches the macOS interaction model more closely.
- `CompletionWindow` keeps the non-activating topmost popup behavior. UI refinements there should preserve mouse hover selection, click confirmation, and the existing no-focus-steal window flags.
- `ClipboardMonitor` uses `AddClipboardFormatListener` on a hidden WPF message source and ignores SnipKey's own replacement clipboard writes.
- The cheapest validation loop for Windows UI work is:

```powershell
dotnet build .\Windows\SnipKey.Windows\SnipKey.Windows.csproj
dotnet run --project .\Windows\SnipKey.Windows\SnipKey.Windows.csproj
```

After the build passes, verify the Settings window and completion popup manually on a Windows machine because keyboard hook behavior and popup feel are still platform-dependent.

## Data

The MVP stores Keys at:

```text
%APPDATA%\SnipKey\snippets.json
```

Additional Windows files:

```text
%APPDATA%\SnipKey\clipboard-history.json
%APPDATA%\SnipKey\app-settings.json
```

The Key JSON shape intentionally matches the macOS app so exported data can move between platforms. Clipboard history and language settings are stored separately from Keys.

## Input And Packaging Notes

- See [../docs/windows-input-compatibility.md](../docs/windows-input-compatibility.md) for current IME, terminal, browser, and privilege-level boundaries.
- See [../docs/windows-packaging.md](../docs/windows-packaging.md) for the current `dotnet publish` flow and the recommended installer decision path.
