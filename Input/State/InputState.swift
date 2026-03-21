import NaturalLanguage

/// All mutable runtime state for `InputController`, extracted to enable unit testing of
/// `InputState` and the context-tracking logic.
///
/// `typingRules` is included here because every handler reads it and `refreshRules()` in
/// `InputController` updates it. It is intentionally **not** cleared by `reset()` —
/// rules persist across composition resets and are only refreshed by notification callbacks.
@MainActor final class InputState {
    /// Maximum characters kept in `typingContext` before trimming is triggered.
    nonisolated static let maxContextLength = 400
    /// Minimum characters preserved after trimming when no clean sentence boundary is found.
    nonisolated static let fallbackContextLength = 300

    var typingRules: any TypingRules = EnglishTypingRules.shared

    // MARK: - Composition state

    var compositionBuffer = ""
    var currentPredictions: [String] = []
    var typingContext = ""
    var isNextWordMode = false
    var didAutoInsertTrailingSpace = false

    // MARK: - Context helpers

    /// Appends `text` to `typingContext` and trims to a sentence boundary when the
    /// context exceeds `maxContextLength` characters.
    func appendToContext(_ text: String) {
        typingContext.append(text)
        if typingContext.count > Self.maxContextLength {
            typingContext = InputState.trimContext(typingContext)
        }
    }

    /// Pure function: trims `context` to the nearest sentence boundary so it stays
    /// under `maxContextLength` characters. Falls back to `suffix(fallbackContextLength)`
    /// when fewer than two sentences are detected or the trim point is at the start of
    /// the string.
    ///
    /// Kept on `InputState` (rather than `InputController`) so that `appendToContext`
    /// does not create a bottom-up dependency on the controller layer.
    nonisolated static func trimContext(_ context: String) -> String {
        let tokenizer = NLTokenizer(unit: .sentence)
        tokenizer.string = context

        var sentenceStarts: [String.Index] = []
        tokenizer.enumerateTokens(in: context.startIndex ..< context.endIndex) { range, _ in
            sentenceStarts.append(range.lowerBound)
            return true
        }

        guard sentenceStarts.count >= 2 else {
            return String(context.suffix(fallbackContextLength))
        }

        let keepFrom = sentenceStarts[sentenceStarts.count - 2]

        guard keepFrom > context.startIndex else {
            return String(context.suffix(fallbackContextLength))
        }

        let trimmed = String(context[keepFrom...])
        return trimmed.count <= maxContextLength ? trimmed : String(trimmed.suffix(fallbackContextLength))
    }

    /// Resets all composition fields to their defaults.
    /// Does **not** reset `typingRules` — those are managed by `InputController.refreshRules()`.
    func reset() {
        compositionBuffer = ""
        currentPredictions = []
        typingContext = ""
        isNextWordMode = false
        didAutoInsertTrailingSpace = false
    }
}
