import AppKit

// MARK: - Highlight Container

@MainActor private final class HighlightContainerView: NSView {
    let label: NSTextField

    var isHighlighted: Bool = false {
        didSet { updateLayerBackground() }
    }

    /// Stored without a `didSet` observer; always set before `isHighlighted`
    /// inside `apply(highlighted:color:radius:)` so the single `didSet` on
    /// `isHighlighted` sees the already-updated color value.
    var highlightColor: NSColor = .clear

    init(label: NSTextField) {
        self.label = label
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true
        layer?.masksToBounds = true
        addSubview(label)
        label.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
            label.topAnchor.constraint(equalTo: topAnchor, constant: 4),
            label.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4),
        ])
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Updates the cell's highlight color, pill radius, and highlighted state in
    /// a single pass. Sets `highlightColor` and `cornerRadius` first so that the
    /// `isHighlighted` `didSet` observer calls `updateLayerBackground()` exactly
    /// once with all values already current.
    func apply(highlighted: Bool, color: NSColor, radius: CGFloat) {
        highlightColor = color
        layer?.cornerRadius = radius
        isHighlighted = highlighted
    }

    private func updateLayerBackground() {
        layer?.backgroundColor = isHighlighted && highlightColor.alphaComponent > 0
            ? highlightColor.cgColor
            : nil
    }
}

// MARK: - Candidate View

/// Renders the candidate grid: up to `gridMaxVisibleRows` horizontal rows,
/// each containing up to `maxSupportedGridCols` cells.
///
/// All cells are pre-allocated in `setupView()` and shown/hidden on each `updateGrid` call —
/// no subview additions or removals occur at runtime.
@MainActor final class CandidateView: NSView {
    // MARK: - Grid

    private let gridView: NSGridView

    /// `cells[r][c]` is the HighlightContainerView for row r, column c.
    private var cells: [[HighlightContainerView]] = []

    /// Thin divider lines between adjacent rows; `separators[i]` sits between row i and row i+1.
    private var separators: [NSView] = []

    // MARK: - Cached theme values — rebuilt only on theme change

    private var wordFont = NSFont.systemFont(ofSize: 14, weight: .medium)
    private var numberFont = NSFont.monospacedSystemFont(ofSize: 11, weight: .medium)
    private var baselineOffset: CGFloat = 1.0
    private var pillColor = NSColor.clear
    private var pillRadius: CGFloat = 6
    private var cachedTheme: Theme = .defaultTheme

    // MARK: - Init

    override init(frame frameRect: NSRect) {
        gridView = NSGridView(frame: .zero)
        super.init(frame: frameRect)
        setupView()
        rebuildCachedThemeValues()
        observeThemeChanges()
    }

    required init?(coder: NSCoder) {
        gridView = NSGridView(frame: .zero)
        super.init(coder: coder)
        setupView()
        rebuildCachedThemeValues()
        observeThemeChanges()
    }

    // MARK: - Setup

    private func setupView() {
        precondition(
            Constants.maxSupportedGridCols >= (ThemeManager.gridColsOptions.max() ?? 0),
            "CandidateView: maxSupportedGridCols must be >= max(gridColsOptions)",
        )

        let maxRows = Constants.maxSupportedGridRows
        let maxCols = Constants.maxSupportedGridCols

        for _ in 0 ..< maxRows {
            let rowCells: [HighlightContainerView] = (0 ..< maxCols).map { _ in
                let container = HighlightContainerView(label: Self.makeLabelField())
                container.isHidden = true
                return container
            }
            cells.append(rowCells)
            let row = gridView.addRow(with: rowCells.map { $0 as NSView })
            row.isHidden = true
            row.topPadding = 0
            row.bottomPadding = 4
        }

        // Each column sizes to its widest visible cell; cells stretch to fill that width.
        // rowSpacing = 0 so hidden rows never contribute unexpected space — the uniform
        // 4 pt gap between rows comes from each row's bottomPadding alone.
        gridView.xPlacement = .fill
        gridView.yPlacement = .fill
        gridView.columnSpacing = 4
        gridView.rowSpacing = 0
        gridView.column(at: 0).leadingPadding = 4

        gridView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(gridView)
        NSLayoutConstraint.activate([
            gridView.leadingAnchor.constraint(equalTo: leadingAnchor),
            gridView.trailingAnchor.constraint(equalTo: trailingAnchor),
            gridView.topAnchor.constraint(equalTo: topAnchor, constant: 4),
            gridView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])

        // Separators are centred in the 4 pt inter-row gap (1.75 + 0.5 + 1.75 = 4 pt).
        for r in 0 ..< maxRows - 1 {
            let separator = NSView()
            separator.wantsLayer = true
            separator.translatesAutoresizingMaskIntoConstraints = false
            separator.isHidden = true
            addSubview(separator)
            NSLayoutConstraint.activate([
                separator.heightAnchor.constraint(equalToConstant: 0.5),
                separator.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
                separator.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
                separator.topAnchor.constraint(equalTo: cells[r][0].bottomAnchor, constant: 1.75),
            ])
            separators.append(separator)
        }
    }

