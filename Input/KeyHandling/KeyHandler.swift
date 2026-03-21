import InputMethodKit

/// Encapsulates language-specific key handling behaviour.
///
/// `InputController` owns a `KeyHandler` and delegates to it for the handful of
/// operations that may differ between languages. Shared logic — backspace, escape,
/// arrow navigation, modifier passthrough — stays in `InputController`.
@MainActor protocol KeyHandler: Sendable {
    /// Handles a candidate number-key press for the prediction at `predictionIndex`.
    func handleCandidateSelection(
        predictionIndex: Int,
        controller: InputController,
        client: any IMKTextInput,
    )

    /// Handles the Space key. Returns `true` if the event was consumed.
    func handleSpace(
        controller: InputController,
        client: any IMKTextInput,
    ) -> Bool

    /// Handles the Return key when the candidate window is visible.
    /// Returns `true` if the event was consumed.
    func handleReturn(
        controller: InputController,
        client: any IMKTextInput,
    ) -> Bool

    /// Returns the literal text for the candidate window's literal slot, or `nil`
    /// when no literal slot should be shown.
    func literalText(compositionBuffer: String) -> String?

    /// Builds the unified `currentPredictions` array from raw completions.
    func unifiedPredictions(from rawWords: [String], compositionBuffer: String) -> [String]
}
