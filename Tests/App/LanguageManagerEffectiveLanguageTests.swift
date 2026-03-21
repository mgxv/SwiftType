@testable import SwiftType
import XCTest

/// Tests for `LanguageManager.effectiveLanguage` and `effectiveBaseCode`.
///
/// These properties centralise the language resolution logic previously duplicated
/// across SpellCheckPredictor, KenLMPredictor, InputController, and StatusBarController.
@MainActor final class LanguageManagerEffectiveLanguageTests: XCTestCase {
    private var defaults: UserDefaults!
    private var manager: LanguageManager!
    private var suiteName: String!

    override func setUp() async throws {
        suiteName = "com.matthew.inputmethod.SwiftType.effectivelang.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
        manager = LanguageManager(defaults: defaults)
    }

    override func tearDown() async throws {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        manager = nil
    }

    // MARK: - effectiveLanguage

    func testEffectiveLanguageReturnsPinnedCodeWhenSet() {
        // Arrange: pin to "de".
        manager.addLanguage(code: "de")
        manager.selectLanguage(code: "de")

        // Act / Assert: effectiveLanguage returns the pinned code.
        XCTAssertEqual(manager.effectiveLanguage, "de")
    }

    func testEffectiveLanguageReturnsFallbackInAutoMode() {
        // Arrange: selectedCode is "" (Auto mode, default state).
        XCTAssertEqual(manager.selectedCode, "")

        // Act / Assert: effectiveLanguage returns the system spell-checker language (non-empty).
        XCTAssertFalse(manager.effectiveLanguage.isEmpty,
                       "Auto mode should return the system spell-checker language")
    }

    func testEffectiveLanguageChangesWhenLanguagePinned() {
        let autoLanguage = manager.effectiveLanguage

        manager.addLanguage(code: "de")
        manager.selectLanguage(code: "de")
        let pinnedLanguage = manager.effectiveLanguage

        // The pinned language should be "de", which differs from the auto language
        // (unless the system language happens to be "de").
        XCTAssertEqual(pinnedLanguage, "de")
        if autoLanguage != "de" {
            XCTAssertNotEqual(autoLanguage, pinnedLanguage)
        }
    }

    func testEffectiveLanguageReturnsAutoAfterDeselectingPinned() {
        manager.addLanguage(code: "de")
        manager.selectLanguage(code: "de")
        XCTAssertEqual(manager.effectiveLanguage, "de")

        // Deselect (back to Auto).
        manager.selectLanguage(code: "")
        XCTAssertFalse(manager.effectiveLanguage.isEmpty)
    }

    // MARK: - effectiveBaseCode

    func testEffectiveBaseCodeReturnsPinnedBaseCode() {
        manager.addLanguage(code: "de")
        manager.selectLanguage(code: "de")
        XCTAssertEqual(manager.effectiveBaseCode, "de")
    }

    func testEffectiveBaseCodeStripsRegionSubtag() {
        // When Auto mode returns something like "en_US", effectiveBaseCode should be "en".
        let baseCode = manager.effectiveBaseCode
        XCTAssertFalse(baseCode.contains("_"), "Base code should not contain region subtag")
        XCTAssertFalse(baseCode.contains("-"), "Base code should not contain script subtag")
    }

    func testEffectiveBaseCodeIsNonEmptyInAutoMode() {
        XCTAssertFalse(manager.effectiveBaseCode.isEmpty)
    }

    func testEffectiveBaseCodeMatchesEffectiveLanguageBaseCode() {
        let expected = manager.effectiveLanguage.baseLanguageCode
        XCTAssertEqual(manager.effectiveBaseCode, expected)
    }

    func testEffectiveBaseCodeMatchesPinnedBaseCode() {
        manager.addLanguage(code: "de")
        manager.selectLanguage(code: "de")
        let expected = "de".baseLanguageCode
        XCTAssertEqual(manager.effectiveBaseCode, expected)
    }
}
