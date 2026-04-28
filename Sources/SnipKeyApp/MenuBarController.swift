import Cocoa

protocol MenuBarControllerDelegate: AnyObject {
    func menuBarDidToggleEnabled(_ enabled: Bool)
    func menuBarDidRequestPermissions()
    func menuBarDidRequestSettings()
    func menuBarDidRequestClipboardHistory()
    func menuBarDidRequestQuit()
}

class MenuBarController {
    weak var delegate: MenuBarControllerDelegate?

    private var statusItem: NSStatusItem?
    private var isEnabled = true
    private var toggleItem: NSMenuItem?
    private var language: AppLanguage = .current

    func setup(language: AppLanguage) {
        self.language = language
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "text.cursor", accessibilityDescription: "SnipKey")
        }

        rebuildMenu()
    }

    func updateLanguage(_ language: AppLanguage) {
        self.language = language
        rebuildMenu()
    }

    private func rebuildMenu() {
        let menu = NSMenu()

        let toggle = NSMenuItem(title: L10n.text(.menuEnable, language: language), action: #selector(toggleEnabled(_:)), keyEquivalent: "")
        toggle.target = self
        toggle.state = isEnabled ? .on : .off
        toggleItem = toggle
        menu.addItem(toggle)

        menu.addItem(.separator())

        let permissionsItem = NSMenuItem(title: L10n.text(.menuGrantPermissionsEllipsis, language: language), action: #selector(openPermissions), keyEquivalent: "")
        permissionsItem.target = self
        menu.addItem(permissionsItem)

        let settingsItem = NSMenuItem(title: L10n.text(.menuSettingsEllipsis, language: language), action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        let clipboardHistoryItem = NSMenuItem(title: L10n.text(.menuClipboardHistoryEllipsis, language: language), action: #selector(openClipboardHistory), keyEquivalent: "")
        clipboardHistoryItem.target = self
        menu.addItem(clipboardHistoryItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: L10n.text(.menuQuitSnipKey, language: language), action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem?.menu = menu
    }

    func updateEnabledState(_ enabled: Bool) {
        isEnabled = enabled
        toggleItem?.state = enabled ? .on : .off

        if let button = statusItem?.button {
            let symbolName = enabled ? "text.cursor" : "text.cursor"
            button.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: "SnipKey")
            button.appearsDisabled = !enabled
        }
    }

    @objc private func toggleEnabled(_ sender: NSMenuItem) {
        isEnabled.toggle()
        updateEnabledState(isEnabled)
        delegate?.menuBarDidToggleEnabled(isEnabled)
    }

    @objc private func openSettings() {
        delegate?.menuBarDidRequestSettings()
    }

    @objc private func openPermissions() {
        delegate?.menuBarDidRequestPermissions()
    }

    @objc private func openClipboardHistory() {
        delegate?.menuBarDidRequestClipboardHistory()
    }

    @objc private func quit() {
        delegate?.menuBarDidRequestQuit()
    }
}
