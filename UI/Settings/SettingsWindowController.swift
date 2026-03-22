import AppKit
import UniformTypeIdentifiers

// MARK: - SettingsWindowController

//
// Coordinator for the five-tab Settings window. Each tab's UI-building code,
// action handlers, and table-view data live in a companion extension file:
//
//   SettingsWindowController+General.swift       — General tab
//   SettingsWindowController+Keyboards.swift     — Keyboards tab
//   SettingsWindowController+Languages.swift     — Languages tab
//   SettingsWindowController+Customization.swift — Customization tab
//   SettingsWindowController+About.swift         — About tab
//
// Shared UI helpers (makeIconButton, makeDragHandle, …) and the unified
// NSTableViewDataSource/Delegate dispatch live here so every extension can
// call them without needing cross-file access.

@MainActor final class SettingsWindowController: NSWindowController, NSWindowDelegate, NSToolbarDelegate, NSTableViewDataSource, NSTableViewDelegate {
    static let shared = SettingsWindowController()

    // MARK: - Toolbar Tab Definition

    enum Tab: String, CaseIterable {
        case general
        case keyboards
        case languages
        case customization
        case about

        var title: String {
            switch self {
            case .general: "General"
            case .keyboards: "Keyboards"
            case .languages: "Languages"
            case .customization: "Customization"
            case .about: "About"
            }
        }

        var icon: String {
            switch self {
            case .general: "gearshape"
            case .keyboards: "keyboard"
            case .languages: "character.book.closed"
            case .customization: "paintbrush"
            case .about: "info.circle"
            }
        }

        var toolbarIdentifier: NSToolbarItem.Identifier {
            NSToolbarItem.Identifier(rawValue)
        }
    }

    // MARK: - UI References

    // Internal so extension files in separate source files can access them.

    var tableView: NSTableView!
    var colorWells: [ThemeColorKey: NSColorWell] = [:]
    var highlightOpacitySlider: NSSlider!
    var highlightOpacityLabel: NSTextField!
    var candidateCountPopUp: NSPopUpButton!
    var gridRowsPopUp: NSPopUpButton!

    var generalPane: NSView?
    var keyboardsPane: NSView?
    var customizationPane: NSView?
    var aboutPane: NSView?

    var nextWordPredictionsToggle: NSSwitch?

    var languagesPane: NSView?
    var languageTableView: NSTableView?
    var addLanguageButton: NSButton?

    // MARK: - Cached Data

    var cachedInputSources: [InputSourceInfo] = []

    // MARK: - Layout Constants

    // Internal so extension files can reference the same constants.

    enum Layout {
        static let windowWidth: CGFloat = 550
        static let generalPaneHeight: CGFloat = 400
        static let edgeInset: CGFloat = 16
        static let buttonSpacing: CGFloat = 8
        static let buttonSize: CGFloat = 24
        static let colorWellSize: CGFloat = 30
        static let popUpWidth: CGFloat = 160
        static let sliderWidth: CGFloat = 120
        static let sliderLabelWidth: CGFloat = 36
        static let rowLabelWidth: CGFloat = 170
        static let headerFontSize: CGFloat = 13
        static let rowHeight: CGFloat = 30
        static let rowSpacing: CGFloat = 14
        static let appIconSize: CGFloat = 16
    }

    // MARK: - Initialization

    private convenience init() {
        let window = Self.makeWindow()
        self.init(window: window)
        window.delegate = self
        setupToolbar()
        selectTab(.general, animate: false)
        observeNotifications()
    }

    func showWindow() {
        reloadTable()
        if generalPane != nil { syncGeneralControls() }
        if customizationPane != nil { syncCustomizationControls() }
        NSApp.setActivationPolicy(.regular)
        window?.collectionBehavior = .canJoinAllSpaces
        window?.center()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        window?.collectionBehavior = []
    }

    // MARK: - Window Setup

