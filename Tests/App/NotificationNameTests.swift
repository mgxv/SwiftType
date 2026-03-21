@testable import SwiftType
import XCTest

/// Tests for custom `Notification.Name` extensions.
///
/// Verifies that notification names are distinct (no accidental collision) and
/// that their raw strings match expectations (observers reference these by name).
@MainActor final class NotificationNameTests: XCTestCase {
    // MARK: - Uniqueness

    func testAllNotificationNamesAreDistinct() {
        let names: [Notification.Name] = [
            .themeDidChange,
            .appMappingsDidChange,
            .languagesDidChange,
            .activePredictionLanguageDidChange,
        ]
        let unique = Set(names)
        XCTAssertEqual(unique.count, names.count, "All notification names must be unique")
    }

    // MARK: - Raw string values

    func testThemeDidChangeRawValue() {
        XCTAssertEqual(Notification.Name.themeDidChange.rawValue, "themeDidChange")
    }

    func testAppMappingsDidChangeRawValue() {
        XCTAssertEqual(Notification.Name.appMappingsDidChange.rawValue, "appMappingsDidChange")
    }

    func testLanguagesDidChangeRawValue() {
        XCTAssertEqual(Notification.Name.languagesDidChange.rawValue, "languagesDidChange")
    }

    func testActivePredictionLanguageDidChangeRawValue() {
        XCTAssertEqual(Notification.Name.activePredictionLanguageDidChange.rawValue, "activePredictionLanguageDidChange")
    }
}
