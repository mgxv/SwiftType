import AppKit
import InputMethodKit

@MainActor final class CandidateWindow {
    static let shared = CandidateWindow()

    private enum Layout {
        static let fallbackLineHeight: CGFloat = 20
        static let cursorGap: CGFloat = 4
        static let minWidth: CGFloat = 100
        static let minHeight: CGFloat = 30
    }

    private let panel: NSPanel
    private let candidateView: CandidateView
    private let backgroundView: NSView

    // MARK: - Grid state

    private var gridState: GridCandidateState?
    /// Cached cursor rect — reused when reflowing the panel on expand / collapse.
    private var lastCursorRect: NSRect = .zero

    // MARK: - Public accessors

    var isVisible: Bool {
        panel.isVisible
    }

    var isLiteralSelected: Bool {
        gridState?.isLiteralSelected ?? false
    }

    // MARK: - Init

    init() {
        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 30),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true,
        )
        panel.level = .popUpMenu
        panel.hasShadow = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        panel.contentView?.wantsLayer = true
        panel.contentView?.layer?.backgroundColor = NSColor.clear.cgColor

        backgroundView = NSView(frame: panel.contentView!.bounds)
        backgroundView.wantsLayer = true
        backgroundView.autoresizingMask = [.width, .height]
        panel.contentView?.addSubview(backgroundView)

        candidateView = CandidateView(frame: backgroundView.bounds)
        candidateView.translatesAutoresizingMaskIntoConstraints = false
        backgroundView.addSubview(candidateView)

        NSLayoutConstraint.activate([
            candidateView.leadingAnchor.constraint(equalTo: backgroundView.leadingAnchor),
            candidateView.trailingAnchor.constraint(equalTo: backgroundView.trailingAnchor),
            candidateView.topAnchor.constraint(equalTo: backgroundView.topAnchor),
            candidateView.bottomAnchor.constraint(equalTo: backgroundView.bottomAnchor),
        ])

        applyTheme()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(themeDidChange),
            name: .themeDidChange,
            object: nil,
        )
    }

    // MARK: - Theme

    private func applyTheme() {
        let theme = ThemeManager.shared.current

        backgroundView.layer?.backgroundColor = theme.backgroundColor.cgColor
        backgroundView.layer?.cornerRadius = theme.cornerRadius
        backgroundView.layer?.masksToBounds = true
        backgroundView.layer?.borderWidth = theme.border.width
        backgroundView.layer?.borderColor = theme.border.color.cgColor

        // Clip the window's visual output to the rounded rect so the rectangular
        // corner areas of the panel frame are fully transparent (no shadow bleed).
        // panel.hasShadow = false so there is no outer shadow.
        let contentLayer = panel.contentView?.layer
        contentLayer?.backgroundColor = NSColor.clear.cgColor
        contentLayer?.cornerRadius = theme.cornerRadius
        contentLayer?.masksToBounds = true
    }

    // MARK: - Show / Hide

    /// Displays the candidate grid.
    ///
    /// `candidates` is the full display-capitalised prediction buffer (up to
    /// `Constants.gridInitialPageSize` items). When `literalText` is non-nil it is prepended
    /// to `candidates` in the unified predictions array so that `predictions[0]` = literal
    /// and `predictions[1…]` = word predictions. The grid starts collapsed (row 0 only).
    func show(candidates: [String], literalText: String? = nil, client: (any IMKTextInput)?) {
        guard !candidates.isEmpty || literalText != nil else {
            hide()
            return
        }

        let unified = literalText.map { [$0] + candidates } ?? candidates
        gridState = GridCandidateState(
            columnCount: Constants.gridMaxVisibleCols,
            hasLiteral: literalText != nil,
            maxVisibleRows: Constants.gridMaxVisibleRows,
            predictions: unified,
        )

        lastCursorRect = resolvedCursorRect(from: client)
        refreshView()

        let (panelWidth, panelHeight) = fittingPanelSize()
        let origin = clampedPanelOrigin(cursorRect: lastCursorRect, panelWidth: panelWidth, panelHeight: panelHeight)
        presentPanel(at: origin, width: panelWidth, height: panelHeight)
    }

    func hide() {
        panel.orderOut(nil)
        gridState = nil
    }

    // MARK: - Row navigation

    /// Expands the grid (if collapsed) and moves the active row down by one.
    func moveActiveRowDown() {
        mutateGrid({ $0.moveRowDown() }, reframe: true)
    }

    /// Moves the active row up by one.
    /// Stays expanded when arriving at row 0; collapses on a second press while at row 0.
    func moveActiveRowUp() {
        mutateGrid({ $0.moveRowUp() }, reframe: true)
    }

    // MARK: - Column navigation

    /// Cycles the active column right within the current row (tab / right arrow).
    func moveActiveColumnRight() {
        mutateGrid({ $0.moveColumnRight() }, reframe: false)
    }

    /// Cycles the active column left within the current row (left arrow).
    func moveActiveColumnLeft() {
        mutateGrid({ $0.moveColumnLeft() }, reframe: false)
    }

    // MARK: - Lazy-load signal

    /// Returns the minimum prediction count InputController should request before pressing Down,
    /// or `nil` if the current buffer already covers the next row plus a two-row prefetch buffer.
    func predictionsNeededCountForDownArrow() -> Int? {
        guard let gs = gridState else { return nil }
        let targetRow = gs.activeRow + 3 // next row + 2-row prefetch buffer
        let maxIdx = gs.maxPredictionIndexNeeded(throughRow: targetRow)
        guard maxIdx >= gs.predictions.count else { return nil }
        return maxIdx + 1
    }

    /// Replaces the prediction buffer with a larger batch fetched during lazy loading.
    /// Does not reset navigation state (activeRow / isExpanded / activeCol).
    /// When `hasLiteral` is true the literal at `predictions[0]` is preserved and
    /// the incoming batch replaces `predictions[1…]`.
    func updatePredictions(_ predictions: [String]) {
        mutateGrid({ gs in
            gs.predictions = gs.hasLiteral ? [gs.predictions[0]] + predictions : predictions
        }, reframe: true)
    }

    // MARK: - Selection queries

    /// The display-capitalised prediction at the current (activeRow, activeCol) cursor,
    /// or `nil` when the literal slot is selected.
    func selectedCandidate() -> String? {
        gridState?.selectedPrediction
    }

    /// 0-based prediction index at the current cursor, or `nil` when the literal slot is selected.
    var selectedPredictionIndex: Int? {
        guard let gs = gridState else { return nil }
        return gs.predictionIndex(row: gs.activeRow, col: gs.activeCol)
    }

    /// 0-based prediction index for column `col` of the active row.
    /// Returns `nil` for the literal cell or cells beyond the loaded buffer.
    func predictionIndexAt(gridColumn col: Int) -> Int? {
        guard let gs = gridState else { return nil }
        return gs.predictionIndex(row: gs.activeRow, col: col)
    }

    /// True when (activeRow, col) is the literal slot.
    func isLiteralAt(gridColumn col: Int) -> Bool {
        guard let gs = gridState else { return false }
        return gs.hasLiteral && gs.activeRow == 0 && col == 0
    }

    // MARK: - Private helpers

    /// Applies a mutation to `gridState` and refreshes the view. When `reframe` is true
    /// the panel is also resized and repositioned (needed after row count changes).
    private func mutateGrid(_ body: (inout GridCandidateState) -> Void, reframe: Bool) {
        guard var gs = gridState else { return }
        body(&gs)
        gridState = gs
        if reframe { refreshViewAndReframe() } else { refreshView() }
    }

    // MARK: - Private rendering

    private func refreshView() {
        guard let gs = gridState else { return }
        candidateView.updateGrid(gs)
    }

    /// Refreshes the view and resizes / repositions the panel to fit the new row count.
    /// Called after any navigation that changes the number of visible rows.
    private func refreshViewAndReframe() {
        refreshView()
        let (w, h) = fittingPanelSize()
        let origin = clampedPanelOrigin(cursorRect: lastCursorRect, panelWidth: w, panelHeight: h)
        presentPanel(at: origin, width: w, height: h)
    }

    private func fittingPanelSize() -> (width: CGFloat, height: CGFloat) {
        candidateView.layoutSubtreeIfNeeded()
        let fittingSize = candidateView.fittingSize
        return (max(fittingSize.width, Layout.minWidth), max(fittingSize.height, Layout.minHeight))
    }

    private func presentPanel(at origin: NSPoint, width: CGFloat, height: CGFloat) {
        panel.setFrame(NSRect(x: origin.x, y: origin.y, width: width, height: height), display: true)
        panel.orderFront(nil)
    }

    private func resolvedCursorRect(from client: (any IMKTextInput)?) -> NSRect {
        if let client {
            var rect = NSRect.zero
            client.attributes(forCharacterIndex: 0, lineHeightRectangle: &rect)
            if rect.origin != .zero {
                return rect
            }
        }
        let mouse = NSEvent.mouseLocation
        return NSRect(x: mouse.x, y: mouse.y - Layout.fallbackLineHeight,
                      width: 0, height: Layout.fallbackLineHeight)
    }

    private func clampedPanelOrigin(cursorRect: NSRect, panelWidth: CGFloat, panelHeight: CGFloat) -> NSPoint {
        var origin = NSPoint(
            x: cursorRect.origin.x,
            y: cursorRect.origin.y - panelHeight - Layout.cursorGap,
        )
        if let screen = NSScreen.main {
            let frame = screen.visibleFrame
            origin.x = min(max(origin.x, frame.minX), frame.maxX - panelWidth)
            if origin.y < frame.minY {
                origin.y = cursorRect.maxY + Layout.cursorGap
            }
        }
        return origin
    }

    @objc private func themeDidChange() {
        applyTheme()
        if gridState != nil {
            refreshView()
        }
    }
}
