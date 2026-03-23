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

    /// Maximum spell check results (corrections, prefix completions, fuzzy guesses) from NSSpellChecker.
    static let spellCompletionLimit = 5

    /// Maximum KenLM candidates queried during prefix-matched completion matching.
    static let kenlmPrefixMatchLimit = 25

    /// Maximum total completions returned while the user is typing (composition mode).
    static let completionFetchLimit = 30

    /// Maximum predictions fetched during lazy loading when navigating the grid.
    static let predictionLazyLoadLimit = 20

    /// Maximum next-word predictions fetched after committing a word.
    static let predictionFetchLimit = 30
}
