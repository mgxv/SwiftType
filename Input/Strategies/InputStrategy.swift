import Foundation

/// Decouples `InputController` from the concrete prediction backend.
///
/// Currently one concrete strategy exists (in `Input/Strategies/`):
/// - `LatinInputStrategy` — wraps `SpellCheckPredictor` / `NSSpellChecker` for Latin-script
///   languages (English, German, …) and `KenLMPredictor` for next-word predictions.
///
/// `InputController.refreshRules()` updates the active `typingRules`, `keyHandler`, and
/// `strategy` based on the BCP-47 base code, swapping them only when the language actually
/// changes to avoid unnecessary allocations. Adding a new language requires a new conformer
/// in `Input/Strategies/` and an entry in `LanguageDescriptor.all`.
@MainActor protocol InputStrategy: AnyObject {
    func completions(context: String, partial: String, limit: Int) -> [String]
    func nextWordPredictions(context: String, limit: Int) -> [String]
    func refreshLanguage()
}
