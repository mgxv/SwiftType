import InputMethodKit
import os

/// State reset, language-rule selection, strategy swapping, and prediction cancellation.
extension InputController {
    // MARK: - State Management

    func resetState() {
        state.reset()
        CandidateWindow.shared.hide()
    }

    /// Updates `typingRules`, `keyHandler`, and `strategy` to match the active prediction
    /// language. Falls back to English defaults for unknown languages.
    ///
    /// Called on `activateServer` and on both language-change notifications
    /// (`.activePredictionLanguageDidChange`, `keyboardSelectionDidChangeNotification`).
    @objc func refreshRules() {
        let baseCode = LanguageManager.shared.effectiveBaseCode

        // Skip full recreation when the language hasn't changed — refreshRules() is called
        // on every activateServer plus two notification observers, so without this guard
        // each call discards all predictor instances and their notification registrations,
        // leaking observers and eventually overwhelming the system.
        if baseCode == activeLanguageCode {
            return
        }
        activeLanguageCode = baseCode

        let descriptor = LanguageDescriptor.descriptor(for: baseCode)
        if descriptor == nil {
            Log.inputController.info("refreshRules — no descriptor for '\(baseCode, privacy: .public)'; falling back to English/Latin defaults")
        }
        state.typingRules = descriptor?.rules ?? EnglishTypingRules.shared
        keyHandler = descriptor?.makeKeyHandler() ?? LatinKeyHandler()
        strategy = descriptor?.makeStrategy() ?? LatinInputStrategy()
        strategy.refreshLanguage()
    }

    @objc func nextWordSettingChanged() {
        if !SettingsManager.shared.isNextWordPredictionsEnabled {
            cancelPredictions()
        }
    }

    func cancelPredictions() {
        state.isNextWordMode = false
        state.currentPredictions = []
        CandidateWindow.shared.hide()
    }
}
