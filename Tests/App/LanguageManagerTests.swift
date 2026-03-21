@testable import SwiftType
import XCTest

/// Tests for LanguageManager.
///
/// Each test uses an isolated UserDefaults suite so that mutations never leak into
/// UserDefaults.standard or between tests.
@MainActor final class LanguageManagerTests: XCTestCase {
    private var defaults: UserDefaults!
    private var manager: LanguageManager!
    private var suiteName: String!

    override func setUp() async throws {
        suiteName = "com.matthew.inputmethod.SwiftType.langmanagertests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
        manager = LanguageManager(defaults: defaults)
    }

    override func tearDown() async throws {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        manager = nil
    }

    // MARK: - Initial state

    func testInitialAddedCodesDefaultsToEnglish() {
        // Arrange: fresh defaults with no stored value.
        // Act / Assert: the default language list contains just "en".
        XCTAssertEqual(manager.addedCodes, ["en"])
    }

    func testInitialSelectedCodeIsEmpty() {
        // Empty string means "Auto — follow system keyboard".
        XCTAssertEqual(manager.selectedCode, "")
    }

    // MARK: - addLanguage

    func testAddLanguageAppendsCode() {
        // Arrange: start with just "en".
        // Act: add German.
        manager.addLanguage(code: "de")
        // Assert: both codes are present in order.
        XCTAssertEqual(manager.addedCodes, ["en", "de"])
    }

    func testAddLanguageDuplicateIsIgnored() {
        // Arrange: "en" is already in the list.
        // Act: try to add "en" again.
        manager.addLanguage(code: "en")
        // Assert: still only one entry.
        XCTAssertEqual(manager.addedCodes.count, 1)
    }

    func testAddLanguageUnknownCodeIsRejected() {
        // Arrange: "xx" has no TypingRules entry in LanguageDescriptor.all.
        // Act: try to add it.
        manager.addLanguage(code: "xx")
        // Assert: list is unchanged.
        XCTAssertEqual(manager.addedCodes, ["en"])
    }

    func testAddLanguagePostsLanguagesDidChangeNotification() {
        // Arrange: observe the notification.
        let counter = NotificationCounter()
        let token = NotificationCenter.default.addObserver(
            forName: .languagesDidChange, object: nil, queue: nil,
        ) { _ in counter.increment() }
        // Act: add a new language.
        manager.addLanguage(code: "de")
        NotificationCenter.default.removeObserver(token)
        // Assert: exactly one notification posted.
        XCTAssertEqual(counter.count, 1)
    }

    func testAddLanguageDuplicateDoesNotPostNotification() {
        // Arrange: observe notification.
        let counter = NotificationCounter()
        let token = NotificationCenter.default.addObserver(
            forName: .languagesDidChange, object: nil, queue: nil,
        ) { _ in counter.increment() }
        // Act: try to add "en" again (already present).
        manager.addLanguage(code: "en")
        NotificationCenter.default.removeObserver(token)
        // Assert: no notification.
        XCTAssertEqual(counter.count, 0)
    }

    // MARK: - removeLanguage

    func testRemoveLanguageAtValidIndex() {
        // Arrange: add German so there are two codes.
        manager.addLanguage(code: "de")
        // Act: remove the first code ("en").
        manager.removeLanguage(at: 0)
        // Assert: only "de" remains.
        XCTAssertEqual(manager.addedCodes, ["de"])
    }

    func testRemoveLanguageOutOfBoundsIsSilent() {
        // Arrange: only "en" is in the list.
        // Act: try to remove at an invalid index.
        manager.removeLanguage(at: 99)
        // Assert: list is unchanged.
        XCTAssertEqual(manager.addedCodes, ["en"])
    }

    func testRemoveLanguagePostsLanguagesDidChangeNotification() {
        // Arrange.
        manager.addLanguage(code: "de")
        let counter = NotificationCounter()
        let token = NotificationCenter.default.addObserver(
            forName: .languagesDidChange, object: nil, queue: nil,
        ) { _ in counter.increment() }
        // Act: remove "de".
        manager.removeLanguage(at: 1)
        NotificationCenter.default.removeObserver(token)
        // Assert.
        XCTAssertEqual(counter.count, 1)
    }

