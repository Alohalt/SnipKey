# SnipKey Windows MVP

This directory contains the native Windows MVP for SnipKey.

## Scope

Implemented in this first Windows slice:

- Tray app with enable, settings, reload, and quit actions.
- Global low-level keyboard hook for `#trigger` capture.
- Completion popup with keyboard navigation and mouse confirmation.
- Text replacement through backspace simulation plus clipboard paste.
- Settings window for creating, editing, deleting, importing, and exporting Keys.
- Same `snippets.json` field names as the macOS app.

Deferred from the MVP:

- Clipboard history and repeated-copy Key suggestions.
- Full English/Simplified Chinese UI switching.
- Accessibility or UI Automation readback for IME/composition-aware trigger reconciliation.
- Installer, signing, auto-start, and update packaging.

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
```

## Data

The MVP stores Keys at:

```text
%APPDATA%\SnipKey\snippets.json
```

The JSON shape intentionally matches the macOS app so exported data can move between platforms.
