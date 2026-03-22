@testable import SwiftType
import XCTest

/// Tests for the next-word predictions enabled setting in SettingsManager.
@MainActor final class SettingsManagerNextWordTests: XCTestCase {
    private var defaults: UserDefaults!
    private var manager: SettingsManager!
    private var suiteName: String!

    override func setUp() async throws {
        suiteName = "com.matthew.inputmethod.SwiftType.nextword.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
        manager = SettingsManager(defaults: defaults)
    }

    override func tearDown() async throws {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        manager = nil
    }

    // MARK: - Default Value

    func testDefaultIsFalse() {
        XCTAssertFalse(manager.isNextWordPredictionsEnabled,
                       "Next-word predictions should be disabled by default")
    }

    // MARK: - Persistence

    func testDisablePersists() {
        manager.setNextWordPredictionsEnabled(false)
        XCTAssertFalse(manager.isNextWordPredictionsEnabled)
    }

    func testReEnablePersists() {
        manager.setNextWordPredictionsEnabled(false)
        manager.setNextWordPredictionsEnabled(true)
        XCTAssertTrue(manager.isNextWordPredictionsEnabled)
    }

    func testPersistsAcrossInstances() {
        manager.setNextWordPredictionsEnabled(false)
        let secondManager = SettingsManager(defaults: defaults)
        XCTAssertFalse(secondManager.isNextWordPredictionsEnabled,
                       "Setting should survive re-instantiation from the same UserDefaults")
    }

    // MARK: - Notification

    func testNotificationPostedOnChange() {
        let counter = NotificationCounter()
        let token = NotificationCenter.default.addObserver(
            forName: .nextWordPredictionsSettingDidChange,
            object: nil, queue: nil,
        ) { _ in counter.increment() }
        defer { NotificationCenter.default.removeObserver(token) }

        manager.setNextWordPredictionsEnabled(true)
        XCTAssertEqual(counter.count, 1)

        manager.setNextWordPredictionsEnabled(false)
        XCTAssertEqual(counter.count, 2)
    }

    func testNoNotificationWhenValueUnchanged() {
        let counter = NotificationCounter()
        let token = NotificationCenter.default.addObserver(
            forName: .nextWordPredictionsSettingDidChange,
            object: nil, queue: nil,
        ) { _ in counter.increment() }
        defer { NotificationCenter.default.removeObserver(token) }

        manager.setNextWordPredictionsEnabled(false)
        XCTAssertEqual(counter.count, 0,
                       "Setting to the current value should not post a notification")
    }
}
