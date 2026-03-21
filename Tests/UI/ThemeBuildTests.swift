import AppKit
@testable import SwiftType
import XCTest

/// Tests for `ThemeManager.buildTheme` (via the `.current` cache), verifying that
/// customised values propagate to the Theme struct and that invalid hex is rejected.
@MainActor final class ThemeBuildTests: XCTestCase {
    private var defaults: UserDefaults!
    private var manager: ThemeManager!
    private var suiteName: String!

    override func setUp() async throws {
        suiteName = "com.matthew.inputmethod.SwiftType.themebuild.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
        manager = ThemeManager(defaults: defaults)
    }

    override func tearDown() async throws {
        defaults.removePersistentDomain(forName: suiteName)
    }

    // MARK: - Default theme

    func testDefaultThemeBorderHasStandardWidth() {
        XCTAssertEqual(manager.current.border.width, ThemeBorder.standardWidth)
    }

    func testDefaultCornerRadius() {
        XCTAssertEqual(manager.current.cornerRadius, 6)
    }

    func testDefaultFontSizes() {
        XCTAssertEqual(manager.current.wordFontSize, 14)
        XCTAssertEqual(manager.current.numberFontSize, 11)
    }

    // MARK: - Border always uses standard width

    func testBorderAlwaysHasStandardWidth() {
        XCTAssertEqual(manager.current.border.width, ThemeBorder.standardWidth)
    }

    func testBorderUsesEffectiveBorderColor() {
        manager.setColor("#FF0000", for: .borderColor)
        let theme = manager.current
        XCTAssertEqual(theme.border.width, ThemeBorder.standardWidth)
    }

    // MARK: - Invalid hex rejection

    func testInvalidHexIsRejectedAndDefaultPreserved() {
        manager.setColor("not-a-hex", for: .backgroundColor)
        // setColor rejects invalid hex — the default remains.
        XCTAssertEqual(manager.hexString(for: .backgroundColor), ThemeColorKey.backgroundColor.defaultHex)
    }

    // MARK: - Color customisation propagates

    func testCustomBackgroundColorPropagates() throws {
        manager.setColor("#FF0000", for: .backgroundColor)
        let bg = try XCTUnwrap(manager.current.backgroundColor.usingColorSpace(.sRGB))
        XCTAssertEqual(bg.redComponent, 1.0, accuracy: 0.01)
        XCTAssertEqual(bg.greenComponent, 0.0, accuracy: 0.01)
        XCTAssertEqual(bg.blueComponent, 0.0, accuracy: 0.01)
    }

    func testCustomHighlightTextColorPropagates() throws {
        manager.setColor("#00FF00", for: .highlightTextColor)
        let color = try XCTUnwrap(manager.current.highlightTextColor.usingColorSpace(.sRGB))
        XCTAssertEqual(color.greenComponent, 1.0, accuracy: 0.01)
    }

    // MARK: - highlightOpacity

    func testDefaultHighlightOpacityIsZero() {
        XCTAssertEqual(manager.highlightOpacity, 0, accuracy: 0.001)
    }

    func testHighlightOpacityPersistsAcrossInstances() {
        manager.setHighlightOpacity(0.5)
        let m2 = ThemeManager(defaults: defaults)
        XCTAssertEqual(m2.highlightOpacity, 0.5, accuracy: 0.001)
    }
}
