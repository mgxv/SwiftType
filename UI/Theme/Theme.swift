import AppKit

@MainActor struct ThemeBorder {
    nonisolated static let standardWidth: CGFloat = 2

    let color: NSColor
    let width: CGFloat
}

@MainActor struct Theme {
    let backgroundColor: NSColor
    let border: ThemeBorder
    let cornerRadius: CGFloat
    let highlightTextColor: NSColor
    let highlightColor: NSColor
    let normalTextColor: NSColor
    let numberLabelColor: NSColor
    let separatorColor: NSColor
    let fontWeight: NSFont.Weight
    let numberFontWeight: NSFont.Weight
    let wordFontSize: CGFloat
    let numberFontSize: CGFloat

    init(
        backgroundColor: NSColor,
        border: ThemeBorder,
        cornerRadius: CGFloat,
        highlightTextColor: NSColor,
        highlightColor: NSColor,
        normalTextColor: NSColor,
        numberLabelColor: NSColor,
        separatorColor: NSColor,
        fontWeight: NSFont.Weight,
        numberFontWeight: NSFont.Weight,
        wordFontSize: CGFloat = 14,
        numberFontSize: CGFloat = 11,
    ) {
        self.backgroundColor = backgroundColor
        self.border = border
        self.cornerRadius = cornerRadius
        self.highlightTextColor = highlightTextColor
        self.highlightColor = highlightColor
        self.normalTextColor = normalTextColor
        self.numberLabelColor = numberLabelColor
        self.separatorColor = separatorColor
        self.fontWeight = fontWeight
        self.numberFontWeight = numberFontWeight
        self.wordFontSize = wordFontSize
        self.numberFontSize = numberFontSize
    }

    /// Builds the default theme from `ThemeColorKey.defaultHex` — the single source of truth
    /// for all default colour values. No hex literals are duplicated here.
    static let defaultTheme: Theme = {
        func color(_ key: ThemeColorKey) -> NSColor {
            NSColor(hexString: key.defaultHex)!
        }
        return Theme(
            backgroundColor: color(.backgroundColor),
            border: ThemeBorder(color: color(.borderColor), width: ThemeBorder.standardWidth),
            cornerRadius: 6,
            highlightTextColor: color(.highlightTextColor),
            highlightColor: color(.highlightColor),
            normalTextColor: color(.normalTextColor),
            numberLabelColor: color(.numberLabelColor),
            separatorColor: color(.separatorColor),
            fontWeight: .medium,
            numberFontWeight: .medium,
        )
    }()
}
