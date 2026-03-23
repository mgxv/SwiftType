import AppKit
@testable import SwiftType
import XCTest

@MainActor final class ThemeManagerTests: XCTestCase {
    private var defaults: UserDefaults!
    private var manager: ThemeManager!
    private var suiteName: String!

    override func setUp() async throws {
        suiteName = "com.matthew.inputmethod.SwiftType.themetests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
        manager = ThemeManager(defaults: defaults)
    }

    override func tearDown() async throws {
        defaults.removePersistentDomain(forName: suiteName)
    }

    // MARK: - Default hex values

    func testAllDefaultHexValuesParseToNonNilColor() {
        for key in ThemeColorKey.allCases {
            XCTAssertNotNil(NSColor(hexString: key.defaultHex),
                            "\(key.rawValue) defaultHex '\(key.defaultHex)' failed to parse")
        }
    }

    // MARK: - gridColsOptions

    func testGridColsOptionsContainsDefaultGridCols() {
        XCTAssertTrue(ThemeManager.gridColsOptions.contains(ThemeManager.defaultGridCols))
    }

    func testGridColsOptionsAreAllPositive() {
        for count in ThemeManager.gridColsOptions {
            XCTAssertGreaterThan(count, 0)
        }
    }

    func testGridColsOptionsAreSorted() {
        let options = ThemeManager.gridColsOptions
        XCTAssertEqual(options, options.sorted())
    }

    // MARK: - resetToDefaults

    func testResetToDefaultsRestoresAllColors() {
        // Dirty a color
        manager.setColor("#123456", for: .backgroundColor)
        XCTAssertEqual(manager.hexString(for: .backgroundColor), "#123456")

        manager.resetToDefaults()

        for key in ThemeColorKey.allCases {
            XCTAssertEqual(manager.hexString(for: key), key.defaultHex,
                           "\(key.rawValue) was not restored to default after reset")
        }
    }

    func testResetToDefaultsRestoresHighlightOpacity() {
        manager.setHighlightOpacity(0.9)
        manager.resetToDefaults()
        XCTAssertEqual(manager.highlightOpacity, ThemeManager.defaultHighlightOpacity, accuracy: 0.001)
    }

    func testResetToDefaultsRestoresGridCols() {
        manager.setGridCols(6)
        manager.resetToDefaults()
        XCTAssertEqual(manager.gridCols, ThemeManager.defaultGridCols)
    }

    // MARK: - setColor / hexString

    func testSetAndReadColor() {
        manager.setColor("#AABBCC", for: .normalTextColor)
        XCTAssertEqual(manager.hexString(for: .normalTextColor), "#AABBCC")
    }

    // MARK: - Persistence round-trips

    func testHighlightOpacityRoundTrip() {
        manager.setHighlightOpacity(0.75)
        let m2 = ThemeManager(defaults: defaults)
        XCTAssertEqual(m2.highlightOpacity, 0.75, accuracy: 0.001)
    }

    func testBorderColorRoundTrip() {
        manager.setColor("#AABBCC", for: .borderColor)
        let m2 = ThemeManager(defaults: defaults)
        XCTAssertEqual(m2.hexString(for: .borderColor), "#AABBCC")
    }

    // MARK: - Border color

    func testBorderColorDefault() {
        XCTAssertEqual(manager.hexString(for: .borderColor), ThemeColorKey.borderColor.defaultHex)
    }

    func testBorderColorIsIndependentOfHighlightTextColor() {
        manager.setColor("#112233", for: .highlightTextColor)
        XCTAssertEqual(manager.hexString(for: .borderColor), ThemeColorKey.borderColor.defaultHex)
    }

    func testExplicitBorderColor() {
        manager.setColor("#AABBCC", for: .borderColor)
        XCTAssertEqual(manager.hexString(for: .borderColor), "#AABBCC")
    }

    func testBorderColorResetsToDefault() {
        manager.setColor("#AABBCC", for: .borderColor)
        manager.resetToDefaults()
        XCTAssertEqual(manager.hexString(for: .borderColor), ThemeColorKey.borderColor.defaultHex)
    }

    // MARK: - gridCols validation

    func testGridColsFallsBackToDefaultForInvalidValue() {
        defaults.set(999, forKey: "theme.gridCols")
        let m = ThemeManager(defaults: defaults)
        XCTAssertEqual(m.gridCols, ThemeManager.defaultGridCols)
    }

    func testGridColsAcceptsValidOption() {
        for count in ThemeManager.gridColsOptions {
            manager.setGridCols(count)
            XCTAssertEqual(manager.gridCols, count)
        }
    }
}
