@testable import SwiftType
import XCTest

/// Tests for the border color in `ThemeManager`. Border color is a standard
/// `ThemeColorKey` (`.borderColor`) with default `#1B1B1B`. Accessed via
/// `setColor(_:for: .borderColor)` and `hexString(for: .borderColor)`.
@MainActor final class ThemeManagerBorderColorTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!
    private var manager: ThemeManager!

    override func setUp() async throws {
        suiteName = "com.matthew.inputmethod.SwiftType.bordertests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
        manager = ThemeManager(defaults: defaults)
    }

    override func tearDown() async throws {
        defaults.removePersistentDomain(forName: suiteName)
    }

    // MARK: - Defaults

    func testBorderColorDefaultHex() {
        XCTAssertEqual(ThemeColorKey.borderColor.defaultHex, "#1B1B1B")
    }

    func testBorderColorDefaultWhenUnset() {
        XCTAssertEqual(manager.hexString(for: .borderColor), ThemeColorKey.borderColor.defaultHex)
    }

    func testBorderColorIsIndependentOfHighlightTextColor() {
        manager.setColor("#00FF00", for: .highlightTextColor)
        // Border color has its own default, not linked to highlightTextColor.
        XCTAssertEqual(manager.hexString(for: .borderColor), ThemeColorKey.borderColor.defaultHex)
    }

    func testExplicitBorderColor() {
        manager.setColor("#FF0000", for: .borderColor)
        XCTAssertEqual(manager.hexString(for: .borderColor), "#FF0000")
    }

    // MARK: - buildTheme uses correct border color

    func testBorderThemeUsesExplicitBorderColor() {
        manager.setColor("#123456", for: .borderColor)

        let theme = manager.current
        XCTAssertEqual(theme.border.width, ThemeBorder.standardWidth)
    }

    func testBorderAlwaysHasStandardWidth() {
        let theme = manager.current
        XCTAssertEqual(theme.border.width, ThemeBorder.standardWidth)
    }

    // MARK: - Reset clears border color

    func testResetClearsBorderColor() {
        manager.setColor("#FF0000", for: .borderColor)
        manager.resetToDefaults()
        XCTAssertEqual(manager.hexString(for: .borderColor), ThemeColorKey.borderColor.defaultHex)
    }

    // MARK: - Invalid border color hex

    func testInvalidBorderColorHexIsRejected() {
        manager.setColor("not-a-hex", for: .borderColor)
        // Invalid hex is rejected — falls back to the default chain.
        XCTAssertEqual(manager.hexString(for: .borderColor), ThemeColorKey.borderColor.defaultHex)
    }

    func testInvalidBorderColorDoesNotOverwriteValidColor() {
        manager.setColor("#112233", for: .borderColor)
        manager.setColor("not-a-hex", for: .borderColor)
        // The previously valid color is preserved.
        XCTAssertEqual(manager.hexString(for: .borderColor), "#112233")
    }
}