    private static func makeWindow() -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: Layout.windowWidth, height: Layout.generalPaneHeight),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false,
        )
        window.title = "SwiftType"
        window.toolbarStyle = .preference
        window.center()
        window.isReleasedWhenClosed = false
        return window
    }

    // MARK: - Toolbar

    private func setupToolbar() {
        let toolbar = NSToolbar(identifier: "SettingsToolbar")
        toolbar.delegate = self
        toolbar.displayMode = .iconAndLabel
        toolbar.selectedItemIdentifier = Tab.general.toolbarIdentifier
        window?.toolbar = toolbar
    }

    func toolbarAllowedItemIdentifiers(_: NSToolbar) -> [NSToolbarItem.Identifier] {
        Tab.allCases.map(\.toolbarIdentifier)
    }

    func toolbarDefaultItemIdentifiers(_: NSToolbar) -> [NSToolbarItem.Identifier] {
        Tab.allCases.map(\.toolbarIdentifier)
    }

    func toolbarSelectableItemIdentifiers(_: NSToolbar) -> [NSToolbarItem.Identifier] {
        Tab.allCases.map(\.toolbarIdentifier)
    }

    func toolbar(_: NSToolbar, itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier, willBeInsertedIntoToolbar _: Bool) -> NSToolbarItem? {
        guard let tab = Tab(rawValue: itemIdentifier.rawValue) else { return nil }
        let item = NSToolbarItem(itemIdentifier: itemIdentifier)
        item.label = tab.title
        item.image = NSImage(systemSymbolName: tab.icon, accessibilityDescription: tab.title)
        item.target = self
        item.action = #selector(toolbarItemClicked(_:))
        return item
    }

    @objc private func toolbarItemClicked(_ sender: NSToolbarItem) {
        guard let tab = Tab(rawValue: sender.itemIdentifier.rawValue) else { return }
        selectTab(tab)
    }

    func selectTab(_ tab: Tab, animate: Bool = true) {
        window?.toolbar?.selectedItemIdentifier = tab.toolbarIdentifier

        let paneView: NSView
        let paneHeight: CGFloat
        switch tab {
        case .general:
            if generalPane == nil { generalPane = makeGeneralTab() }
            paneView = generalPane!
            paneView.layoutSubtreeIfNeeded()
            paneHeight = paneView.fittingSize.height
        case .keyboards:
            if keyboardsPane == nil { keyboardsPane = makeKeyboardsTab() }
            paneView = keyboardsPane!
            paneHeight = Layout.generalPaneHeight
        case .languages:
            if languagesPane == nil { languagesPane = makeLanguagesTab() }
            paneView = languagesPane!
            paneHeight = Layout.generalPaneHeight
        case .customization:
            if customizationPane == nil { customizationPane = makeCustomizationTab() }
            paneView = customizationPane!
            paneView.layoutSubtreeIfNeeded()
            paneHeight = paneView.fittingSize.height
        case .about:
            if aboutPane == nil { aboutPane = makeAboutTab() }
            paneView = aboutPane!
            paneView.layoutSubtreeIfNeeded()
            paneHeight = paneView.fittingSize.height
        }

        window?.contentView = paneView

        guard let window else { return }
        let newFrameSize = window.frameRect(forContentRect: NSRect(x: 0, y: 0, width: Layout.windowWidth, height: paneHeight)).size
        var frame = window.frame
        let yDelta = frame.size.height - newFrameSize.height
        frame.origin.y += yDelta
        frame.size = newFrameSize
        window.setFrame(frame, display: true, animate: animate)
    }

    // MARK: - Notification Observers

    private func observeNotifications() {
        NotificationCenter.default.addObserver(
            self, selector: #selector(mappingsDidChange),
            name: .appMappingsDidChange, object: nil,
        )
        NotificationCenter.default.addObserver(
            self, selector: #selector(languagesDidChange),
            name: .languagesDidChange, object: nil,
        )
    }

    @objc private func mappingsDidChange() {
        guard window?.isVisible == true else { return }
        reloadTable()
    }

    @objc private func languagesDidChange() {
        guard window?.isVisible == true else { return }
        languageTableView?.reloadData()
        addLanguageButton?.isEnabled = !LanguageManager.shared.availableToAdd.isEmpty
    }

    // MARK: - NSWindowDelegate

    func windowWillClose(_: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }

    // MARK: - Keyboards Data

    func reloadTable() {
        cachedInputSources = InputSourceSwitcher.shared?.availableInputSources() ?? []
        tableView?.reloadData()
    }

    func displayName(for bundleId: String) -> String {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) else {
            return bundleId
        }
        return FileManager.default.displayName(atPath: url.path)
            .replacingOccurrences(of: ".app", with: "")
    }

    // MARK: - NSTableViewDataSource

    // Unified dispatch: each pane's table registers a unique identifier string so a
    // single data-source/delegate implementation can serve all three table views.

    func numberOfRows(in tableView: NSTableView) -> Int {
        switch tableView.identifier?.rawValue {
        case "languagesTable": LanguageManager.shared.addedCodes.count
        default: SettingsManager.shared.mappings.count
        }
    }

    // MARK: - NSTableViewDelegate

    func tableView(_ tableView: NSTableView, viewFor _: NSTableColumn?, row: Int) -> NSView? {
        switch tableView.identifier?.rawValue {
        case "languagesTable":
            let descriptors = LanguageManager.shared.addedDescriptors
            guard row < descriptors.count else { return nil }
            return makeLanguageRowView(for: descriptors[row], row: row)
        default:
            let mapping = SettingsManager.shared.mappings[row]
            return makeMappingRowView(for: mapping, row: row)
        }
    }

    func tableView(_: NSTableView, pasteboardWriterForRow row: Int) -> NSPasteboardWriting? {
        let item = NSPasteboardItem()
        item.setString("\(row)", forType: .string)
        return item
    }

    func tableView(_: NSTableView, validateDrop _: NSDraggingInfo, proposedRow _: Int, proposedDropOperation dropOperation: NSTableView.DropOperation) -> NSDragOperation {
        dropOperation == .above ? .move : []
    }

    func tableView(_ tableView: NSTableView, acceptDrop info: NSDraggingInfo, row: Int, dropOperation _: NSTableView.DropOperation) -> Bool {
        guard let str = info.draggingPasteboard.string(forType: .string),
              let fromRow = Int(str) else { return false }
        let toRow = fromRow < row ? row - 1 : row
        guard fromRow != toRow else { return false }
        switch tableView.identifier?.rawValue {
        case "languagesTable":
            LanguageManager.shared.moveLanguage(from: fromRow, to: toRow)
        default:
            SettingsManager.shared.moveMapping(from: fromRow, to: toRow)
        }
        tableView.moveRow(at: fromRow, to: toRow)
        return true
    }

    // MARK: - Shared UI Helpers

    // Used by multiple pane extensions.

    /// Creates a fully configured table + scroll view pair. Both table-based panes
    /// (Keyboards, Languages) use identical NSTableView settings;
    /// the only difference is the identifier used for delegate dispatch.
    func makeTableScrollView(identifier: String) -> (scrollView: NSScrollView, tableView: NSTableView) {
        let tv = NSTableView()
        tv.identifier = NSUserInterfaceItemIdentifier(identifier)
        tv.style = .plain
        tv.rowHeight = Layout.rowHeight
        tv.headerView = nil
        tv.dataSource = self
        tv.delegate = self
        tv.gridStyleMask = []
        tv.intercellSpacing = NSSize(width: 0, height: 4)

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("row"))
        column.resizingMask = .autoresizingMask
        tv.addTableColumn(column)
        tv.columnAutoresizingStyle = .uniformColumnAutoresizingStyle
        tv.registerForDraggedTypes([.string])
        tv.setDraggingSourceOperationMask(.move, forLocal: true)

        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.documentView = tv
        scrollView.hasVerticalScroller = false
        scrollView.borderType = .bezelBorder
        scrollView.drawsBackground = false

        return (scrollView, tv)
    }

    /// Assembles the standard table-pane layout: scroll view pinned to three edges,
    /// add button centred at the bottom. Used by the Keyboards and Languages tabs.
    func makeTablePane(scrollView: NSScrollView, addButton: NSButton) -> NSView {
        let container = NSView()
        container.addSubview(scrollView)
        container.addSubview(addButton)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: container.topAnchor, constant: Layout.edgeInset),
            scrollView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: Layout.edgeInset),
            scrollView.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -Layout.edgeInset),
            scrollView.bottomAnchor.constraint(equalTo: addButton.topAnchor, constant: -Layout.buttonSpacing),

            addButton.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            addButton.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -Layout.edgeInset),
        ])
        return container
    }

    /// Returns a pre-configured vertical leading-aligned NSStackView used as the
    /// root content stack for the Customization and About panes.
    func makeContentStack() -> NSStackView {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = Layout.rowSpacing
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }

    func makeIconButton(title: String, action: Selector) -> NSButton {
        let button = NSButton(title: title, target: self, action: action)
        button.bezelStyle = .circular
        button.translatesAutoresizingMaskIntoConstraints = false
        button.widthAnchor.constraint(equalToConstant: Layout.buttonSize).isActive = true
        button.heightAnchor.constraint(equalToConstant: Layout.buttonSize).isActive = true
        return button
    }

    func makeDragHandle() -> NSImageView {
        let imageView = NSImageView()
        let config = NSImage.SymbolConfiguration(pointSize: 11, weight: .regular)
        imageView.image = NSImage(systemSymbolName: "line.3.horizontal", accessibilityDescription: "Drag to reorder")?
            .withSymbolConfiguration(config)
        imageView.contentTintColor = .tertiaryLabelColor
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.widthAnchor.constraint(equalToConstant: Layout.buttonSize).isActive = true
        return imageView
    }

    func makeRowLabel(_ title: String) -> NSTextField {
        let label = NSTextField(labelWithString: title + ":")
        label.font = .systemFont(ofSize: Layout.headerFontSize)
        label.alignment = .right
        label.translatesAutoresizingMaskIntoConstraints = false
        label.widthAnchor.constraint(greaterThanOrEqualToConstant: Layout.rowLabelWidth).isActive = true
        return label
    }

    func makeColorWell(color: NSColor, action: Selector) -> NSColorWell {
        let well = NSColorWell(frame: NSRect(x: 0, y: 0, width: Layout.colorWellSize, height: Layout.colorWellSize))
        well.color = color
        well.translatesAutoresizingMaskIntoConstraints = false
        well.widthAnchor.constraint(equalToConstant: Layout.colorWellSize).isActive = true
        well.heightAnchor.constraint(equalToConstant: Layout.colorWellSize).isActive = true
        well.target = self
        well.action = action
        return well
    }

    func makePopUp(items: [String], selectedIndex: Int, action: Selector) -> NSPopUpButton {
        let popUp = NSPopUpButton(frame: .zero, pullsDown: false)
        items.forEach { popUp.addItem(withTitle: $0) }
        popUp.selectItem(at: selectedIndex)
        popUp.target = self
        popUp.action = action
        popUp.translatesAutoresizingMaskIntoConstraints = false
        popUp.widthAnchor.constraint(equalToConstant: Layout.popUpWidth).isActive = true
        return popUp
    }

    func makeSettingsRow(label title: String, control: NSView) -> NSView {
        let row = NSStackView(views: [makeRowLabel(title), control])
        row.alignment = .centerY
        row.spacing = Layout.buttonSpacing
        return row
    }
}