    func testRemoveSelectedLanguageFallsBackToAuto() {
        // Arrange: add German, pin it as the selected language.
        manager.addLanguage(code: "de")
        manager.selectLanguage(code: "de")
        XCTAssertEqual(manager.selectedCode, "de")
        // Act: remove the pinned language.
        manager.removeLanguage(at: 1)
        // Assert: selectedCode falls back to "" (Auto).
        XCTAssertEqual(manager.selectedCode, "")
    }

    func testRemoveUnselectedLanguageDoesNotChangeSelectedCode() {
        // Arrange: add German, pin English (the first code).
        manager.addLanguage(code: "de")
        manager.selectLanguage(code: "en")
        // Act: remove German (not the pinned language).
        manager.removeLanguage(at: 1)
        // Assert: selectedCode is still "en".
        XCTAssertEqual(manager.selectedCode, "en")
    }

    // MARK: - selectLanguage

    func testSelectLanguageUpdatesSelectedCode() {
        // Arrange: add German.
        manager.addLanguage(code: "de")
        // Act: select German.
        manager.selectLanguage(code: "de")
        // Assert.
        XCTAssertEqual(manager.selectedCode, "de")
    }

    func testSelectLanguageEmptyStringSelectsAuto() {
        // Arrange: pin German.
        manager.addLanguage(code: "de")
        manager.selectLanguage(code: "de")
        // Act: deselect to Auto.
        manager.selectLanguage(code: "")
        // Assert.
        XCTAssertEqual(manager.selectedCode, "")
    }

    func testSelectLanguageNotInListIsIgnored() {
        // Arrange: "fr" is not an added language.
        // Act: try to select it.
        manager.selectLanguage(code: "fr")
        // Assert: no change.
        XCTAssertEqual(manager.selectedCode, "")
    }

    func testSelectLanguageSameCodeDoesNotPostNotification() {
        // Arrange: selectedCode starts as "".
        let counter = NotificationCounter()
        let token = NotificationCenter.default.addObserver(
            forName: .activePredictionLanguageDidChange, object: nil, queue: nil,
        ) { _ in counter.increment() }
        // Act: select "" again (no change).
        manager.selectLanguage(code: "")
        NotificationCenter.default.removeObserver(token)
        // Assert: no notification for a no-op selection.
        XCTAssertEqual(counter.count, 0)
    }

    func testSelectLanguagePostsActivePredictionLanguageDidChangeNotification() {
        // Arrange: add German.
        manager.addLanguage(code: "de")
        let counter = NotificationCounter()
        let token = NotificationCenter.default.addObserver(
            forName: .activePredictionLanguageDidChange, object: nil, queue: nil,
        ) { _ in counter.increment() }
        // Act: pin German.
        manager.selectLanguage(code: "de")
        NotificationCenter.default.removeObserver(token)
        // Assert.
        XCTAssertEqual(counter.count, 1)
    }

    // MARK: - moveLanguage

    func testMoveLanguageReordersArray() {
        // Arrange: two codes.
        manager.addLanguage(code: "de")
        // Act: move "de" to index 0.
        manager.moveLanguage(from: 1, to: 0)
        // Assert: order reversed.
        XCTAssertEqual(manager.addedCodes, ["de", "en"])
    }

    func testMoveLanguageSameIndexIsNoOp() {
        // Arrange.
        manager.addLanguage(code: "de")
        // Act: move index 0 to 0.
        manager.moveLanguage(from: 0, to: 0)
        // Assert: unchanged.
        XCTAssertEqual(manager.addedCodes, ["en", "de"])
    }

