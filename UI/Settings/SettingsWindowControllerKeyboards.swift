import AppKit
import UniformTypeIdentifiers

// MARK: - Keyboards Tab

extension SettingsWindowController {
    func makeKeyboardsTab() -> NSView {
        let (scrollView, tv) = makeTableScrollView(identifier: "keyboardsTable")
        tableView = tv
        let addButton = makeIconButton(title: "+", action: #selector(addMapping))
        return makeTablePane(scrollView: scrollView, addButton: addButton)
    }

    // MARK: - Cell Factory

    func makeMappingRowView(for mapping: AppInputSourceMapping, row: Int) -> NSView {
        let appLabel = makeAppLabel(for: mapping)
        appLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        appLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let sourcePopUp = makeInputSourceCell(for: mapping, row: row)

        let enabledCheckbox = NSButton(checkboxWithTitle: "", target: self,
                                       action: #selector(enabledCheckboxChanged(_:)))
        enabledCheckbox.state = mapping.isEnabled ? .on : .off
        enabledCheckbox.tag = row
        enabledCheckbox.toolTip = "Enable or disable this mapping"

        // Dim the row controls when the mapping is disabled so the state is visible at a glance.
        let alpha: CGFloat = mapping.isEnabled ? 1.0 : 0.4
        appLabel.alphaValue = alpha
        sourcePopUp.alphaValue = alpha

        let removeButton = makeIconButton(title: "\u{2212}", action: #selector(removeMappingClicked(_:)))
        removeButton.tag = row

        let stack = NSStackView(views: [makeDragHandle(), appLabel, sourcePopUp,
                                        enabledCheckbox, removeButton])
        stack.spacing = Layout.buttonSpacing
        stack.distribution = .fill
        stack.edgeInsets = NSEdgeInsets(top: 0, left: Layout.buttonSpacing, bottom: 0, right: Layout.buttonSpacing)
        // Pin source popup to the same width as the app label so both columns are equal.
        sourcePopUp.widthAnchor.constraint(equalTo: appLabel.widthAnchor).isActive = true
        return stack
    }

    private func makeAppLabel(for mapping: AppInputSourceMapping) -> NSView {
        var arrangedViews: [NSView] = []

        if !mapping.bundleId.isEmpty,
           let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: mapping.bundleId)
        {
            let icon = NSWorkspace.shared.icon(forFile: url.path)
            icon.size = NSSize(width: Layout.appIconSize, height: Layout.appIconSize)
            let imageView = NSImageView(image: icon)
            imageView.translatesAutoresizingMaskIntoConstraints = false
            imageView.widthAnchor.constraint(equalToConstant: Layout.appIconSize).isActive = true
            imageView.heightAnchor.constraint(equalToConstant: Layout.appIconSize).isActive = true
            arrangedViews.append(imageView)
        }

        let label = NSTextField(labelWithString: displayName(for: mapping.bundleId))
        label.lineBreakMode = .byTruncatingTail
        arrangedViews.append(label)

        let stack = NSStackView(views: arrangedViews)
        stack.spacing = 4
        return stack
    }

    private func makeInputSourceCell(for mapping: AppInputSourceMapping, row: Int) -> NSPopUpButton {
        let popUp = NSPopUpButton(frame: .zero, pullsDown: false)
        for source in cachedInputSources {
            popUp.addItem(withTitle: source.localizedName)
            popUp.lastItem?.representedObject = source.id
        }
        let matchIndex = cachedInputSources.firstIndex(where: { $0.id == mapping.inputSourceId }) ?? 0
        popUp.selectItem(at: matchIndex)
        popUp.tag = row
        popUp.target = self
        popUp.action = #selector(sourcePopUpChanged(_:))
        return popUp
    }

    // MARK: - Actions

    @objc private func addMapping() {
        showAppChooserPanel { [weak self] bundleId in
            guard let self else { return }
            let defaultSourceId = cachedInputSources.first?.id ?? ""
            SettingsManager.shared.addMapping(AppInputSourceMapping(bundleId: bundleId, inputSourceId: defaultSourceId))
            reloadTable()
        }
    }

    @objc private func removeMappingClicked(_ sender: NSButton) {
        SettingsManager.shared.removeMapping(at: sender.tag)
        reloadTable()
    }

    @objc private func sourcePopUpChanged(_ sender: NSPopUpButton) {
        guard let sourceId = sender.selectedItem?.representedObject as? String else { return }
        SettingsManager.shared.updateMapping(at: sender.tag, inputSourceId: sourceId)
    }

    @objc private func enabledCheckboxChanged(_ sender: NSButton) {
        SettingsManager.shared.updateMapping(at: sender.tag, isEnabled: sender.state == .on)
        reloadTable()
    }

    private func showAppChooserPanel(completion: @escaping (String) -> Void) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.applicationBundle]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")

        panel.begin { response in
            guard response == .OK,
                  let url = panel.url,
                  let bundle = Bundle(url: url),
                  let bundleId = bundle.bundleIdentifier else { return }
            completion(bundleId)
        }
    }
}
