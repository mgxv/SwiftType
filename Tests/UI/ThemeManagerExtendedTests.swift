import AppKit
import Foundation
@testable import SwiftType
import XCTest

/// Extended ThemeManager tests covering areas not addressed by ThemeManagerTests.swift:
///   - themeDidChange notification is posted by every mutating operation
///   - manager.current reflects changes immediately (cache is rebuilt synchronously)
///   - highlightOpacity precision round-trip
///   - hexString(for:) returns the default when a key has never been set
///
/// DEVELOPER DECISION (marked inline):
///   `setGridCols(_:)` does not validate its argument before persisting.
///   An invalid value is stored in UserDefaults and a notification is posted, even though
///   `gridCols` will discard the stored value and return the default.
@MainActor final class ThemeManagerExtendedTests: XCTestCase {
    private var defaults: UserDefaults!
    private var manager: ThemeManager!
    private var suiteName: String!

    override func setUp() async throws {
        suiteName = "com.matthew.inputmethod.SwiftType.themeext.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
        manager = ThemeManager(defaults: defaults)
    }

    override func tearDown() async throws {
        defaults.removePersistentDomain(forName: suiteName)
    }

    // MARK: - Helpers

    /// Returns the number of `.themeDidChange` notifications posted during `block`.
    private func notificationCount(during block: () -> Void) -> Int {
        let counter = NotificationCounter()
        let token = NotificationCenter.default.addObserver(
            forName: .themeDidChange, object: nil, queue: nil,
        ) { _ in counter.increment() }
        block()
        NotificationCenter.default.removeObserver(token)
        return counter.count
    }

    // MARK: - themeDidChange notification from every setter

    func testSetColorPostsExactlyOneThemeDidChange() {
        let count = notificationCount { manager.setColor("#AABBCC", for: .backgroundColor) }
        XCTAssertEqual(count, 1)
    }

    func testSetColorPostsOneNotificationForEachKey() {
        // Every ThemeColorKey setter must post exactly one notification.
        for key in ThemeColorKey.allCases {
            let count = notificationCount { manager.setColor("#AABBCC", for: key) }
            XCTAssertEqual(count, 1,
                           "setColor(for: .\(key)) must post exactly one themeDidChange")
        }
    }

    func testSetBorderColorPostsExactlyOneThemeDidChange() {
        let count = notificationCount { manager.setColor("#AABBCC", for: .borderColor) }
        XCTAssertEqual(count, 1)
    }

    func testSetHighlightOpacityPostsExactlyOneThemeDidChange() {
        let count = notificationCount { manager.setHighlightOpacity(0.5) }
        XCTAssertEqual(count, 1)
    }

    func testSetGridColsPostsExactlyOneThemeDidChange() {
        let count = notificationCount { manager.setGridCols(6) }
        XCTAssertEqual(count, 1)
    }

    func testResetToDefaultsPostsExactlyOneThemeDidChange() {
        // resetToDefaults removes many keys then calls notifyThemeChange() once —
        // it must not emit one notification per key removed.
        let count = notificationCount { manager.resetToDefaults() }
        XCTAssertEqual(count, 1,
                       "resetToDefaults must post exactly one themeDidChange, not one per key")
    }

    func testThreeDistinctSettersPostThreeNotifications() {
        let count = notificationCount {
            manager.setColor("#AABBCC", for: .backgroundColor)
            manager.setColor("#112233", for: .borderColor)
            manager.setHighlightOpacity(0.3)
        }
        XCTAssertEqual(count, 3)
    }

    /// DEVELOPER DECISION: `setGridCols(_:)` does not validate before persisting.
    /// An invalid value is stored and a notification fires, even though `gridCols`
    /// getter discards it and returns the default.
    /// If the intent is "only persist valid values", add input validation in `setGridCols`.
    func testSetGridColsWithInvalidValueStillPostsNotification_DEVELOPER_DECISION() {
        let count = notificationCount { manager.setGridCols(99) }
        XCTAssertEqual(count, 1,
                       "DEVELOPER DECISION: invalid setGridCols still posts themeDidChange. " +
                           "Add pre-validation if this is undesirable.")
    }

