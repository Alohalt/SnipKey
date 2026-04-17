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

    func setup() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "text.cursor", accessibilityDescription: "SnipKey")
        }

        let menu = NSMenu()

        let toggle = NSMenuItem(title: "启用", action: #selector(toggleEnabled(_:)), keyEquivalent: "")
        toggle.target = self
        toggle.state = .on
        toggleItem = toggle
        menu.addItem(toggle)

        menu.addItem(.separator())

        let permissionsItem = NSMenuItem(title: "授予权限…", action: #selector(openPermissions), keyEquivalent: "")
        permissionsItem.target = self
        menu.addItem(permissionsItem)

        let settingsItem = NSMenuItem(title: "设置\u{2026}", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        let clipboardHistoryItem = NSMenuItem(title: "剪贴板记录\u{2026}", action: #selector(openClipboardHistory), keyEquivalent: "")
        clipboardHistoryItem.target = self
        menu.addItem(clipboardHistoryItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "退出 SnipKey", action: #selector(quit), keyEquivalent: "q")
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
