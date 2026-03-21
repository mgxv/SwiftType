import AppKit

// MARK: - Customization Tab

extension SettingsWindowController {
    func makeCustomizationTab() -> NSView {
        let container = NSView()

        let stack = makeContentStack()

        for key in ThemeColorKey.allCases {
            stack.addArrangedSubview(makeColorRow(for: key))
        }
        stack.addArrangedSubview(makeHighlightOpacityRow())
        stack.addArrangedSubview(makeCandidateCountRow())
        stack.addArrangedSubview(makeGridRowsRow())

        container.addSubview(stack)

        let resetButton = NSButton(title: "Reset to Defaults", target: self, action: #selector(resetColorsToDefaults))
        resetButton.bezelStyle = .push
        resetButton.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(resetButton)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: container.topAnchor, constant: Layout.edgeInset),
            stack.centerXAnchor.constraint(equalTo: container.centerXAnchor),

            resetButton.topAnchor.constraint(equalTo: stack.bottomAnchor, constant: Layout.edgeInset),
            resetButton.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            resetButton.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -Layout.edgeInset),
        ])

        return container
    }

    // MARK: - Row Builders

    private func makeColorRow(for key: ThemeColorKey) -> NSView {
        let hex = ThemeManager.shared.hexString(for: key)
        let color = NSColor(hexString: hex) ?? NSColor(hexString: key.defaultHex)!
        let well = makeColorWell(color: color, action: #selector(colorWellChanged(_:)))
        well.identifier = NSUserInterfaceItemIdentifier(key.rawValue)
        colorWells[key] = well
        return makeSettingsRow(label: key.displayName, control: well)
    }

    private func makeHighlightOpacityRow() -> NSView {
        let initialValue = ThemeManager.shared.highlightOpacity

        highlightOpacitySlider = NSSlider(value: Double(initialValue),
                                          minValue: 0.0,
                                          maxValue: 1.0,
                                          target: self,
                                          action: #selector(highlightOpacityChanged(_:)))
        highlightOpacitySlider.translatesAutoresizingMaskIntoConstraints = false
        highlightOpacitySlider.widthAnchor.constraint(equalToConstant: Layout.sliderWidth).isActive = true

        highlightOpacityLabel = NSTextField(labelWithString: formatOpacity(initialValue))
        highlightOpacityLabel.font = .monospacedSystemFont(ofSize: Layout.headerFontSize, weight: .regular)
        highlightOpacityLabel.translatesAutoresizingMaskIntoConstraints = false
        highlightOpacityLabel.widthAnchor.constraint(equalToConstant: Layout.sliderLabelWidth).isActive = true

        let sliderRow = NSStackView(views: [highlightOpacitySlider, highlightOpacityLabel])
        sliderRow.spacing = 4

        return makeSettingsRow(label: "Highlight Opacity", control: sliderRow)
    }

    private func makeCandidateCountRow() -> NSView {
        let index = ThemeManager.gridColsOptions.firstIndex(of: ThemeManager.shared.gridCols) ?? 2
        candidateCountPopUp = makePopUp(items: ThemeManager.gridColsOptions.map(String.init), selectedIndex: index, action: #selector(candidateCountChanged(_:)))
        return makeSettingsRow(label: "Candidate Columns", control: candidateCountPopUp)
    }

    private func makeGridRowsRow() -> NSView {
        let index = ThemeManager.gridRowsOptions.firstIndex(of: ThemeManager.shared.gridRows) ?? 0
        gridRowsPopUp = makePopUp(items: ThemeManager.gridRowsOptions.map(String.init), selectedIndex: index, action: #selector(gridRowsChanged(_:)))
        return makeSettingsRow(label: "Candidate Rows", control: gridRowsPopUp)
    }

    // MARK: - Actions

    @objc private func colorWellChanged(_ sender: NSColorWell) {
        guard let key = ThemeColorKey(rawValue: sender.identifier?.rawValue ?? "") else { return }
        ThemeManager.shared.setColor(sender.color.hexString, for: key)
    }

    @objc private func highlightOpacityChanged(_ sender: NSSlider) {
        let value = CGFloat(sender.doubleValue)
        ThemeManager.shared.setHighlightOpacity(value)
        highlightOpacityLabel?.stringValue = formatOpacity(value)
    }

    @objc private func candidateCountChanged(_ sender: NSPopUpButton) {
        let options = ThemeManager.gridColsOptions
        guard sender.indexOfSelectedItem < options.count else { return }
        ThemeManager.shared.setGridCols(options[sender.indexOfSelectedItem])
    }

    @objc private func gridRowsChanged(_ sender: NSPopUpButton) {
        let options = ThemeManager.gridRowsOptions
        guard sender.indexOfSelectedItem < options.count else { return }
        ThemeManager.shared.setGridRows(options[sender.indexOfSelectedItem])
    }

    @objc private func resetColorsToDefaults() {
        ThemeManager.shared.resetToDefaults()
        syncCustomizationControls()
    }

    // MARK: - Sync

    func syncCustomizationControls() {
        for key in ThemeColorKey.allCases {
            let hex = ThemeManager.shared.hexString(for: key)
            colorWells[key]?.color = NSColor(hexString: hex) ?? NSColor(hexString: key.defaultHex)!
        }

        let opacity = ThemeManager.shared.highlightOpacity
        highlightOpacitySlider?.doubleValue = Double(opacity)
        highlightOpacityLabel?.stringValue = formatOpacity(opacity)

        let countIndex = ThemeManager.gridColsOptions.firstIndex(of: ThemeManager.shared.gridCols) ?? 2
        candidateCountPopUp?.selectItem(at: countIndex)

        let rowsIndex = ThemeManager.gridRowsOptions.firstIndex(of: ThemeManager.shared.gridRows) ?? 0
        gridRowsPopUp?.selectItem(at: rowsIndex)
    }

    private func formatOpacity(_ value: CGFloat) -> String {
        "\(Int(round(value * 100)))%"
    }
}
