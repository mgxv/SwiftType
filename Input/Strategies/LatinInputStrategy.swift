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

    func completions(context: String, prefix: String, limit: Int) -> [String] {
        let spellResults = spellPredictor.completions(context: context, prefix: prefix, limit: Constants.spellCompletionLimit)

        // Skip KenLM context matching for very short prefixes (too broad)
        // or when there is no prior context to score against.
        let lowercasedPrefix = prefix.lowercased()
        guard !lowercasedPrefix.isEmpty, !context.isEmpty else { return spellResults }

        // Query KenLM for context-aware completions matching the typed prefix,
        // ranked by n-gram probability (e.g. "store" after "went to the st").
        let prefixMatches = kenlmPredictor.prefixMatchSuggestions(context: context, prefix: lowercasedPrefix, limit: Constants.kenlmPrefixMatchLimit)

        guard !prefixMatches.isEmpty else { return spellResults }

        // Merge: KenLM context matches first (contextually ranked), then spell results.
        // KenLM matches are ranked by how likely they follow the preceding context,
        // making them more relevant than dictionary-based spell corrections which
        // ignore context entirely (e.g. "much" after "I love you very" vs "Mac").
        var seen = Set<String>()
        var merged: [String] = []

        // 1. KenLM prefix matches (ranked by n-gram probability in context).
        for word in prefixMatches {
            guard merged.count < limit else { break }
            let lower = word.lowercased()
            if lower != lowercasedPrefix, seen.insert(lower).inserted {
                merged.append(word)
            }
        }

        // 2. Fill remaining slots with spell completions.
        for word in spellResults {
            guard merged.count < limit else { break }
            let lower = word.lowercased()
            if lower != lowercasedPrefix, seen.insert(lower).inserted {
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