    // MARK: - current Theme cache rebuilds synchronously

    func testCurrentBorderWidthIsAlwaysStandardWidth() {
        XCTAssertEqual(manager.current.border.width, ThemeBorder.standardWidth)
    }

    func testCurrentReflectsBorderColorImmediatelyAfterSet() {
        // Verify that `current` is rebuilt synchronously -- not deferred.
        let before = manager.current.border.color
        manager.setColor("#FF0000", for: .borderColor)
        let after = manager.current.border.color
        XCTAssertNotEqual(before, after)
    }

    // MARK: - highlightOpacity cache

    func testHighlightOpacityIsCachedImmediatelyAfterSet() {
        manager.setHighlightOpacity(0.42)
        XCTAssertEqual(manager.highlightOpacity, 0.42, accuracy: 0.001)
    }

    func testHighlightOpacityDefaultIsZero() {
        XCTAssertEqual(manager.highlightOpacity, ThemeManager.defaultHighlightOpacity,
                       accuracy: 0.001)
    }

    func testHighlightOpacityBoundaryValues() {
        // 0.0 and 1.0 are legal boundary values; both must round-trip.
        for value: CGFloat in [0.0, 0.25, 0.5, 0.75, 1.0] {
            manager.setHighlightOpacity(value)
            XCTAssertEqual(manager.highlightOpacity, value, accuracy: 0.001,
                           "highlightOpacity \(value) did not round-trip within tolerance")
        }
    }

    func testHighlightOpacityResetsAfterResetToDefaults() {
        manager.setHighlightOpacity(0.8)
        manager.resetToDefaults()
        XCTAssertEqual(manager.highlightOpacity, ThemeManager.defaultHighlightOpacity,
                       accuracy: 0.001)
    }

    // MARK: - gridCols — invalid value behaviour

    func testGridColsWithInvalidValueRetainsEffectiveDefault() {
        // setGridCols writes 99 but the getter validates against gridColsOptions.
        let before = manager.gridCols
        manager.setGridCols(99)
        XCTAssertEqual(manager.gridCols, before,
                       "An invalid setGridCols must not change the effective gridCols")
    }

    func testGridColsWithZeroRetainsEffectiveDefault() {
        let before = manager.gridCols
        manager.setGridCols(0)
        XCTAssertEqual(manager.gridCols, before)
    }

    func testGridColsWithNegativeRetainsEffectiveDefault() {
        let before = manager.gridCols
        manager.setGridCols(-1)
        XCTAssertEqual(manager.gridCols, before)
    }

    // MARK: - hexString(for:) — default when unset

    func testHexStringReturnsDefaultWhenKeyNotStored() {
        // Fresh instance with no values written: every key must return its defaultHex.
        for key in ThemeColorKey.allCases {
            XCTAssertEqual(manager.hexString(for: key), key.defaultHex,
                           "\(key.rawValue) should return defaultHex when not in UserDefaults")
        }
    }

    func testHexStringReturnsStoredValueAfterSetColor() {
        manager.setColor("#ABCDEF", for: .normalTextColor)
        XCTAssertEqual(manager.hexString(for: .normalTextColor), "#ABCDEF")
    }

    func testHexStringReturnsDefaultAfterResetToDefaults() {
        manager.setColor("#ABCDEF", for: .normalTextColor)
        manager.resetToDefaults()
        XCTAssertEqual(manager.hexString(for: .normalTextColor),
                       ThemeColorKey.normalTextColor.defaultHex)
    }

    func testHexStringUnaffectedKeyRetainsDefaultAfterUnrelatedSetColor() {
        // Setting one key must not affect the stored/default value of another key.
        manager.setColor("#AABBCC", for: .backgroundColor)
        XCTAssertEqual(manager.hexString(for: .normalTextColor),
                       ThemeColorKey.normalTextColor.defaultHex,
                       "Setting backgroundColor must not change normalTextColor")
    }
}
