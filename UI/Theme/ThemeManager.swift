import AppKit
import Foundation

// MARK: - Theme Color Key

enum ThemeColorKey: String, CaseIterable, Sendable {
    case backgroundColor = "theme.backgroundColor"
    case borderColor = "theme.borderColor"
    case separatorColor = "theme.separatorColor"
    case normalTextColor = "theme.normalTextColor"
    case numberLabelColor = "theme.numberLabelColor"
    case highlightTextColor = "theme.highlightTextColor"
    case highlightColor = "theme.highlightColor"

    var displayName: String {
        switch self {
        case .backgroundColor: "Background Color"
        case .borderColor: "Border Color"
        case .separatorColor: "Separator Color"
        case .normalTextColor: "Text Color"
        case .numberLabelColor: "Number Label Color"
        case .highlightTextColor: "Selected Word Color"
        case .highlightColor: "Highlight Color"
        }
    }

    var defaultHex: String {
        switch self {
        case .backgroundColor: "#1B1B1B"
        case .borderColor: "#1B1B1B"
        case .separatorColor: "#777E7C"
        case .normalTextColor: "#FCFCFC"
        case .numberLabelColor: "#A0796A"
        case .highlightTextColor: "#FF9900"
        case .highlightColor: "#533566"
        }
    }
}

// MARK: - Theme Manager

@MainActor final class ThemeManager {
    static let shared = ThemeManager()

    static let defaultHighlightOpacity: CGFloat = 0
    static let defaultGridCols = 5
    static let gridColsOptions = [4, 5, 6]
    static let defaultGridRows = 4
    static let gridRowsOptions = [3, 4, 5]

    private enum Keys {
        static let highlightOpacity = "theme.highlightTransparency" // key string preserved for backwards compat
        static let gridCols = "theme.maxCandidates"
        static let gridRows = "theme.gridRows"
    }

    private let defaults: UserDefaults

    /// Cached theme — rebuilt only when settings change.
    private(set) var current: Theme
    /// Cached highlight opacity — read separately from theme since it's applied as alpha.
    private(set) var highlightOpacity: CGFloat

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        highlightOpacity = Self.readHighlightOpacity(from: defaults)
        current = Self.buildTheme(from: defaults)
    }

    // MARK: - Highlight Opacity

    func setHighlightOpacity(_ value: CGFloat) {
        setDefault(Float(value), forKey: Keys.highlightOpacity)
    }

    // MARK: - Theme Colors

    func setColor(_ hex: String, for key: ThemeColorKey) {
        guard NSColor(hexString: hex) != nil else { return }
        setDefault(hex, forKey: key.rawValue)
    }

    func hexString(for key: ThemeColorKey) -> String {
        defaults.string(forKey: key.rawValue) ?? key.defaultHex
    }

    // MARK: - Candidate Columns

    var gridCols: Int {
        let value = defaults.integer(forKey: Keys.gridCols)
        return Self.gridColsOptions.contains(value) ? value : Self.defaultGridCols
    }

    func setGridCols(_ count: Int) {
        setDefault(count, forKey: Keys.gridCols)
    }

    // MARK: - Candidate Rows

    var gridRows: Int {
        let value = defaults.integer(forKey: Keys.gridRows)
        return Self.gridRowsOptions.contains(value) ? value : Self.defaultGridRows
    }

    func setGridRows(_ count: Int) {
        guard Self.gridRowsOptions.contains(count) else { return }
        setDefault(count, forKey: Keys.gridRows)
    }

    // MARK: - Reset

    func resetToDefaults() {
        let allKeys = ThemeColorKey.allCases.map(\.rawValue) + [
            Keys.highlightOpacity,
            Keys.gridCols,
            Keys.gridRows,
        ]
        for key in allKeys {
            defaults.removeObject(forKey: key)
        }
        rebuildCache()
        notifyThemeChange()
    }

    // MARK: - Private

    private func setDefault(_ value: some Any, forKey key: String) {
        defaults.set(value, forKey: key)
        rebuildCache()
        notifyThemeChange()
    }

    private func rebuildCache() {
        current = Self.buildTheme(from: defaults)
        highlightOpacity = Self.readHighlightOpacity(from: defaults)
    }

    private func notifyThemeChange() {
        NotificationCenter.default.post(name: .themeDidChange, object: nil)
    }

    private static func readHighlightOpacity(from defaults: UserDefaults) -> CGFloat {
        if let value = defaults.object(forKey: Keys.highlightOpacity) as? Float {
            return CGFloat(value)
        }
        return defaultHighlightOpacity
    }

    private static func buildTheme(from defaults: UserDefaults) -> Theme {
        let base = Theme.defaultTheme

        func color(for key: ThemeColorKey) -> NSColor {
            let hex = defaults.string(forKey: key.rawValue) ?? key.defaultHex
            return NSColor(hexString: hex) ?? NSColor(hexString: key.defaultHex)!
        }

        return Theme(
            backgroundColor: color(for: .backgroundColor),
            border: ThemeBorder(color: color(for: .borderColor), width: ThemeBorder.standardWidth),
            cornerRadius: base.cornerRadius,
            highlightTextColor: color(for: .highlightTextColor),
            highlightColor: color(for: .highlightColor),
            normalTextColor: color(for: .normalTextColor),
            numberLabelColor: color(for: .numberLabelColor),
            separatorColor: color(for: .separatorColor),
            fontWeight: base.fontWeight,
            numberFontWeight: base.numberFontWeight,
        )
    }
}
