@testable import SwiftType
import XCTest

/// Tests for `LanguageManager.selectLanguage(code:)` and the interaction between
/// selection, removal, and notification contracts. Complements the existing
/// `LanguageManagerTests` by focusing on selection edge cases and derived properties.
@MainActor final class LanguageManagerSelectionTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!

    override func setUp() async throws {
        suiteName = "com.matthew.inputmethod.SwiftType.langselectiontests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
    }

    override func tearDown() async throws {
        defaults.removePersistentDomain(forName: suiteName)
    }

    private func makeManager(codes: [String] = ["en"], selected: String = "") -> LanguageManager {
        defaults.set(codes, forKey: "languages.addedCodes")
        if selected.isEmpty {
            defaults.removeObject(forKey: "languages.selectedCode")
        } else {
            defaults.set(selected, forKey: "languages.selectedCode")
        }
        return LanguageManager(defaults: defaults)
    }

    // MARK: - selectLanguage basic contract

    func testSelectLanguageWithValidCodePins() {
        let mgr = makeManager(codes: ["en", "de"])
        mgr.selectLanguage(code: "de")
        XCTAssertEqual(mgr.selectedCode, "de")
    }

    func testSelectLanguageWithEmptyCodeSelectsAuto() {
        let mgr = makeManager(codes: ["en", "de"], selected: "de")
        mgr.selectLanguage(code: "")
        XCTAssertEqual(mgr.selectedCode, "")
    }

    func testSelectLanguageSameCodeIsNoop() {
        let mgr = makeManager(codes: ["en"], selected: "en")
        var notified = false
        let token = NotificationCenter.default.addObserver(
            forName: .activePredictionLanguageDidChange, object: nil, queue: nil,
        ) { _ in notified = true }
        defer { NotificationCenter.default.removeObserver(token) }

        mgr.selectLanguage(code: "en")
        XCTAssertFalse(notified, "Selecting the already-selected code must not notify")
    }

    func testSelectLanguageNotInAddedCodesIsNoop() {
        let mgr = makeManager(codes: ["en"])
        mgr.selectLanguage(code: "de")
        XCTAssertEqual(mgr.selectedCode, "", "Cannot select a code not in addedCodes")
    }

    // MARK: - selectLanguage persistence

    func testSelectLanguagePersists() {
        let mgr = makeManager(codes: ["en", "de"])
        mgr.selectLanguage(code: "de")

        let mgr2 = LanguageManager(defaults: defaults)
        XCTAssertEqual(mgr2.selectedCode, "de")
    }

    func testSelectAutoRemovesKey() {
        let mgr = makeManager(codes: ["en", "de"], selected: "de")
        mgr.selectLanguage(code: "")

        // When Auto is selected, the key should be absent (not stored as "")
        XCTAssertNil(defaults.string(forKey: "languages.selectedCode"))
    }

    // MARK: - removeLanguage resets pinned code

    func testRemovePinnedLanguageResetsToAuto() {
        let mgr = makeManager(codes: ["en", "de"], selected: "de")
        mgr.removeLanguage(at: 1) // remove "de"
        XCTAssertEqual(mgr.selectedCode, "")
    }

    func testRemoveNonPinnedLanguageKeepsPinned() {
        let mgr = makeManager(codes: ["en", "de"], selected: "de")
        mgr.removeLanguage(at: 0) // remove "en"
        XCTAssertEqual(mgr.selectedCode, "de")
    }

    func testRemovePinnedLanguagePostsActiveLanguageNotification() {
        let mgr = makeManager(codes: ["en", "de"], selected: "de")
        let counter = NotificationCounter()
        let token = NotificationCenter.default.addObserver(
            forName: .activePredictionLanguageDidChange, object: nil, queue: nil,
        ) { _ in counter.increment() }
        defer { NotificationCenter.default.removeObserver(token) }

        mgr.removeLanguage(at: 1)
        XCTAssertEqual(counter.count, 1)
    }

    // MARK: - addedDescriptors ordering

    func testAddedDescriptorsMatchesInsertionOrder() {
        let mgr = makeManager(codes: ["de", "en"])
        let codes = mgr.addedDescriptors.map(\.code)
        XCTAssertEqual(codes, ["de", "en"])
    }

    func testAddedDescriptorsSkipsUnknownCodes() {
        let mgr = makeManager(codes: ["en", "xx", "de"])
        let codes = mgr.addedDescriptors.map(\.code)
        XCTAssertEqual(codes, ["en", "de"])
    }

    // MARK: - availableToAdd

    func testAvailableToAddExcludesAddedCodes() {
        let mgr = makeManager(codes: ["en"])
        let available = mgr.availableToAdd.map(\.code)
        XCTAssertFalse(available.contains("en"))
        XCTAssertTrue(available.contains("de"))
    }

    func testAvailableToAddIsEmptyWhenAllAdded() {
        let allCodes = LanguageDescriptor.all.map(\.code)
        let mgr = makeManager(codes: allCodes)
        XCTAssertTrue(mgr.availableToAdd.isEmpty)
    }

    // MARK: - moveLanguage does not notify

    func testMoveLanguageDoesNotPostNotification() {
        let mgr = makeManager(codes: ["en", "de"])
        var languagesChanged = false
        var activeChanged = false
        let t1 = NotificationCenter.default.addObserver(
            forName: .languagesDidChange, object: nil, queue: nil,
        ) { _ in languagesChanged = true }
        let t2 = NotificationCenter.default.addObserver(
            forName: .activePredictionLanguageDidChange, object: nil, queue: nil,
        ) { _ in activeChanged = true }
        defer {
            NotificationCenter.default.removeObserver(t1)
            NotificationCenter.default.removeObserver(t2)
        }

        mgr.moveLanguage(from: 0, to: 1)
        XCTAssertFalse(languagesChanged)
        XCTAssertFalse(activeChanged)
    }

    func testMoveLanguagePersists() {
        let mgr = makeManager(codes: ["en", "de"])
        mgr.moveLanguage(from: 0, to: 1)

        let mgr2 = LanguageManager(defaults: defaults)
        XCTAssertEqual(mgr2.addedCodes, ["de", "en"])
    }
}
