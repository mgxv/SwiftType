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

    /// Returns up to `limit` completion candidates for `prefix` given `context`.
    func completions(context: String, prefix: String, limit: Int) -> [String] {
        guard limit > 0, !prefix.isEmpty else { return [] }

        let fullString = context + prefix
        let nsString = fullString as NSString
        let prefixLength = (prefix as NSString).length
        let prefixRange = NSRange(location: nsString.length - prefixLength, length: prefixLength)
        let lowercasedPrefix = prefix.lowercased()
        let language = cachedLanguage

        var results: [String] = []
        var seen = Set<String>()

        // 1. Spell correction — if the prefix is misspelled, offer the fix first
        let correction = spellChecker.correction(
            forWordRange: prefixRange,
            in: fullString,
            language: language,
            inSpellDocumentWithTag: tag,
        )
        if let correction, correction.lowercased() != lowercasedPrefix {
            results.append(correction)
            seen.insert(correction.lowercased())
        }

        // 2. Prefix completions from the system dictionary
        if results.count < limit {
            let completions = spellChecker.completions(
                forPartialWordRange: prefixRange,
                in: fullString,
                language: language,
                inSpellDocumentWithTag: tag,
            )
            if let completions {
                addUnique(from: completions, to: &results, seen: &seen, excluding: lowercasedPrefix, limit: limit)
            }
        }

        // 3. Fuzzy guesses — fill remaining slots (handles typos like "helo")
        if results.count < limit {
            let guesses = spellChecker.guesses(
                forWordRange: prefixRange,
                in: fullString,
                language: language,
                inSpellDocumentWithTag: tag,
            )
            if let guesses {
                addUnique(from: guesses, to: &results, seen: &seen, excluding: lowercasedPrefix, limit: limit)
            }
        }

        return results
    }

    private func addUnique(from words: [String], to results: inout [String], seen: inout Set<String>, excluding lowercasedPrefix: String, limit: Int) {
        for word in words {
            guard results.count < limit else { break }
            let lower = word.lowercased()
            if lower != lowercasedPrefix, seen.insert(lower).inserted {
                results.append(word)
            }
        }
    }
}
