# Windows Input Compatibility

Date: 2026-04-30

This document records the current Windows input boundary for SnipKey. It is intentionally conservative: the app uses a low-level keyboard hook and simulated replacement, not UI Automation or TSF readback.

## Current Behavior

- SnipKey captures ASCII `#trigger` text through a global low-level keyboard hook.
- Trigger characters are limited to letters, digits, and underscores.
- Completion can be accepted with `Tab`, `Enter`, arrow selection, or mouse click.
- Clicking outside the completion popup cancels the active completion session and resets the keyboard buffer.
- Direct expansion deletes the typed trigger plus the terminating character, then pastes the resolved replacement text through the clipboard.

## IME Boundary

The Windows implementation does not yet read TSF composition state or text-before-cursor through UI Automation. For Chinese IME and other composition-based input methods, the supported path is:

1. Commit an ASCII `#trigger` string.
2. Type a non-trigger terminator such as space, punctuation, or Enter.
3. Let SnipKey replace the committed trigger text.

Known limitation: if an IME keeps the trigger inside an active composition buffer, the low-level hook can see key events before the target control has committed text. That case is not treated as fully supported yet.

## Privilege Boundary

Windows blocks lower-privilege processes from reliably interacting with higher-privilege windows. If the target app runs as administrator, run SnipKey as administrator for keyboard hook and replacement behavior to be consistent.

## App Class Notes

- Notepad and normal desktop text fields are the primary validation targets.
- Browser text fields are expected to work when the browser runs at the same privilege level, but secure fields may block paste or input simulation.
- Terminals vary by host and shell. Basic replacement should work in normal prompt input, but alternate screen applications and elevated terminals are not guaranteed.
- Password fields and secure input surfaces are intentionally not a supported target.

## Next Useful Validation

The cheapest regression pass after input changes is:

1. Build with `dotnet build .\Windows\SnipKey.Windows\SnipKey.Windows.csproj`.
2. In Notepad, create a Key and expand it with `#trigger `.
3. Open completion with a partial trigger, click outside once, and confirm no replacement occurs.
4. Repeat with a Chinese IME after committing ASCII `#trigger` before the terminator.