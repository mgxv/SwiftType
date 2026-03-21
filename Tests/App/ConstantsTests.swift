@testable import SwiftType
import XCTest

/// Tests for `Constants` computed properties and static values.
@MainActor final class ConstantsTests: XCTestCase {
    // MARK: - Static bounds

    func testMaxSupportedGridColsIsAtLeastSeven() {
        XCTAssertGreaterThanOrEqual(Constants.maxSupportedGridCols, 7)
    }

    func testMaxSupportedGridRowsIsAtLeastFive() {
        XCTAssertGreaterThanOrEqual(Constants.maxSupportedGridRows, 5)
    }

    func testReplacementNotFoundLocationIsNSNotFound() {
        XCTAssertEqual(Constants.replacementNotFound.location, NSNotFound)
    }

    func testReplacementNotFoundLengthIsZero() {
        XCTAssertEqual(Constants.replacementNotFound.length, 0)
    }

    // MARK: - Computed properties

    func testGridMaxVisibleColsMatchesThemeManager() {
        XCTAssertEqual(Constants.gridMaxVisibleCols, ThemeManager.shared.gridCols)
    }

    func testGridMaxVisibleRowsMatchesThemeManager() {
        XCTAssertEqual(Constants.gridMaxVisibleRows, ThemeManager.shared.gridRows)
    }

    func testGridInitialPageSizeIsProductOfColsAndRows() {
        XCTAssertEqual(
            Constants.gridInitialPageSize,
            Constants.gridMaxVisibleCols * Constants.gridMaxVisibleRows,
        )
    }

    func testGridInitialPageSizeIsPositive() {
        XCTAssertGreaterThan(Constants.gridInitialPageSize, 0)
    }

    // MARK: - Consistency with ThemeManager options

    func testMaxSupportedGridColsCoversAllThemeOptions() {
        for option in ThemeManager.gridColsOptions {
            XCTAssertLessThanOrEqual(option, Constants.maxSupportedGridCols,
                                     "gridColsOption \(option) exceeds maxSupportedGridCols")
        }
    }

    func testMaxSupportedGridRowsCoversAllThemeRowOptions() {
        for option in ThemeManager.gridRowsOptions {
            XCTAssertLessThanOrEqual(option, Constants.maxSupportedGridRows,
                                     "gridRowsOption \(option) exceeds maxSupportedGridRows")
        }
    }
}
