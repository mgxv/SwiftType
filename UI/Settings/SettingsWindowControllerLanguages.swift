import AppKit

// MARK: - Languages Tab

extension SettingsWindowController {
    func makeLanguagesTab() -> NSView {
        let (scrollView, tv) = makeTableScrollView(identifier: "languagesTable")
        languageTableView = tv
        let addButton = makeIconButton(title: "+", action: #selector(addLanguage))
        addButton.isEnabled = !LanguageManager.shared.availableToAdd.isEmpty
        addLanguageButton = addButton
        return makeTablePane(scrollView: scrollView, addButton: addButton)
    }

    // MARK: - Cell Factory

    func makeLanguageRowView(for descriptor: LanguageDescriptor, row: Int) -> NSView {
        let label = NSTextField(labelWithString: descriptor.displayName)
        label.setContentHuggingPriority(.defaultLow, for: .horizontal)
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let removeButton = makeIconButton(title: "\u{2212}", action: #selector(removeLanguageClicked(_:)))
        removeButton.tag = row
        removeButton.isHidden = LanguageManager.shared.addedCodes.count <= 1

        let stack = NSStackView(views: [makeDragHandle(), label, removeButton])
        stack.spacing = Layout.buttonSpacing
        stack.distribution = .fill
        stack.edgeInsets = NSEdgeInsets(top: 0, left: Layout.buttonSpacing, bottom: 0, right: Layout.buttonSpacing)
        return stack
    }

    // MARK: - Actions

    @objc private func addLanguage() {
        let available = LanguageManager.shared.availableToAdd
        guard !available.isEmpty, let window else { return }

        let popup = NSPopUpButton(frame: NSRect(x: 0, y: 0, width: 280, height: 26), pullsDown: false)
        available.forEach { popup.addItem(withTitle: $0.displayName) }

        let alert = NSAlert()
        alert.messageText = "Add Language"
        alert.addButton(withTitle: "Add")
        alert.addButton(withTitle: "Cancel")
        alert.accessoryView = popup

        alert.beginSheetModal(for: window) { [weak self] response in
            guard response == .alertFirstButtonReturn, let self else { return }
            let index = popup.indexOfSelectedItem
            guard available.indices.contains(index) else { return }
            LanguageManager.shared.addLanguage(code: available[index].code)
            languageTableView?.reloadData()
        }
    }

    @objc private func removeLanguageClicked(_ sender: NSButton) {
        let index = sender.tag
        guard LanguageManager.shared.addedCodes.indices.contains(index) else { return }
        LanguageManager.shared.removeLanguage(at: index)
        languageTableView?.reloadData()
    }
}
