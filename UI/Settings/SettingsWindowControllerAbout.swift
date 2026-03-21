import AppKit

// MARK: - About Tab

extension SettingsWindowController {
    func makeAboutTab() -> NSView {
        let container = NSView()

        let stack = makeContentStack()

        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"

        let titleLabel = NSTextField(labelWithString: "Version:")
        titleLabel.font = .systemFont(ofSize: Layout.headerFontSize)

        let versionLabel = NSTextField(labelWithString: version)
        versionLabel.font = .monospacedSystemFont(ofSize: Layout.headerFontSize, weight: .regular)

        let row = NSStackView(views: [titleLabel, versionLabel])
        row.spacing = Layout.buttonSpacing
        row.alignment = .firstBaseline
        stack.addArrangedSubview(row)

        container.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: container.topAnchor, constant: Layout.edgeInset),
            stack.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -Layout.edgeInset),
        ])

        return container
    }
}
