import AppKit
import Carbon.HIToolbox
import os

@MainActor final class SpellCheckPredictor {
    private let spellChecker = NSSpellChecker.shared
    private nonisolated let tag: Int
    private var cachedLanguage: String

    init() {
        tag = NSSpellChecker.uniqueSpellDocumentTag()
        cachedLanguage = LanguageManager.shared.effectiveLanguage
        Log.spellCheck.info("SpellCheckPredictor initialized (tag=\(self.tag, privacy: .public))")

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(refreshLanguage),
            name: NSSpellChecker.didChangeAutomaticSpellingCorrectionNotification,
            object: nil,
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(refreshLanguage),
            name: NSTextInputContext.keyboardSelectionDidChangeNotification,
            object: nil,
        )
        // Also observe the system distributed notification for input source changes,
        // which fires reliably after programmatic TISSelectInputSource calls.
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(refreshLanguage),
            name: NSNotification.Name(kTISNotifySelectedKeyboardInputSourceChanged as String),
            object: nil,
        )
        // Refresh when the user pins or cycles the active prediction language.
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
        NSSpellChecker.shared.closeSpellDocument(withTag: tag)
    }

    @objc func refreshLanguage() {
        let newLanguage = LanguageManager.shared.effectiveLanguage
        if newLanguage != cachedLanguage {
            Log.spellCheck.info("refreshLanguage — was '\(self.cachedLanguage, privacy: .public)', now '\(newLanguage, privacy: .public)'")
            cachedLanguage = newLanguage
        }
    }

    /// Returns up to `limit` completion candidates for `partial` given `context`.
    func completions(context: String, partial: String, limit: Int) -> [String] {
        let fullString = context + partial
        let nsString = fullString as NSString
        let partialLength = (partial as NSString).length
        let partialRange = NSRange(location: nsString.length - partialLength, length: partialLength)
        let lowercasedPartial = partial.lowercased()
        let language = cachedLanguage

        var results: [String] = []
        var seen = Set<String>()

        // 1. Spell correction — if the partial is misspelled, offer the fix first
        let correction = spellChecker.correction(
            forWordRange: partialRange,
            in: fullString,
            language: language,
            inSpellDocumentWithTag: tag,
        )
        if let correction, correction.lowercased() != lowercasedPartial {
            results.append(correction)
            seen.insert(correction.lowercased())
        }

        // 2. Prefix completions from the system dictionary
        let completions = spellChecker.completions(
            forPartialWordRange: partialRange,
            in: fullString,
            language: language,
            inSpellDocumentWithTag: tag,
        )
        if let completions {
            addUnique(from: completions, to: &results, seen: &seen, excluding: lowercasedPartial, limit: limit)
        }

        // 3. Fuzzy guesses — always run to fill remaining slots (handles typos like "helo")
        if results.count < limit {
            let guesses = spellChecker.guesses(
                forWordRange: partialRange,
                in: fullString,
                language: language,
                inSpellDocumentWithTag: tag,
            )
            if let guesses {
                addUnique(from: guesses, to: &results, seen: &seen, excluding: lowercasedPartial, limit: limit)
            }
        }

        return Array(results.prefix(limit))
    }

    /// Returns up to `limit` next-word predictions given the committed `context`.
    func nextWordPredictions(context: String, limit: Int) -> [String] {
        let nsString = context as NSString
        // Zero-length range at the end of the string triggers next-word prediction
        let zeroRange = NSRange(location: nsString.length, length: 0)

        let completions = spellChecker.completions(
            forPartialWordRange: zeroRange,
            in: context,
            language: cachedLanguage,
            inSpellDocumentWithTag: tag,
        )

        return Array((completions ?? []).prefix(limit))
    }

    private func addUnique(from words: [String], to results: inout [String], seen: inout Set<String>, excluding lowercasedPartial: String, limit: Int) {
        for word in words {
            guard results.count < limit else { break }
            let lower = word.lowercased()
            if lower != lowercasedPartial, seen.insert(lower).inserted {
                results.append(word)
            }
        }
    }
}
