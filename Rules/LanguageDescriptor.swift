import Foundation

/// A static catalog entry associating a BCP-47 language code with its `TypingRules`
/// implementation, `InputStrategy` factory, and `KeyHandler` factory.
///
/// Adding a new language requires only a new entry in `all` with `rules:`, `strategy:`,
/// and `keyHandler:` — `InputController` reads these from the descriptor and requires
/// no changes itself.
@MainActor struct LanguageDescriptor {
    let code: String
    let displayName: String
    let rules: any TypingRules
    /// Factory for the prediction strategy, called by `InputController.refreshRules()`.
    let makeStrategy: () -> any InputStrategy
    /// Factory for the language-specific key handler.
    let makeKeyHandler: () -> any KeyHandler

    /// All languages that have a coded `TypingRules` implementation.
    static let all: [LanguageDescriptor] = [
        .make(code: "en", rules: EnglishTypingRules.shared, strategy: { LatinInputStrategy() }, keyHandler: { LatinKeyHandler() }),
        .make(code: "de", rules: GermanTypingRules.shared, strategy: { LatinInputStrategy() }, keyHandler: { LatinKeyHandler() }),
    ]

    /// Returns the descriptor for `code`, or `nil` if no language with that code exists.
    static func descriptor(for code: String) -> LanguageDescriptor? {
        all.first(where: { $0.code == code })
    }

    /// Derives the native display name from the language's maximal locale identifier
    /// (e.g. "en" → "en-Latn-US" → "English (United States)").
    private static func make(
        code: String,
        rules: any TypingRules,
        strategy: @escaping () -> any InputStrategy,
        keyHandler: @escaping () -> any KeyHandler,
    ) -> LanguageDescriptor {
        let maxCode = Locale.Language(identifier: code).maximalIdentifier
        let name = Locale(identifier: maxCode).localizedString(forIdentifier: maxCode) ?? code
        return LanguageDescriptor(code: code, displayName: name, rules: rules, makeStrategy: strategy, makeKeyHandler: keyHandler)
    }
}
