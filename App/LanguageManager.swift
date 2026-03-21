import AppKit

// MARK: - Language Code Helpers

extension String {
    /// Strips BCP-47 region and script subtags, returning the bare language code.
    /// Examples: "en-US" → "en", "de-DE" → "de".
    var baseLanguageCode: String {
        components(separatedBy: CharacterSet(charactersIn: "_-")).first ?? self
    }
}

/// Manages the user's set of enabled prediction languages and the currently active one.
///
/// Persists a list of BCP-47 language codes to UserDefaults under `languages.addedCodes`.
/// Only languages present in `LanguageDescriptor.all` can be added. The list drives
/// `SpellCheckPredictor` language selection.
///
/// **Invariant:** `addedCodes` always contains at least one code that has a matching
/// `LanguageDescriptor`. This is enforced at load time (invalid codes are filtered,
/// empty lists fall back to `["en"]`) and at mutation time (`removeLanguage` refuses
/// to remove the last entry, `addLanguage` rejects unknown codes).
///
/// `selectedCode` ("" = Auto) tracks which language from the list is currently pinned
/// for prediction.
@MainActor final class LanguageManager {
    static let shared = LanguageManager()

    private static let defaultCode = "en"
    private static let defaultsKey = "languages.addedCodes"
    private static let selectedCodeKey = "languages.selectedCode"
    private let defaults: UserDefaults

    private(set) var addedCodes: [String]

    /// The pinned prediction language code. Empty string means Auto (follow system keyboard).
    private(set) var selectedCode: String

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let stored = defaults.stringArray(forKey: Self.defaultsKey) ?? []
        let valid = stored.filter { LanguageDescriptor.descriptor(for: $0) != nil }
        addedCodes = valid.isEmpty ? [Self.defaultCode] : valid
        selectedCode = defaults.string(forKey: Self.selectedCodeKey) ?? ""
    }

    // MARK: - Derived

    /// Descriptors for each added code, in insertion order. All codes are guaranteed
    /// to have descriptors (enforced by init validation and `addLanguage` guards);
    /// `compactMap` is a safety net only.
    var addedDescriptors: [LanguageDescriptor] {
        addedCodes.compactMap { LanguageDescriptor.descriptor(for: $0) }
    }

    /// Coded languages not yet added by the user.
    var availableToAdd: [LanguageDescriptor] {
        LanguageDescriptor.all.filter { d in !addedCodes.contains(d.code) }
    }

    // MARK: - Mutations

    func addLanguage(code: String) {
        guard !addedCodes.contains(code) else { return }
        guard LanguageDescriptor.descriptor(for: code) != nil else {
            Log.languageManager.error("LanguageManager — no TypingRules for code '\(code, privacy: .public)'; add rejected")
            return
        }
        let previous = effectiveBaseCode
        addedCodes.append(code)
        // Pin the previously active language when in Auto mode so adding a language
        // doesn't silently switch predictions to the system keyboard language.
        // The user can switch via the status bar menu.
        if selectedCode.isEmpty {
            selectedCode = previous
            persistSelectedCode()
        }
        notifyIfEffectiveChanged(from: previous)
        save()
    }

    func removeLanguage(at index: Int) {
        guard addedCodes.count > 1, addedCodes.indices.contains(index) else { return }
        let previous = effectiveBaseCode
        let removed = addedCodes[index]
        addedCodes.remove(at: index)
        // If the removed language was pinned, fall back to Auto.
        if selectedCode == removed {
            selectedCode = ""
            persistSelectedCode()
        }
        notifyIfEffectiveChanged(from: previous)
        save()
    }

    func selectLanguage(code: String) {
        guard code.isEmpty || addedCodes.contains(code) else { return }
        guard code != selectedCode else { return }
        let previous = effectiveBaseCode
        selectedCode = code
        persistSelectedCode()
        notifyIfEffectiveChanged(from: previous)
    }

    func moveLanguage(from fromIndex: Int, to toIndex: Int) {
        guard fromIndex != toIndex,
              addedCodes.indices.contains(fromIndex),
              addedCodes.indices.contains(toIndex) else { return }
        let code = addedCodes.remove(at: fromIndex)
        addedCodes.insert(code, at: toIndex)
        // No notification — the table view animates the row move itself via moveRow(at:to:).
        // The add-language button state remains correct because moves don't change the set of
        // added codes — only their order. The button is refreshed in languagesDidChange(),
        // which fires on add/remove but intentionally not on move.
        persistCodes()
    }

    // MARK: - Language Resolution

    /// Returns the effective prediction language as a full locale string (e.g. "en_US").
    /// When only one language is configured, returns that code directly — all predictors
    /// and the status bar agree on the same language regardless of the system keyboard.
    /// Otherwise: pinned code if set, else system spell-checker language.
    /// Used by `SpellCheckPredictor`.
    var effectiveLanguage: String {
        if addedCodes.count == 1 { return addedCodes[0] }
        let stored = selectedCode
        return stored.isEmpty ? NSSpellChecker.shared.language() : stored
    }

    /// Returns the effective prediction language as a base code (e.g. "en").
    /// When only one language is configured, returns it directly (unified with
    /// `effectiveLanguage`). Otherwise falls back to the first added code when
    /// the resolved code has no `LanguageDescriptor` (e.g. system keyboard is French
    /// but no French descriptor exists). This guarantees the returned code always has
    /// a matching descriptor, KenLM model, and typing rules.
    /// Used by `KenLMPredictor`, `InputController.refreshRules()`, `StatusBarController`.
    var effectiveBaseCode: String {
        if addedCodes.count == 1 { return addedCodes[0] }
        let base = effectiveLanguage.baseLanguageCode
        if LanguageDescriptor.descriptor(for: base) != nil { return base }
        return addedCodes.first!
    }

    // MARK: - Private

    /// Posts `.activePredictionLanguageDidChange` if the effective language changed.
    /// Shared by `addLanguage`, `removeLanguage`, and `selectLanguage` to ensure
    /// the status bar, predictors, and InputController stay in sync.
    private func notifyIfEffectiveChanged(from previous: String) {
        if effectiveBaseCode != previous {
            NotificationCenter.default.post(name: .activePredictionLanguageDidChange, object: nil)
        }
    }

    private func persistCodes() {
        defaults.set(addedCodes, forKey: Self.defaultsKey)
    }

    private func persistSelectedCode() {
        if selectedCode.isEmpty {
            defaults.removeObject(forKey: Self.selectedCodeKey)
        } else {
            defaults.set(selectedCode, forKey: Self.selectedCodeKey)
        }
    }

    private func save() {
        persistCodes()
        NotificationCenter.default.post(name: .languagesDidChange, object: nil)
    }
}
