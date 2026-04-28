import AppKit

@main
struct SnipKeyAppMain {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.mainMenu = AppMenuFactory.makeMainMenu(target: delegate, language: AppLanguage.current)
        app.run()
    }
}

enum AppMenuFactory {
    static func makeMainMenu(target: AppDelegate, language: AppLanguage) -> NSMenu {
        let mainMenu = NSMenu()

        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)

        let appMenu = NSMenu(title: "SnipKey")
        let settingsItem = NSMenuItem(title: L10n.text(.menuSettingsEllipsis, language: language), action: #selector(AppDelegate.openSettingsFromAppMenu(_:)), keyEquivalent: ",")
        settingsItem.target = target
        appMenu.addItem(settingsItem)
        appMenu.addItem(.separator())

        let quitItem = NSMenuItem(title: L10n.text(.menuQuitSnipKey, language: language), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appMenu.addItem(quitItem)
        appMenuItem.submenu = appMenu

        let editMenuItem = NSMenuItem()
        mainMenu.addItem(editMenuItem)

        let editMenu = NSMenu(title: L10n.text(.menuEdit, language: language))
        editMenu.addItem(withTitle: L10n.text(.menuUndo, language: language), action: Selector(("undo:")), keyEquivalent: "z")

        let redoItem = NSMenuItem(title: L10n.text(.menuRedo, language: language), action: Selector(("redo:")), keyEquivalent: "z")
        redoItem.keyEquivalentModifierMask = [.command, .shift]
        editMenu.addItem(redoItem)

        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: L10n.text(.menuCut, language: language), action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: L10n.text(.menuCopy, language: language), action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: L10n.text(.menuPaste, language: language), action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: L10n.text(.menuSelectAll, language: language), action: #selector(NSResponder.selectAll(_:)), keyEquivalent: "a")
        editMenuItem.submenu = editMenu

        return mainMenu
    }
}
