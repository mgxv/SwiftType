@testable import SwiftType
import XCTest

/// Tests for the auto-capitalization enabled setting in SettingsManager.
@MainActor final class SettingsManagerAutoCapTests: XCTestCase {
    private var defaults: UserDefaults!
    private var manager: SettingsManager!
    private var suiteName: String!

    override func setUp() async throws {
        suiteName = "com.matthew.inputmethod.SwiftType.autocap.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
        manager = SettingsManager(defaults: defaults)
    }

    override func tearDown() async throws {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        manager = nil
    }

    // MARK: - Default Value

    func testDefaultIsTrue() {
        XCTAssertTrue(manager.isAutoCapitalizationEnabled,
                      "Auto capitalization should be enabled by default")
    }

    // MARK: - Persistence

    func testDisablePersists() {
        manager.setAutoCapitalizationEnabled(false)
        XCTAssertFalse(manager.isAutoCapitalizationEnabled)
    }

    func testReEnablePersists() {
        manager.setAutoCapitalizationEnabled(false)
        manager.setAutoCapitalizationEnabled(true)
        XCTAssertTrue(manager.isAutoCapitalizationEnabled)
    }

    func testPersistsAcrossInstances() {
        manager.setAutoCapitalizationEnabled(false)
        let secondManager = SettingsManager(defaults: defaults)
        XCTAssertFalse(secondManager.isAutoCapitalizationEnabled,
                       "Setting should survive re-instantiation from the same UserDefaults")
    }

    // MARK: - Notification

    func testNotificationPostedOnChange() {
        let counter = NotificationCounter()
        let token = NotificationCenter.default.addObserver(
            forName: .autoCapitalizationSettingDidChange,
            object: nil, queue: nil,
        ) { _ in counter.increment() }
        defer { NotificationCenter.default.removeObserver(token) }

        manager.setAutoCapitalizationEnabled(false)
        XCTAssertEqual(counter.count, 1)

        manager.setAutoCapitalizationEnabled(true)
        XCTAssertEqual(counter.count, 2)
    }

    func testNoNotificationWhenValueUnchanged() {
        let counter = NotificationCounter()
        let token = NotificationCenter.default.addObserver(
            forName: .autoCapitalizationSettingDidChange,
            object: nil, queue: nil,
        ) { _ in counter.increment() }
        defer { NotificationCenter.default.removeObserver(token) }

        manager.setAutoCapitalizationEnabled(true)
        XCTAssertEqual(counter.count, 0,
                       "Setting to the current value should not post a notification")
    }
}
