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

        let uninstallButton = NSButton(title: "Uninstall SwiftType\u{2026}", target: self, action: #selector(uninstallButtonClicked))
        uninstallButton.bezelStyle = .push
        uninstallButton.contentTintColor = .systemRed
        uninstallButton.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(uninstallButton)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: container.topAnchor, constant: Layout.edgeInset),
            stack.centerXAnchor.constraint(equalTo: container.centerXAnchor),

            uninstallButton.topAnchor.constraint(equalTo: stack.bottomAnchor, constant: Layout.edgeInset),
            uninstallButton.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            uninstallButton.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -Layout.edgeInset),
        ])

        return container
    }

    // MARK: - Uninstall

    @objc private func uninstallButtonClicked() {
        guard let window else { return }

        let alert = NSAlert()
        alert.alertStyle = .critical
        alert.messageText = "Uninstall SwiftType?"
        alert.informativeText = "This will remove SwiftType from Input Methods and the Applications folder. You may need to log out for the change to take full effect."

        let uninstallButton = alert.addButton(withTitle: "Uninstall")
        uninstallButton.hasDestructiveAction = true
        alert.addButton(withTitle: "Cancel")

        alert.beginSheetModal(for: window) { [weak self] response in
            guard response == .alertFirstButtonReturn else { return }
            self?.performUninstall()
        }
    }

    private func performUninstall() {
        let appBundle = URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent("Library/Input Methods/SwiftType.app")
        let applicationsSymlink = URL(fileURLWithPath: "/Applications/SwiftType.app")

        removeItem(at: appBundle, label: "app bundle")

        if (try? FileManager.default.destinationOfSymbolicLink(atPath: applicationsSymlink.path)) != nil {
            removeItem(at: applicationsSymlink, label: "symlink")
        }

        Log.settingsManager.info("Uninstall complete; terminating")
        NSApp.terminate(nil)
    }

    private func removeItem(at url: URL, label: String) {
        do {
            try FileManager.default.removeItem(at: url)
            Log.settingsManager.info("Removed \(label, privacy: .public): \(url.path, privacy: .public)")
        } catch {
            Log.settingsManager.error("Failed to remove \(label, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }
    }
}
