/// German-specific `TypingRules` conformance.
///
/// Supplies the three character sets that drive auto-space removal, composition-buffer
/// continuation, and sentence-boundary detection. Both capitalisation methods
/// (`preserveCapitalization`, `applyCapitalization`) are inherited from the default
/// implementations in `TypingRules`. `applyCapitalization` uses `sentenceEndingChars`
/// to auto-capitalise suggestions at sentence start.
///
/// Key differences from English:
/// - Closing double-quote is U+201C " (German „text") rather than U+201D "
/// - Closing guillemet is U+00AB « (Swiss-style »text«) rather than U+00BB »
/// - Apostrophes still continue composition for informal contractions (e.g. "geht's")
/// - `:` in `sentenceEndingChars` triggers auto-capitalisation after colons
struct GermanTypingRules: TypingRules, Sendable {
    static let shared = GermanTypingRules()

    /// Punctuation that removes an auto-inserted trailing space when typed immediately
    /// after a committed word. Uses German closing quotation marks: U+201C (") for
    /// standard „text" style and U+00AB («) for Swiss »text« style. U+2019 (') covers
    /// both the curly apostrophe and the German closing single-quotation mark (‚text').
    ///
    /// This set has **14 members**; `TypingRulesEdgeCaseTests.testGermanAutoRemoveSpaceCharsExactCount` locks this in.
    let autoRemoveSpaceChars: Set<Character> = [
        ".", ",", "!", "?", ":", ";", ")", "]", "}", "%",
        "\u{201C}", "\u{2019}", "\u{00AB}", "\u{2026}",
    ]

    /// Characters that extend the composition buffer mid-word. German uses apostrophes
    /// informally in contractions (e.g. "geht's", "hab'") and in genitive of names
    /// ending in a sibilant (e.g. "Thomas' Buch"), so both straight and curly
    /// apostrophes are included. The hyphen (U+002D) is also included to allow
    /// hyphenated German compound words (e.g. "E-Mail", "U-Bahn", "Groß-Britannien")
    /// to be typed as a single composition unit and recognised by NSSpellChecker.
    ///
    /// This set has **3 members**; `TypingRulesEdgeCaseTests.testGermanCompositionContinuationMarksExactCount` locks this in.
    let compositionContinuationMarks: Set<Character> = ["'", "\u{2019}", "-"]

    /// Characters that mark sentence boundaries. Extends the English set with `:`
    /// because German grammar treats a colon introducing a complete sentence as a
    /// sentence boundary (e.g. "Er sagte: Es ist schön."). Includes the Unicode
    /// ellipsis (U+2026) which macOS auto-substitutes from `...`.
    ///
    /// This set has **5 members**; `TypingRulesEdgeCaseTests.testGermanSentenceEndingCharsExactCount` locks this in.
    let sentenceEndingChars: Set<Character> = [".", "!", "?", ":", "\u{2026}"]
}