    private static func makeLabelField() -> NSTextField {
        let label = NSTextField(labelWithString: "")
        label.isEditable = false
        label.isBordered = false
        label.drawsBackground = false
        label.textColor = .labelColor
        label.font = .systemFont(ofSize: 14)
        label.lineBreakMode = .byTruncatingTail
        label.isHidden = true
        return label
    }

    // MARK: - Theme observation

    private func observeThemeChanges() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(themeDidChange),
            name: .themeDidChange,
            object: nil,
        )
    }

    @objc private func themeDidChange() {
        rebuildCachedThemeValues()
    }

    private func rebuildCachedThemeValues() {
        let theme = ThemeManager.shared.current
        let alpha = ThemeManager.shared.highlightOpacity
        cachedTheme = theme
        wordFont = NSFont.systemFont(ofSize: theme.wordFontSize, weight: theme.fontWeight)
        numberFont = NSFont.monospacedSystemFont(ofSize: theme.numberFontSize, weight: theme.numberFontWeight)
        baselineOffset = (theme.wordFontSize - theme.numberFontSize) / 3.0
        pillColor = theme.highlightColor.withAlphaComponent(alpha)
        pillRadius = max(theme.cornerRadius - 2, 2)
        let separatorCGColor = theme.separatorColor.withAlphaComponent(0.5).cgColor
        for separator in separators {
            separator.layer?.backgroundColor = separatorCGColor
        }
    }

    // MARK: - Number label attributes

    private var numberTextAttributes: [NSAttributedString.Key: Any] {
        [
            .font: numberFont,
            .foregroundColor: cachedTheme.numberLabelColor,
            .baselineOffset: baselineOffset,
        ]
    }

    /// Returns `base` with its foreground color set to `.clear` when the cell is
    /// not in the active row, hiding the number label on inactive rows.
    private func rowNumberAttrs(_ base: [NSAttributedString.Key: Any], isActiveRow: Bool) -> [NSAttributedString.Key: Any] {
        if isActiveRow { return base }
        var hidden = base
        hidden[.foregroundColor] = NSColor.clear
        return hidden
    }

    // MARK: - Update

    /// Renders the grid described by `state`.
    /// Only `state.renderedRowCount` rows are shown; everything else is hidden.
    func updateGrid(_ state: GridCandidateState) {
        let theme = cachedTheme
        let numberAttrs = numberTextAttributes
        let renderedRows = state.renderedRowCount
        let columnCount = state.columnCount

        // Show/hide columns; trailing padding on the last visible column provides the right margin.
        for col in 0 ..< Constants.maxSupportedGridCols {
            let column = gridView.column(at: col)
            column.isHidden = col >= columnCount
            column.trailingPadding = col == columnCount - 1 ? 4 : 0
        }

        // Iterate over ALL pre-allocated rows (maxSupportedGridRows), not just the
        // user-configured max (gridMaxVisibleRows). Without this, shrinking from the
        // maximum row count (e.g. 5→3) leaves the excess rows in stale visible state
        // because those indices are never touched by the narrower loop.
        for rowIndex in 0 ..< Constants.maxSupportedGridRows {
            let gridRow = state.visibleRowOffset + rowIndex
            let nsGridRow = gridView.row(at: rowIndex)

            guard rowIndex < renderedRows, gridRow < state.totalRows else {
                nsGridRow.isHidden = true
                hideAllCells(inVisibleRow: rowIndex)
                continue
            }

            nsGridRow.isHidden = false

            for col in 0 ..< columnCount {
                let container = cells[rowIndex][col]
                let isActiveRow = (gridRow == state.activeRow)
                let isActive = isActiveRow && col == state.activeCol

                if state.hasLiteral, gridRow == 0, col == 0 {
                    renderLiteralCell(
                        container,
                        literalText: state.predictions.first,
                        isActive: isActive,
                        isActiveRow: isActiveRow,
                        theme: theme,
                        numberAttrs: numberAttrs,
                    )
                } else if let predIdx = state.predictionIndex(row: gridRow, col: col) {
                    renderPredictionCell(
                        container,
                        text: state.predictions[predIdx],
                        columnLabel: col + 1,
                        isActive: isActive,
                        isActiveRow: isActiveRow,
                        theme: theme,
                        numberAttrs: numberAttrs,
                    )
                } else {
                    hideCell(container)
                }
            }
        }

        for (i, separator) in separators.enumerated() {
            separator.isHidden = gridView.row(at: i + 1).isHidden
        }
    }

    // MARK: - Cell rendering

    private func renderLiteralCell(
        _ container: HighlightContainerView,
        literalText: String?,
        isActive: Bool,
        isActiveRow: Bool,
        theme: Theme,
        numberAttrs: [NSAttributedString.Key: Any],
    ) {
        let text = literalText ?? ""
        let textColor: NSColor = isActive ? theme.highlightTextColor : theme.normalTextColor
        let quoteAttrs: [NSAttributedString.Key: Any] = [
            .font: wordFont,
            .foregroundColor: theme.numberLabelColor,
        ]

        let activeNumberAttrs = rowNumberAttrs(numberAttrs, isActiveRow: isActiveRow)

        let attributed = NSMutableAttributedString()
        attributed.append(NSAttributedString(string: "1 ", attributes: activeNumberAttrs))
        attributed.append(NSAttributedString(string: "\u{201C}", attributes: quoteAttrs))
        attributed.append(NSAttributedString(string: text, attributes: [
            .font: wordFont,
            .foregroundColor: textColor,
        ]))
        attributed.append(NSAttributedString(string: "\u{201D}", attributes: quoteAttrs))

        container.label.attributedStringValue = attributed
        container.label.isHidden = false
        container.isHidden = false
        container.apply(highlighted: isActive, color: pillColor, radius: pillRadius)
    }

    private func renderPredictionCell(
        _ container: HighlightContainerView,
        text: String,
        columnLabel: Int,
        isActive: Bool,
        isActiveRow: Bool,
        theme: Theme,
        numberAttrs: [NSAttributedString.Key: Any],
    ) {
        let wordColor: NSColor = isActive ? theme.highlightTextColor : theme.normalTextColor
        let activeNumberAttrs = rowNumberAttrs(numberAttrs, isActiveRow: isActiveRow)

        let attributed = NSMutableAttributedString()
        attributed.append(NSAttributedString(string: "\(columnLabel) ", attributes: activeNumberAttrs))
        attributed.append(NSAttributedString(string: text, attributes: [
            .font: wordFont,
            .foregroundColor: wordColor,
        ]))

        container.label.attributedStringValue = attributed
        container.label.isHidden = false
        container.isHidden = false
        container.apply(highlighted: isActive, color: pillColor, radius: pillRadius)
    }

    // MARK: - Helpers

    private func hideCell(_ container: HighlightContainerView) {
        container.label.stringValue = ""
        container.label.isHidden = true
        container.isHidden = true
        container.isHighlighted = false
    }

    private func hideAllCells(inVisibleRow rowIndex: Int) {
        for container in cells[rowIndex] {
            hideCell(container)
        }
    }
}
