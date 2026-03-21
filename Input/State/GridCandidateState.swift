/// Pure value type describing the grid layout, cursor position, and navigation state for
/// the candidate window. Contains no AppKit dependencies and is fully unit-testable.
///
/// ## Grid geometry
///
/// Candidates are arranged in a C-column grid (C = `columnCount`). `predictions` is a
/// flat, unified array:
/// - When `hasLiteral` is true: `predictions[0]` = literal typing-buffer text;
///   `predictions[1…]` = word predictions. The literal occupies (row 0, col 0).
/// - When `hasLiteral` is false: `predictions[0…]` = word predictions.
///
/// In both cases the layout formula is identical:
/// - Row r, col c → `predictions[r * C + c]`
///
/// ## Navigation
///
/// - Left / Right / Tab cycle `activeCol` within the current row.
/// - Down expands the grid and increments `activeRow`; Up decrements and collapses at row 0.
/// - The visible window (up to `maxVisibleRows` rows) follows `activeRow` via `visibleRowOffset`.
struct GridCandidateState: Sendable {
    // MARK: - Stored

    /// Number of columns (= gridCols captured at show() time).
    let columnCount: Int
    /// True when a literal typing-buffer slot occupies (row 0, col 0).
    let hasLiteral: Bool
    /// Maximum number of rows in the visible window; captured from user setting at show() time.
    let maxVisibleRows: Int

    /// Flat display-capitalised prediction buffer; grows during lazy loading.
    var predictions: [String]

    var activeRow: Int = 0
    var activeCol: Int = 0
    var isExpanded: Bool = false
    /// Index of the first rendered row in the visible window.
    var visibleRowOffset: Int = 0

    // MARK: - Geometry

    /// Total logical rows in the grid given the currently loaded predictions.
    var totalRows: Int {
        predictions.isEmpty ? 0 : (predictions.count + columnCount - 1) / columnCount
    }

    /// How many cells are populated in row `r` (up to `columnCount`).
    func columnCountForRow(_ r: Int) -> Int {
        min(columnCount, max(0, predictions.count - r * columnCount))
    }

    /// Index into `predictions` for cell (row, col).
    /// Returns `nil` for the literal cell (row 0, col 0 when `hasLiteral`) or for cells
    /// beyond the loaded buffer.
    func predictionIndex(row: Int, col: Int) -> Int? {
        if hasLiteral, row == 0, col == 0 { return nil } // literal slot
        let idx = row * columnCount + col
        return idx < predictions.count ? idx : nil
    }

    /// Maximum `predictions` index needed to render every cell in rows 0…r.
    /// Used to determine whether a lazy-load fetch is required before navigating to row r.
    func maxPredictionIndexNeeded(throughRow r: Int) -> Int {
        (r + 1) * columnCount - 1
    }

    // MARK: - Selection

    /// True when the literal typing-buffer slot is selected.
    var isLiteralSelected: Bool {
        hasLiteral && activeRow == 0 && activeCol == 0
    }

    /// The prediction string at the current cursor position, or nil when the literal is selected.
    var selectedPrediction: String? {
        guard let idx = predictionIndex(row: activeRow, col: activeCol) else { return nil }
        return predictions[idx]
    }

    /// Prediction string at `col` of the active row, nil if the cell is literal or empty.
    func predictionAt(col: Int) -> String? {
        guard let idx = predictionIndex(row: activeRow, col: col) else { return nil }
        return predictions[idx]
    }

    // MARK: - Visible window

    /// Number of rows actually rendered (1 when collapsed; up to `maxVisibleRows` when expanded).
    var renderedRowCount: Int {
        isExpanded ? min(totalRows, maxVisibleRows) : 1
    }

    /// Adjusts `visibleRowOffset` so `activeRow` is always within the visible window.
    mutating func clampVisibleWindow() {
        if activeRow < visibleRowOffset {
            visibleRowOffset = activeRow
        } else if activeRow >= visibleRowOffset + maxVisibleRows {
            visibleRowOffset = activeRow - maxVisibleRows + 1
        }
        visibleRowOffset = max(0, visibleRowOffset)
    }

    // MARK: - Navigation

    /// Expands the grid on the first press (without moving the active row).
    /// On subsequent presses, moves the active row down by one.
    /// Does nothing if already at the last row.
    /// The active column is preserved, clamped to the target row's column count.
    mutating func moveRowDown() {
        guard isExpanded else {
            isExpanded = true
            return
        }
        let nextRow = activeRow + 1
        if nextRow < totalRows {
            activeRow = nextRow
        }
        activeCol = min(activeCol, max(0, columnCountForRow(activeRow) - 1))
        clampVisibleWindow()
    }

    /// Moves the active row up by one.
    /// - Not expanded: no-op, returns `false`.
    /// - At row 0 while expanded: collapses the grid, returns `true`.
    /// - Otherwise: moves up one row, preserving `activeCol` (clamped to the target row), returns `false`.
    @discardableResult
    mutating func moveRowUp() -> Bool {
        guard isExpanded else { return false }
        if activeRow == 0 {
            isExpanded = false
            visibleRowOffset = 0
            return true
        }
        activeRow -= 1
        activeCol = min(activeCol, max(0, columnCountForRow(activeRow) - 1))
        clampVisibleWindow()
        return false
    }

    /// Cycles the active column right within the current row's populated cells.
    mutating func moveColumnRight() {
        let cols = columnCountForRow(activeRow)
        guard cols > 0 else { return }
        activeCol = (activeCol + 1) % cols
    }

    /// Cycles the active column left within the current row's populated cells.
    mutating func moveColumnLeft() {
        let cols = columnCountForRow(activeRow)
        guard cols > 0 else { return }
        activeCol = (activeCol - 1 + cols) % cols
    }
}
