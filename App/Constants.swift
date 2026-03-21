import Foundation

@MainActor enum Constants {
    static let maxSupportedGridCols = 7
    static var gridMaxVisibleCols: Int {
        ThemeManager.shared.gridCols
    }

    static let replacementNotFound = NSRange(location: NSNotFound, length: 0)

    /// Hard upper bound for grid row pre-allocation in `CandidateView`. Never changes.
    static let maxSupportedGridRows = 5

    /// User-configured maximum rows rendered in the expanded grid (3–5, default 4).
    static var gridMaxVisibleRows: Int {
        ThemeManager.shared.gridRows
    }

    /// Predictions fetched on the first call to `updatePredictions` / `triggerNextWordPredictions`.
    /// Sized to fill the entire visible grid so lazy loading is only needed beyond the last row.
    static var gridInitialPageSize: Int {
        gridMaxVisibleCols * gridMaxVisibleRows
    }
}
