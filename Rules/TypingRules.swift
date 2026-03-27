/// Defines the language-specific typing rules used by `InputController`.
///
/// `InputController` is a language-agnostic orchestrator — it manages composition buffers,
/// navigation, and key routing. All decisions that depend on the target language (which
/// characters extend a word, which punctuation triggers auto-space removal, when to
/// capitalise) are delegated to a `TypingRules` conformer.
///
/// Default implementations are provided for `insertsTrailingSpace` and the two
/// capitalisation methods (`preserveCapitalization`, `applyCapitalization`). Conformers
/// only need to supply the three character sets.
///
/// - Note: Members may appear in both `compositionContinuationMarks` and
///   `autoRemoveSpaceChars` (e.g. U+2019 in English). This is intentional:
///   `InputController` checks continuation marks before auto-space removal, so an
///   overlapping character never reaches the auto-space path mid-word.
protocol TypingRules: Sendable {
    /// Punctuation characters that should replace an auto-inserted trailing space.
    var autoRemoveSpaceChars: Set<Character> { get }

    /// Characters that extend the current composition buffer mid-word (e.g. apostrophes
    /// for contractions and elisions). Named generically so future languages can supply
    /// empty sets or different marks without changing the protocol.
    var compositionContinuationMarks: Set<Character> { get }

    /// Characters whose presence (followed by a space) signals a sentence boundary.
    var sentenceEndingChars: Set<Character> { get }

    /// Whether `commitWord` appends a trailing space after the committed text.
    var insertsTrailingSpace: Bool { get }

    /// Matches the capitalisation of `original` onto `suggested`: if `original` starts
    /// with an uppercase letter, uppercases the first character of `suggested`.
    func preserveCapitalization(original: String, suggested: String) -> String

    /// Display-time capitalisation applied to each suggestion before showing in the
    /// candidate bar. If the user typed an uppercase letter, their case is preserved
    /// via `preserveCapitalization`. Otherwise, if `context` indicates a sentence start
    /// (empty, or trailing `sentenceEndingChars` character), the suggestion is
    /// auto-capitalised.
    func applyCapitalization(original: String, suggested: String, context: String) -> String
}

extension TypingRules {
    var insertsTrailingSpace: Bool {
        true
    }

    func preserveCapitalization(original: String, suggested: String) -> String {
        guard let firstChar = original.first, firstChar.isUppercase else { return suggested }
        return suggested.prefix(1).uppercased() + suggested.dropFirst()
    }

    func applyCapitalization(original: String, suggested: String, context: String) -> String {
        if let first = original.first, first.isUppercase {
            return preserveCapitalization(original: original, suggested: suggested)
        }
        if isAtSentenceStart(context: context) {
            return suggested.prefix(1).uppercased() + suggested.dropFirst()
        }
        return preserveCapitalization(original: original, suggested: suggested)
    }

    /// Returns `true` when `context` indicates the next word is at the start of a sentence:
    /// either the context is empty/whitespace-only, or the last non-whitespace character is
    /// in `sentenceEndingChars`.
    private func isAtSentenceStart(context: String) -> Bool {
        guard let lastNonSpace = context.last(where: { !$0.isWhitespace }) else { return true }
        return sentenceEndingChars.contains(lastNonSpace)
    }
}