    func testMoveLanguageOutOfBoundsIsSilent() {
        // Arrange.
        manager.addLanguage(code: "de")
        // Act.
        manager.moveLanguage(from: 5, to: 0)
        // Assert: unchanged.
        XCTAssertEqual(manager.addedCodes, ["en", "de"])
    }

    func testMoveLanguageDoesNotPostLanguagesDidChangeNotification() {
        // Arrange.
        manager.addLanguage(code: "de")
        let counter = NotificationCounter()
        let token = NotificationCenter.default.addObserver(
            forName: .languagesDidChange, object: nil, queue: nil,
        ) { _ in counter.increment() }
        // Act: move without the notification path.
        manager.moveLanguage(from: 0, to: 1)
        NotificationCenter.default.removeObserver(token)
        // Assert: moveLanguage suppresses the notification (mirrors moveMapping/moveTarget).
        XCTAssertEqual(counter.count, 0)
    }

    // MARK: - addedDescriptors

    func testAddedDescriptorsReturnsDescriptorsForAddedCodes() {
        // Arrange: "en" is in LanguageDescriptor.all.
        // Act.
        let descriptors = manager.addedDescriptors
        // Assert: one descriptor with code "en".
        XCTAssertEqual(descriptors.count, 1)
        XCTAssertEqual(descriptors[0].code, "en")
    }

    func testAddedDescriptorsSkipsUnknownCodes() {
        // Arrange: inject an unknown code directly into defaults to simulate a
        // language that was removed from LanguageDescriptor.all after persisting.
        defaults.set(["en", "xx"], forKey: "languages.addedCodes")
        let manager2 = LanguageManager(defaults: defaults)
        // Act.
        let descriptors = manager2.addedDescriptors
        // Assert: "xx" is silently skipped.
        XCTAssertEqual(descriptors.count, 1)
        XCTAssertEqual(descriptors[0].code, "en")
    }

    func testAddedDescriptorsOrderMatchesAddedCodesOrder() {
        // addedDescriptors must preserve the insertion order of addedCodes.
        manager.addLanguage(code: "de")
        let descriptors = manager.addedDescriptors
        XCTAssertEqual(descriptors.map(\.code), ["en", "de"],
                       "addedDescriptors must preserve addedCodes insertion order")
    }

    func testAddedDescriptorsOrderReflectsMoveLanguage() {
        // After moveLanguage reorders addedCodes, addedDescriptors must follow.
        manager.addLanguage(code: "de")
        // Swap "en" and "de".
        manager.moveLanguage(from: 0, to: 1)
        let descriptors = manager.addedDescriptors
        XCTAssertEqual(descriptors.map(\.code), ["de", "en"],
                       "addedDescriptors must reflect addedCodes order after moveLanguage")
    }

    func testAddedDescriptorsMixedWithUnknownCodePreservesOrder() {
        // Unknown codes are skipped; known codes preserve relative order.
        defaults.set(["xx", "en", "yy", "de"], forKey: "languages.addedCodes")
        let m = LanguageManager(defaults: defaults)
        let codes = m.addedDescriptors.map(\.code)
        XCTAssertEqual(codes, ["en", "de"],
                       "Known codes must preserve relative order even when interleaved with unknown codes")
    }

    // MARK: - availableToAdd

    func testAvailableToAddExcludesAlreadyAddedCodes() {
        // Arrange: "en" is already in the list.
        // Act.
        let available = manager.availableToAdd
        // Assert: "en" is not in the available list.
        XCTAssertFalse(available.contains(where: { $0.code == "en" }))
    }

    func testAvailableToAddContainsNonAddedLanguages() {
        // Arrange: "de" has a TypingRules implementation but is not yet added.
        let available = manager.availableToAdd
        // Assert: "de" is available to add.
        XCTAssertTrue(available.contains(where: { $0.code == "de" }))
    }

    func testAvailableToAddIsEmptyWhenAllLanguagesAdded() {
        // Arrange: add every language from LanguageDescriptor.all.
        for descriptor in LanguageDescriptor.all {
            if descriptor.code != "en" {
                manager.addLanguage(code: descriptor.code)
            }
        }
        // Act.
        let available = manager.availableToAdd
        // Assert: nothing left to add.
        XCTAssertTrue(available.isEmpty)
    }

