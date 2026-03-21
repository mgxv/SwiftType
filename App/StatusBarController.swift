import AppKit

@MainActor final class StatusBarController: NSObject {
    private let statusItem: NSStatusItem

    override init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()
        if let button = statusItem.button {
            button.font = NSFont.monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .medium)
        }
        statusItem.menu = buildMenu()

        updateStatusTitle()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateStatusTitle),
            name: .activePredictionLanguageDidChange,
            object: nil,
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateStatusTitle),
            name: NSTextInputContext.keyboardSelectionDidChangeNotification,
            object: nil,
        )
    }

    // MARK: - Status Title

    @objc private func updateStatusTitle() {
        statusItem.button?.title = LanguageManager.shared.effectiveBaseCode.uppercased()
    }

    // MARK: - Menu

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()
        menu.delegate = self

        menu.addItem(.separator())

        let settingsItem = NSMenuItem(title: "Settings", action: #selector(openSettings), keyEquivalent: "")
        settingsItem.target = self
        menu.addItem(settingsItem)
        return menu
    }

    @objc private func openSettings() {
        SettingsWindowController.shared.showWindow()
    }

    @objc private func languageItemClicked(_ sender: NSMenuItem) {
        let code = sender.representedObject as? String ?? ""
        LanguageManager.shared.selectLanguage(code: code)
    }
}

// MARK: - NSMenuDelegate

extension StatusBarController: NSMenuDelegate {
    func menuWillOpen(_ menu: NSMenu) {
        while let first = menu.items.first, !first.isSeparatorItem {
            menu.removeItem(at: 0)
        }
        // Compute which language is currently active: pinned code, or system keyboard if unpinned.
        let selected = LanguageManager.shared.selectedCode
        let systemBase = NSSpellChecker.shared.language().baseLanguageCode
        let effectiveCode = selected.isEmpty
            ? (LanguageManager.shared.addedCodes.contains(systemBase) ? systemBase : "")
            : selected

        for (index, descriptor) in LanguageManager.shared.addedDescriptors.enumerated() {
            let item = NSMenuItem(title: descriptor.displayName,
                                  action: #selector(languageItemClicked(_:)),
                                  keyEquivalent: "")
            item.target = self
            item.representedObject = descriptor.code
            item.state = descriptor.code == effectiveCode ? .on : .off
            menu.insertItem(item, at: index)
        }
    }
}
