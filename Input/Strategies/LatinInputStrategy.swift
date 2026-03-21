/// Concrete `InputStrategy` for Latin-script languages.
///
/// Word completions and spell corrections are backed by `SpellCheckPredictor` /
/// `NSSpellChecker`. Next-word predictions are backed exclusively by `KenLMPredictor`
/// (n-gram language model). When no KenLM model is loaded for the active language,
/// next-word predictions are disabled (returns empty).
///
/// Covers English, German, and any future Latin language added to `LanguageDescriptor.all`.
/// `refreshLanguage` delegates to both predictors so they pick up the active BCP-47
/// code after a language switch.
@MainActor final class LatinInputStrategy: InputStrategy {
    private let spellPredictor: SpellCheckPredictor
    private let kenlmPredictor: KenLMPredictor

    init() {
        spellPredictor = SpellCheckPredictor()
        kenlmPredictor = KenLMPredictor()
    }

    func completions(context: String, partial: String, limit: Int) -> [String] {
        let spellResults = spellPredictor.completions(context: context, partial: partial, limit: limit)

        // Skip KenLM context matching for very short prefixes (too broad)
        // or when there is no prior context to score against.
        let prefix = partial.lowercased()
        guard prefix.count >= 2, !context.isEmpty else { return spellResults }

        // Query KenLM for context-aware completions: get next-word predictions
        // and filter to those matching the typed prefix.  These are ranked by
        // n-gram probability in context (e.g. "store" after "went to the").
        // Request a large batch since most predictions won't match the prefix.
        let kenlmWords = kenlmPredictor.nextWordPredictions(context: context, limit: 50)
        let contextMatches = kenlmWords.filter { $0.lowercased().hasPrefix(prefix) }

        guard !contextMatches.isEmpty else { return spellResults }

        // Merge: spell correction first (most important for typos), then KenLM
        // context matches (contextually ranked), then remaining spell completions.
        var seen = Set<String>()
        var merged: [String] = []

        // 1. Keep the spell correction at the top if it exists and differs
        //    from a simple prefix completion (it's a real typo fix).
        if let correction = spellResults.first,
           correction.lowercased() != prefix,
           !correction.lowercased().hasPrefix(prefix)
        {
            merged.append(correction)
            seen.insert(correction.lowercased())
        }

        // 2. KenLM context matches (ranked by n-gram probability).
        for word in contextMatches {
            guard merged.count < limit else { break }
            let lower = word.lowercased()
            if lower != prefix, seen.insert(lower).inserted {
                merged.append(word)
            }
        }

        // 3. Fill remaining slots with spell completions.
        for word in spellResults {
            guard merged.count < limit else { break }
            let lower = word.lowercased()
            if lower != prefix, seen.insert(lower).inserted {
                merged.append(word)
            }
        }

        return merged
    }

    func nextWordPredictions(context: String, limit: Int) -> [String] {
        kenlmPredictor.nextWordPredictions(context: context, limit: limit)
    }

    func refreshLanguage() {
        spellPredictor.refreshLanguage()
        kenlmPredictor.refreshLanguage()
    }
}
