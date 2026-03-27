import AppKit

// MARK: - General Tab

extension SettingsWindowController {
    func makeGeneralTab() -> NSView {
        let container = NSView()

        let stack = makeContentStack()
        stack.addArrangedSubview(makeNextWordPredictionsRow())
        stack.addArrangedSubview(makeAutoCapitalizationRow())

        container.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: container.topAnchor, constant: Layout.edgeInset),
            stack.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -Layout.edgeInset),
        ])

        return container
    }

    // MARK: - Row Builders

    private func makeNextWordPredictionsRow() -> NSView {
        let toggle = NSSwitch()
        toggle.target = self
        toggle.action = #selector(nextWordPredictionsToggleChanged(_:))
        toggle.state = SettingsManager.shared.isNextWordPredictionsEnabled ? .on : .off
        toggle.controlSize = .small
        toggle.translatesAutoresizingMaskIntoConstraints = false
        nextWordPredictionsToggle = toggle
        return makeSettingsRow(label: "Next Word Predictions (experimental)", control: toggle)
    }

    private func makeAutoCapitalizationRow() -> NSView {
        let toggle = NSSwitch()
        toggle.target = self
        toggle.action = #selector(autoCapitalizationToggleChanged(_:))
        toggle.state = SettingsManager.shared.isAutoCapitalizationEnabled ? .on : .off
        toggle.controlSize = .small
        toggle.translatesAutoresizingMaskIntoConstraints = false
        autoCapitalizationToggle = toggle
        return makeSettingsRow(label: "Auto Capitalization", control: toggle)
    }

    // MARK: - Actions

    @objc private func nextWordPredictionsToggleChanged(_ sender: NSSwitch) {
        SettingsManager.shared.setNextWordPredictionsEnabled(sender.state == .on)
    }

    @objc private func autoCapitalizationToggleChanged(_ sender: NSSwitch) {
        SettingsManager.shared.setAutoCapitalizationEnabled(sender.state == .on)
    }

    // MARK: - Sync

    func syncGeneralControls() {
        nextWordPredictionsToggle?.state = SettingsManager.shared.isNextWordPredictionsEnabled ? .on : .off
        autoCapitalizationToggle?.state = SettingsManager.shared.isAutoCapitalizationEnabled ? .on : .off
    }
}
