import AppKit
import Carbon.HIToolbox
import os

/// Next-word prediction backed by KenLM n-gram models.
///
/// Wraps `KenLMBridge` and handles language switching via the same notification-driven
/// refresh pattern as `SpellCheckPredictor`.  Only provides `nextWordPredictions`;
/// word completions remain with `SpellCheckPredictor`.
@MainActor final class KenLMPredictor {
    private var cachedLanguage: String

    init() {
        cachedLanguage = LanguageManager.shared.effectiveBaseCode
        Log.kenLM.info("KenLMPredictor initialized — language '\(self.cachedLanguage, privacy: .public)'")

        // Load the initial model.
        KenLMBridge.shared().setLanguage(cachedLanguage)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(refreshLanguage),
            name: NSTextInputContext.keyboardSelectionDidChangeNotification,
            object: nil,
        )
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(refreshLanguage),
            name: NSNotification.Name(kTISNotifySelectedKeyboardInputSourceChanged as String),
            object: nil,
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(refreshLanguage),
            name: .activePredictionLanguageDidChange,
            object: nil,
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        DistributedNotificationCenter.default().removeObserver(self)
    }

    @objc func refreshLanguage() {
        let newLanguage = LanguageManager.shared.effectiveBaseCode
        if newLanguage != cachedLanguage {
            Log.kenLM.info("refreshLanguage — was '\(self.cachedLanguage, privacy: .public)', now '\(newLanguage, privacy: .public)'")
            cachedLanguage = newLanguage
            KenLMBridge.shared().setLanguage(cachedLanguage)
        }
    }

    /// Extra results to request from KenLMBridge to compensate for spell-check filtering.
    private static let filterBuffer = 20

    /// Returns up to `limit` next-word predictions ranked by descending n-gram probability.
    /// `context` is the committed text preceding the cursor; all vocab words are scored.
    func nextWordPredictions(context: String, limit: Int) -> [String] {
        guard limit > 0, !context.isEmpty else { return [] }
        let raw = KenLMBridge.shared().nextWordPredictions(context, limit: limit + Self.filterBuffer)
        return Array(filterBySpelling(raw).prefix(limit))
    }

    /// Returns up to `limit` predictions starting with `prefix`, ranked by descending n-gram probability.
    /// `context` is the committed text preceding the cursor; `prefix` is the partially typed word.
    /// Only vocab words matching the prefix are scored.
    func prefixMatchSuggestions(context: String, prefix: String, limit: Int) -> [String] {
        guard limit > 0, !context.isEmpty, !prefix.isEmpty else { return [] }
        let raw = KenLMBridge.shared().prefixMatchSuggestions(context, prefix: prefix, limit: limit + Self.filterBuffer)
        return Array(filterBySpelling(raw).prefix(limit))
    }

    /// Removes words that NSSpellChecker considers misspelled.
    private func filterBySpelling(_ words: [String]) -> [String] {
        let checker = NSSpellChecker.shared
        let language = LanguageManager.shared.effectiveLanguage
        return words.filter { word in
            let range = checker.checkSpelling(
                of: word,
                startingAt: 0,
                language: language,
                wrap: false,
                inSpellDocumentWithTag: 0,
                wordCount: nil,
            )
            return range.location == NSNotFound
        }
    }
}
