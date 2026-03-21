import AppKit
import InputMethodKit
import os

/// Key handling for Latin-script languages (English, German).
///
/// Latin mode shows a literal slot (the raw buffer) as the first candidate,
/// inserts a trailing space after committed words, and triggers next-word
/// predictions after Space (but not Return).
struct LatinKeyHandler: KeyHandler {
    func handleCandidateSelection(
        predictionIndex: Int,
        controller: InputController,
        client: any IMKTextInput,
    ) {
        controller.selectCandidateByIndex(predictionIndex, client: client)
    }

    func handleSpace(
        controller: InputController,
        client: any IMKTextInput,
    ) -> Bool {
        let state = controller.state

        // `selectedCandidate()` returns nil when the literal slot is selected, so
        // the literal path falls through to the buffer guard below.
        if CandidateWindow.shared.isVisible,
           let selected = CandidateWindow.shared.selectedCandidate()
        {
            Log.inputController.info("Space committed selected candidate: \(selected, privacy: .public)")
            controller.commitWord(selected, client: client)
            controller.triggerNextWordPredictions(client: client)
            return true
        }

        guard !state.compositionBuffer.isEmpty else {
            state.appendToContext(" ")
            return false
        }

        Log.inputController.info("Space committed literal: \(state.compositionBuffer, privacy: .public)")
        controller.commitWord(state.compositionBuffer, client: client)
        controller.triggerNextWordPredictions(client: client)
        return true
    }

    func handleReturn(
        controller: InputController,
        client: any IMKTextInput,
    ) -> Bool {
        guard CandidateWindow.shared.isVisible else { return false }

        let word = CandidateWindow.shared.isLiteralSelected
            ? controller.state.compositionBuffer
            : CandidateWindow.shared.selectedCandidate()
        if let word { controller.commitWord(word, client: client) }
        return true
    }

    func literalText(compositionBuffer: String) -> String? {
        compositionBuffer
    }

    func unifiedPredictions(from rawWords: [String], compositionBuffer: String) -> [String] {
        [compositionBuffer] + rawWords
    }
}
