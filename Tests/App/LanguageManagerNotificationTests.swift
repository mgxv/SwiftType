@testable import SwiftType
import XCTest

/// Tests for LanguageManager notification edge cases not covered by LanguageManagerTests.
///
/// LanguageManagerTests verifies *state* changes on removeLanguage / addLanguage.
/// This file locks in the *notification* contract — specifically which notifications
/// fire (and which do NOT fire) in the less-obvious code paths.
@MainActor final class LanguageManagerNotificationTests: XCTestCase {
    private var defaults: UserDefaults!
    private var manager: LanguageManager!
    private var suiteName: String!

    override func setUp() async throws {
        suiteName = "com.matthew.inputmethod.SwiftType.langnotif.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
        manager = LanguageManager(defaults: defaults)
    }

    override func tearDown() async throws {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        manager = nil
    }

    // MARK: - Helpers

    private func count(
        _ name: Notification.Name,
        during block: () -> Void,
    ) -> Int {
        let counter = NotificationCounter()
        let token = NotificationCenter.default.addObserver(
            forName: name, object: nil, queue: nil,
        ) { _ in counter.increment() }
        block()
        NotificationCenter.default.removeObserver(token)
        return counter.count
    }

    // MARK: - removeLanguage — activePredictionLanguageDidChange

    func testRemovePinnedLanguagePostsActivePredictionLanguageDidChange() {
        // Arrange: add German and pin it.
        manager.addLanguage(code: "de")
        manager.selectLanguage(code: "de")
        // Act / Assert: removing the pinned language must notify the predictor.
        let n = count(.activePredictionLanguageDidChange) {
            manager.removeLanguage(at: 1)
        }
        XCTAssertEqual(n, 1,
                       "Removing the pinned language must post .activePredictionLanguageDidChange")
    }

    func testRemoveNonPinnedLanguageDoesNotPostActivePredictionLanguageDidChange() {
        // Arrange: add German, pin English (not German).
        manager.addLanguage(code: "de")
        manager.selectLanguage(code: "en")
        // Act / Assert: removing a language that is NOT pinned must not trigger a
        // predictor refresh — only the languages list changed, not the active language.
        let n = count(.activePredictionLanguageDidChange) {
            manager.removeLanguage(at: 1) // removes "de", which is not selected
        }
        XCTAssertEqual(n, 0,
                       "Removing a non-pinned language must not post .activePredictionLanguageDidChange")
    }

    func testRemovePinnedLanguagePostsBothNotifications() {
        // Arrange: pin German.
        manager.addLanguage(code: "de")
        manager.selectLanguage(code: "de")
        // Act: count BOTH notifications in a single removal.
        let activeCounter = NotificationCounter()
        let listCounter = NotificationCounter()
        let t1 = NotificationCenter.default.addObserver(
            forName: .activePredictionLanguageDidChange, object: nil, queue: nil,
        ) { _ in activeCounter.increment() }
        let t2 = NotificationCenter.default.addObserver(
            forName: .languagesDidChange, object: nil, queue: nil,
        ) { _ in listCounter.increment() }
        manager.removeLanguage(at: 1)
        NotificationCenter.default.removeObserver(t1)
        NotificationCenter.default.removeObserver(t2)
        // Assert: both must fire exactly once.
        XCTAssertEqual(activeCounter.count, 1, "Expected one .activePredictionLanguageDidChange")
        XCTAssertEqual(listCounter.count, 1, "Expected one .languagesDidChange")
    }

    // MARK: - addLanguage — unknown code suppresses notification

    func testAddLanguageUnknownCodeDoesNotPostLanguagesDidChange() {
        // Arrange: "xx" has no TypingRules entry.
        // Act / Assert: the rejection path must not post a notification.
        let n = count(.languagesDidChange) {
            manager.addLanguage(code: "xx")
        }
        XCTAssertEqual(n, 0,
                       "addLanguage with an unknown code must not post .languagesDidChange")
    }

    func testAddLanguageDuplicateCodeDoesNotPostLanguagesDidChange() {
        // Arrange: "en" is already present.
        let n = count(.languagesDidChange) {
            manager.addLanguage(code: "en")
        }
        XCTAssertEqual(n, 0,
                       "addLanguage with a duplicate code must not post .languagesDidChange")
    }

    // MARK: - addedDescriptors ordering

    func testAddedDescriptorsOrderMatchesAddedCodesOrder() {
        // Arrange: add German after English — order in addedCodes is ["en", "de"].
        manager.addLanguage(code: "de")
        // Act.
        let descriptors = manager.addedDescriptors
        // Assert: descriptor codes match addedCodes in the same order.
        XCTAssertEqual(descriptors.map(\.code), manager.addedCodes,
                       "addedDescriptors must preserve the order of addedCodes")
    }

    func testAddedDescriptorsOrderAfterMove() {
        // Arrange: start with ["en", "de"], then move "de" to index 0 → ["de", "en"].
        manager.addLanguage(code: "de")
        manager.moveLanguage(from: 1, to: 0)
        // Act.
        let descriptors = manager.addedDescriptors
        // Assert: descriptors follow the new order.
        XCTAssertEqual(descriptors[0].code, "de")
        XCTAssertEqual(descriptors[1].code, "en")
    }
}
