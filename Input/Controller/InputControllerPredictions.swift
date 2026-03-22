import InputMethodKit
import os

/// Prediction fetching, display-word transformation, lazy loading, and next-word mode.
extension InputController {
    // MARK: - Predictions

    func updatePredictions(client: any IMKTextInput) {
        guard !state.compositionBuffer.isEmpty else {
            cancelPredictions()
            return
        }

        let (unified, display) = fetchCompletions(limit: Constants.gridInitialPageSize)
        Log.inputController.info("updatePredictions — partial='\(self.state.compositionBuffer, privacy: .public)' context=\(self.state.typingContext.count, privacy: .public) chars, results=\(display.count, privacy: .public)")

        state.currentPredictions = unified
        CandidateWindow.shared.show(
            candidates: display,
            literalText: keyHandler.literalText(compositionBuffer: state.compositionBuffer),
            client: client,
        )
    }

    func triggerNextWordPredictions(client: any IMKTextInput) {
        guard SettingsManager.shared.isNextWordPredictionsEnabled else { return }
        let nextWords = strategy.nextWordPredictions(
            context: state.typingContext,
            limit: Constants.gridInitialPageSize,
        )
        guard !nextWords.isEmpty else { return }
        state.currentPredictions = nextWords
        state.isNextWordMode = true
        CandidateWindow.shared.show(candidates: nextWords, literalText: nil, client: client)
    }

    /// Fetches a larger prediction batch for lazy loading when the user navigates to a new grid row.
    /// Stores original-case in `state.currentPredictions` and pushes display-capitalised versions
    /// to `CandidateWindow` without resetting navigation state.
    func fetchMorePredictions(limit: Int) {
        if state.isNextWordMode {
            let words = strategy.nextWordPredictions(context: state.typingContext, limit: limit)
            state.currentPredictions = words
            CandidateWindow.shared.updatePredictions(words)
        } else {
            let (unified, display) = fetchCompletions(limit: limit)
            state.currentPredictions = unified
            CandidateWindow.shared.updatePredictions(display)
        }
    }

    /// Cancels next-word predictions on non-letter input (except space, navigation, candidate, and return keys).
    func cancelNextWordIfNeeded(key: KeyCode?, event: NSEvent) {
        guard state.isNextWordMode else { return }
        guard key != .space else { return }
        if let key, KeyCode.navigationKeys.contains(key) || KeyCode.candidateKeys.contains(key) || key == .returnKey {
            return
        }
        if let char = event.characters?.first, !char.isLetter {
            cancelPredictions()
        }
    }

    // MARK: - Private

    /// Fetches completions from the strategy and returns both the unified predictions
    /// array (for `state.currentPredictions`) and the display-capitalised array (for
    /// `CandidateWindow`). Shared by `updatePredictions` and `fetchMorePredictions`.
    private func fetchCompletions(limit: Int) -> (unified: [String], display: [String]) {
        let rawWords = strategy.completions(
            context: state.typingContext,
            partial: state.compositionBuffer,
            limit: limit,
        )
        let unified = keyHandler.unifiedPredictions(
            from: rawWords, compositionBuffer: state.compositionBuffer,
        )
        let display = displayWords(from: rawWords)
        return (unified, display)
    }

    /// Maps raw (original-case) predictions to display-capitalised strings by matching
    /// the case of the composition buffer onto each suggestion.
    private func displayWords(from rawWords: [String]) -> [String] {
        rawWords.map {
            state.typingRules.applyCapitalization(
                original: state.compositionBuffer,
                suggested: $0,
                context: state.typingContext,
            )
        }
    }
}
