import AppKit
import InputMethodKit
import os

/// Buffer commit, candidate selection, and marked-text helpers.
extension InputController {
    // MARK: - Composition

    func commitCompositionBuffer(client: any IMKTextInput) {
        let text = state.compositionBuffer
        if text.isEmpty {
            // Nothing to commit — clear any lingering marked text and hide predictions.
            client.setMarkedText(
                "",
                selectionRange: NSRange(location: 0, length: 0),
                replacementRange: Constants.replacementNotFound,
            )
            cancelPredictions()
            return
        }
        Log.inputController.info("Committing buffer: \(text, privacy: .public)")
        state.appendToContext(text)
        client.insertText(text, replacementRange: Constants.replacementNotFound)
        state.compositionBuffer = ""
        cancelPredictions()
    }

    func commitWord(_ word: String, client: any IMKTextInput) {
        let insertsSpace = state.typingRules.insertsTrailingSpace
        let committed = insertsSpace ? word + " " : word
        client.insertText(committed, replacementRange: Constants.replacementNotFound)
        state.appendToContext(committed)
        state.compositionBuffer = ""
        state.didAutoInsertTrailingSpace = insertsSpace
        cancelPredictions()
    }

    // MARK: - Candidate Selection

    /// Commits the prediction at `index` in `state.currentPredictions`.
    /// Applies `preserveCapitalization` in composition mode; uses the prediction as-is in
    /// next-word mode (consistent with pre-existing behaviour for number-key commits).
    func selectCandidateByIndex(_ index: Int, client: any IMKTextInput) {
        guard index < state.currentPredictions.count else { return }

        let prediction = state.currentPredictions[index]
        let word = state.isNextWordMode
            ? prediction
            : state.typingRules.preserveCapitalization(
                original: state.compositionBuffer,
                suggested: prediction,
            )

        Log.inputController.info("Selected candidate \(index + 1, privacy: .public): \(word, privacy: .public) (nextWord=\(self.state.isNextWordMode ? 1 : 0, privacy: .public))")
        commitWord(word, client: client)
    }

    // MARK: - Marked Text

    func updateMarkedText(client: any IMKTextInput) {
        setMarkedText(state.compositionBuffer, client: client)
    }

    private func setMarkedText(_ text: String, client: any IMKTextInput) {
        let attrString = NSAttributedString(string: text, attributes: Self.markedTextAttributes)
        client.setMarkedText(
            attrString,
            selectionRange: NSRange(location: text.count, length: 0),
            replacementRange: Constants.replacementNotFound,
        )
    }
}
