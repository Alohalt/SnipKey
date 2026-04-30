# Windows Packaging

Date: 2026-04-30

SnipKey's Windows app currently uses a .NET publish output as the smallest maintainable distribution artifact. A signed installer is still a follow-up decision.

## Current Publish Flow

From the repository root on Windows with .NET 8 SDK installed:

```powershell
dotnet build .\Windows\SnipKey.Windows\SnipKey.Windows.csproj
dotnet publish .\Windows\SnipKey.Windows\SnipKey.Windows.csproj -c Release -r win-x64 --self-contained false -p:PublishSingleFile=true -o .\.build\windows-publish
```

When `make` is available:

```powershell
make windows-build
make windows-publish
```

The publish output is written to `.build/windows-publish`.

## Installer Decision

Recommended next step: use a traditional installer such as WiX/MSI or NSIS for the tray-app shape.

Rationale:

- SnipKey is a desktop tray utility, so install location, Start Menu entries, optional startup registration, and clean uninstall matter more than Store-style packaging at this stage.
- MSIX is still viable later, but it adds identity and packaging constraints that should be evaluated after the input and clipboard behavior stabilizes.
- The current publish output gives a simple artifact that can be smoke-tested on a clean machine before installer-specific work begins.

## Clean Machine Validation

Before adding an installer, verify the published folder directly:

1. Copy `.build/windows-publish` to a clean Windows 10 19041+ or Windows 11 machine with .NET Desktop Runtime 8 installed.
2. Launch `SnipKey.Windows.exe`.
3. Confirm the tray icon appears and Settings opens.
4. Create a Key, expand it in Notepad, and verify clipboard history records normal user copies.
5. Delete the folder and confirm no source-tree path is required.

## Follow-Up Packaging Tasks

- Choose WiX/MSI or NSIS.
- Add code signing inputs and documented certificate expectations.
- Decide whether startup registration is opt-in during install or controlled inside Settings.
- Add uninstall validation for `%APPDATA%\SnipKey` preservation versus explicit data removal.