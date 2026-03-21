import AppKit
@testable import SwiftType
import XCTest

// Tests for the pure value types in Theme.swift: ThemeBorder and Theme.
// None of these touch UserDefaults or any shared singletons, so no setUp/tearDown needed.

@MainActor final class ThemeTests: XCTestCase {
    // MARK: - ThemeBorder

    func testThemeBorderStandardWidthDefault() {
        XCTAssertEqual(ThemeBorder.standardWidth, 2)
    }

    func testThemeBorderMemberwiseInit() {
        let border = ThemeBorder(color: .red, width: 2)
        XCTAssertEqual(border.width, 2)
    }

    // MARK: - Theme.defaultTheme

    func testDefaultThemeCornerRadius() {
        XCTAssertEqual(Theme.defaultTheme.cornerRadius, 6)
    }

    func testDefaultThemeFontWeightIsMedium() {
        XCTAssertEqual(Theme.defaultTheme.fontWeight, .medium)
    }

    func testDefaultThemeNumberFontWeightIsMedium() {
        XCTAssertEqual(Theme.defaultTheme.numberFontWeight, .medium)
    }

    func testDefaultThemeWordFontSize() {
        XCTAssertEqual(Theme.defaultTheme.wordFontSize, 14)
    }

    func testDefaultThemeNumberFontSize() {
        XCTAssertEqual(Theme.defaultTheme.numberFontSize, 11)
    }

    func testDefaultThemeBorderWidthIsStandard() {
        XCTAssertEqual(Theme.defaultTheme.border.width, ThemeBorder.standardWidth)
    }

    // MARK: - Theme default font sizes via memberwise init

    func testThemeDefaultFontSizesApplyWhenOmitted() {
        // wordFontSize and numberFontSize have defaults in the init; verify they apply.
        let theme = Theme(
            backgroundColor: .black,
            border: ThemeBorder(color: .orange, width: ThemeBorder.standardWidth),
            cornerRadius: 8,
            highlightTextColor: .orange,
            highlightColor: .purple,
            normalTextColor: .white,
            numberLabelColor: .gray,
            separatorColor: .darkGray,
            fontWeight: .medium,
            numberFontWeight: .medium,
        )
        XCTAssertEqual(theme.wordFontSize, 14)
        XCTAssertEqual(theme.numberFontSize, 11)
    }

    func testThemeCustomFontSizes() {
        let theme = Theme(
            backgroundColor: .black,
            border: ThemeBorder(color: .orange, width: ThemeBorder.standardWidth),
            cornerRadius: 8,
            highlightTextColor: .orange,
            highlightColor: .purple,
            normalTextColor: .white,
            numberLabelColor: .gray,
            separatorColor: .darkGray,
            fontWeight: .regular,
            numberFontWeight: .light,
            wordFontSize: 16,
            numberFontSize: 12,
        )
        XCTAssertEqual(theme.wordFontSize, 16)
        XCTAssertEqual(theme.numberFontSize, 12)
        XCTAssertEqual(theme.fontWeight, NSFont.Weight.regular)
        XCTAssertEqual(theme.numberFontWeight, NSFont.Weight.light)
    }

    // MARK: - Constants

    func testMaxSupportedGridColsIsSeven() {
        XCTAssertEqual(Constants.maxSupportedGridCols, 7)
    }

    func testMaxSupportedGridColsCoversAllCandidateCountOptions() {
        // All valid user-configurable counts must fit within the pre-allocated label slots.
        for count in ThemeManager.gridColsOptions {
            XCTAssertLessThanOrEqual(count, Constants.maxSupportedGridCols,
                                     "\(count) exceeds maxSupportedGridCols")
        }
    }

    func testReplacementNotFoundLocation() {
        XCTAssertEqual(Constants.replacementNotFound.location, NSNotFound)
    }

    func testReplacementNotFoundLength() {
        XCTAssertEqual(Constants.replacementNotFound.length, 0)
    }

    // MARK: - ThemeColorKey

    func testThemeColorKeyRawValuesMatchUserDefaultsKeys() {
        // Raw values are the UserDefaults keys — changes are breaking.
        XCTAssertEqual(ThemeColorKey.backgroundColor.rawValue, "theme.backgroundColor")
        XCTAssertEqual(ThemeColorKey.normalTextColor.rawValue, "theme.normalTextColor")
        XCTAssertEqual(ThemeColorKey.numberLabelColor.rawValue, "theme.numberLabelColor")
        XCTAssertEqual(ThemeColorKey.highlightTextColor.rawValue, "theme.highlightTextColor")
        XCTAssertEqual(ThemeColorKey.highlightColor.rawValue, "theme.highlightColor")
    }

    func testThemeColorKeyDefaultHexStrings() {
        // Lock in the shipping defaults — changes require migration consideration.
        XCTAssertEqual(ThemeColorKey.backgroundColor.defaultHex, "#1B1B1B")
        XCTAssertEqual(ThemeColorKey.normalTextColor.defaultHex, "#FCFCFC")
        XCTAssertEqual(ThemeColorKey.numberLabelColor.defaultHex, "#A0796A")
        XCTAssertEqual(ThemeColorKey.highlightTextColor.defaultHex, "#FF9900")
        XCTAssertEqual(ThemeColorKey.highlightColor.defaultHex, "#533566")
    }

    func testThemeColorKeyDisplayNames() {
        XCTAssertEqual(ThemeColorKey.backgroundColor.displayName, "Background Color")
        XCTAssertEqual(ThemeColorKey.normalTextColor.displayName, "Text Color")
        XCTAssertEqual(ThemeColorKey.numberLabelColor.displayName, "Number Label Color")
        XCTAssertEqual(ThemeColorKey.highlightTextColor.displayName, "Selected Word Color")
        XCTAssertEqual(ThemeColorKey.highlightColor.displayName, "Highlight Color")
    }

    func testThemeColorKeyHasSevenCases() {
        // Changing this count is a breaking change to the Customize settings UI.
        XCTAssertEqual(ThemeColorKey.allCases.count, 7)
    }
}