    // MARK: - Persistence

    func testAddedCodesPersistAcrossInstances() {
        // Arrange: add German.
        manager.addLanguage(code: "de")
        // Act: create a second manager reading the same defaults.
        let manager2 = LanguageManager(defaults: defaults)
        // Assert: both codes persisted.
        XCTAssertEqual(manager2.addedCodes, ["en", "de"])
    }

    func testSelectedCodePersistsAcrossInstances() {
        // Arrange: add German and pin it.
        manager.addLanguage(code: "de")
        manager.selectLanguage(code: "de")
        // Act: create a second manager.
        let manager2 = LanguageManager(defaults: defaults)
        // Assert.
        XCTAssertEqual(manager2.selectedCode, "de")
    }

    func testAutoSelectedCodeNotPersistedAsDomainKey() {
        // Arrange: ensure selectedCode is "" (Auto).
        XCTAssertEqual(manager.selectedCode, "")
        // Assert: the key is absent from defaults (removeObject was called, not set "").
        XCTAssertNil(defaults.object(forKey: "languages.selectedCode"))
    }

    func testNoContaminationWithStandardDefaults() {
        // Arrange: add German via this test's isolated manager.
        manager.addLanguage(code: "de")
        // Assert: UserDefaults.standard is unaffected.
        let standardManager = LanguageManager()
        XCTAssertFalse(
            standardManager.addedCodes.count > LanguageManager.shared.addedCodes.count,
            "Test writes must not leak into UserDefaults.standard",
        )
    }

    // MARK: - String.baseLanguageCode

    // The `baseLanguageCode` extension is defined alongside LanguageManager and is used
    // throughout the codebase to normalise BCP-47 identifiers returned by the system
    // (e.g. "en-US" from NSSpellChecker) down to a plain language subtag ("en").

    func testBaseLanguageCode_bareCode_returnsItself() {
        // A code with no region or script tag is returned unchanged.
        XCTAssertEqual("en".baseLanguageCode, "en")
    }

    func testBaseLanguageCode_hyphenSeparatedRegion() {
        // "en-US" → "en" (RFC 5646 hyphen separator).
        XCTAssertEqual("en-US".baseLanguageCode, "en")
    }

    func testBaseLanguageCode_underscoreSeparatedScript() {
        // "zh_Hans" → "zh" (underscore separator used by some system APIs).
        XCTAssertEqual("zh_Hans".baseLanguageCode, "zh")
    }

    func testBaseLanguageCode_hyphenSeparatedScript() {
        // "sr-Latn" → "sr" (script tag attached with a hyphen).
        XCTAssertEqual("sr-Latn".baseLanguageCode, "sr")
    }

    func testBaseLanguageCode_threePartBCP47() {
        // "zh-Hans-CN" → "zh" (language-script-region; only the first part is kept).
        XCTAssertEqual("zh-Hans-CN".baseLanguageCode, "zh")
    }

    func testBaseLanguageCode_german() {
        // Concrete example used in LanguageManager and SpellCheckPredictor at runtime.
        XCTAssertEqual("de-DE".baseLanguageCode, "de")
    }

    func testBaseLanguageCode_emptyString_returnsEmpty() {
        // Empty input: components(separatedBy:).first == "" (the empty first component).
        XCTAssertEqual("".baseLanguageCode, "")
    }

    func testBaseLanguageCode_noSeparator_returnsFullString() {
        // A string with no separator characters is returned unchanged via the `?? self` fallback.
        XCTAssertEqual("japanese".baseLanguageCode, "japanese")
    }

    func testBaseLanguageCode_separatorAtStart_returnsEmpty() {
        // If the string begins with the separator the first component is the empty string.
        XCTAssertEqual("-US".baseLanguageCode, "")
    }
}
