import AppKit
import InputMethodKit
import os

/// The `IMKInputController` subclass that owns all input-method logic.
///
/// ## Architecture
///
/// `InputController` is split across focused extension files and delegates language-specific
/// key handling to a `KeyHandler` (see `LatinKeyHandler`):
///
/// | File / Type | Responsibility |
/// |---|---|
/// | `InputControllerLifecycle` | IMK overrides: `activateServer`, `deactivateServer`, `composedString`, … |
/// | `InputControllerStateManagement` | `resetState`, `refreshRules`, `cancelPredictions`, `nextWordSettingChanged` |
/// | `InputControllerPredictions` | `updatePredictions`, `triggerNextWordPredictions`, `fetchMorePredictions` |
/// | `InputControllerKeyHandling` | `handle(_:client:)` and shared per-key handlers (backspace, escape, arrows) |
/// | `InputControllerComposition` | `commitCompositionBuffer`, `commitWord`, `selectCandidateByIndex`, marked text |
/// | `KeyHandler` protocol | Language-specific: Space, Return, candidate selection, bypass, punctuation, literal slot |
/// | `LatinKeyHandler` | English/German: literal slot, trailing space, next-word predictions |
///
/// ## State machine overview
///
/// `InputController` operates as a two-phase state machine:
///
/// **Composition phase** — the user is building a word character by character.
/// - `state.compositionBuffer` accumulates the raw keystrokes (e.g. `"hel"`).
/// - `state.currentPredictions` holds the unified candidate array. The first element is
///   the composition buffer itself (literal slot) and subsequent elements are spell-checker
///   completions.
/// - `state.typingRules` provides language-specific character decisions (continuation marks,
///   sentence enders, auto-space chars, trailing-space and literal-slot behaviour).
/// - Marked text is shown in the active text field via `setMarkedText`.
///
/// **Next-word phase** (`state.isNextWordMode == true`) — the buffer has just been committed
/// and the candidate bar shows next-word suggestions. No marked text is active.
/// - `state.currentPredictions` holds the next-word list (no literal slot).
/// - Any letter keypress cancels this phase and starts a new composition.
///
/// ## Adding a new language
///
/// 1. Add a `*TypingRules` struct in `Rules/Conformers/`.
/// 2. Add a `*InputStrategy` in `Input/Strategies/` (or reuse `LatinInputStrategy`).
/// 3. Add a `*KeyHandler` in `Input/KeyHandling/` (or reuse `LatinKeyHandler`).
/// 4. Add one entry to `LanguageDescriptor.all` with `rules:`, `strategy:`, and `keyHandler:`.
///
/// ## Threading
/// All methods are called on the main thread by InputMethodKit.
@MainActor @objc(InputController)
class InputController: IMKInputController {
    // MARK: - Constants

    static let modifierMask: NSEvent.ModifierFlags = [.command, .control, .option]
    static let ownBundleIdentifier = Bundle.main.bundleIdentifier
    static let markedTextAttributes: [NSAttributedString.Key: Any] = [
        .underlineStyle: NSUnderlineStyle.single.rawValue,
        .foregroundColor: NSColor.textColor,
        .font: NSFont.systemFont(ofSize: NSFont.systemFontSize),
    ]

    // MARK: - State + Strategy

    let state = InputState()
    lazy var strategy: any InputStrategy = LatinInputStrategy()
    var keyHandler: any KeyHandler = LatinKeyHandler()
    /// Tracks the active language code so `refreshRules()` can skip recreation when unchanged.
    var activeLanguageCode: String = ""

    // MARK: - Init

    /// Swift requires designated initializer overrides to reside in the class body, not extensions.
    override init!(server: IMKServer!, delegate: Any!, client inputClient: Any!) {
        super.init(server: server, delegate: delegate, client: inputClient)
        Log.inputController.info("InputController.init — instance \(String(describing: self), privacy: .public) created")
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(refreshRules),
            name: NSTextInputContext.keyboardSelectionDidChangeNotification,
            object: nil,
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(refreshRules),
            name: .activePredictionLanguageDidChange,
            object: nil,
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(nextWordSettingChanged),
            name: .nextWordPredictionsSettingDidChange,
            object: nil,
        )
    }
}
