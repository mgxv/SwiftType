@testable import SwiftType
import XCTest

/// Tests for `GridCandidateState.clampVisibleWindow()`, `maxPredictionIndexNeeded(throughRow:)`,
/// and `columnCountForRow(_:)` — geometry helpers that drive lazy loading and visible-window
/// scrolling. These are pure value-type methods with no AppKit dependencies.
@MainActor final class GridCandidateStateClampTests: XCTestCase {
    // MARK: - Helpers

    private func makeState(
        predictionCount: Int,
        hasLiteral: Bool = false,
        columnCount: Int = 5,
        maxVisibleRows: Int = 3,
    ) -> GridCandidateState {
        let predictions = (0 ..< predictionCount).map { "p\($0)" }
        let unified = hasLiteral ? ["lit"] + predictions : predictions
        return GridCandidateState(
            columnCount: columnCount,
            hasLiteral: hasLiteral,
            maxVisibleRows: maxVisibleRows,
            predictions: unified,
        )
    }

    // MARK: - clampVisibleWindow

    func testClampDoesNothingWhenActiveRowInsideWindow() {
        // Arrange: activeRow 1, visible window [0, 2] — row 1 is inside.
        var s = makeState(predictionCount: 20)
        s.isExpanded = true
        s.activeRow = 1
        s.visibleRowOffset = 0

        // Act
        s.clampVisibleWindow()

        // Assert
        XCTAssertEqual(s.visibleRowOffset, 0)
    }

    func testClampScrollsDownWhenActiveRowBelowWindow() {
        // Arrange: window shows rows [0, 2], activeRow = 3 is below.
        var s = makeState(predictionCount: 25)
        s.isExpanded = true
        s.activeRow = 3
        s.visibleRowOffset = 0

        // Act
        s.clampVisibleWindow()

        // Assert: offset = 3 - 3 + 1 = 1
        XCTAssertEqual(s.visibleRowOffset, 1)
    }

    func testClampScrollsUpWhenActiveRowAboveWindow() {
        // Arrange: window shows rows [3, 5], activeRow = 1 is above.
        var s = makeState(predictionCount: 35)
        s.isExpanded = true
        s.activeRow = 1
        s.visibleRowOffset = 3

        // Act
        s.clampVisibleWindow()

        // Assert
        XCTAssertEqual(s.visibleRowOffset, 1)
    }

    func testClampNeverSetsNegativeOffset() {
        // Arrange: activeRow = 0, offset somehow negative (shouldn't happen, but defensive).
        var s = makeState(predictionCount: 10)
        s.isExpanded = true
        s.activeRow = 0
        s.visibleRowOffset = -1

        // Act
        s.clampVisibleWindow()

        // Assert
        XCTAssertEqual(s.visibleRowOffset, 0)
    }

    func testClampAtLastRowWithMaxVisible3() {
        // Arrange: 25 predictions / 5 cols = 5 rows. activeRow = 4 (last), maxVisible = 3.
        var s = makeState(predictionCount: 25, maxVisibleRows: 3)
        s.isExpanded = true
        s.activeRow = 4
        s.visibleRowOffset = 0

        // Act
        s.clampVisibleWindow()

        // Assert: offset = 4 - 3 + 1 = 2
        XCTAssertEqual(s.visibleRowOffset, 2)
    }

    // MARK: - maxPredictionIndexNeeded

    func testMaxPredictionIndexNeededRow0() {
        let s = makeState(predictionCount: 10, columnCount: 5)
        // Through row 0: (0+1)*5 - 1 = 4
        XCTAssertEqual(s.maxPredictionIndexNeeded(throughRow: 0), 4)
    }

    func testMaxPredictionIndexNeededRow3() {
        let s = makeState(predictionCount: 10, columnCount: 5)
        // Through row 3: (3+1)*5 - 1 = 19
        XCTAssertEqual(s.maxPredictionIndexNeeded(throughRow: 3), 19)
    }

    func testMaxPredictionIndexNeededC3() {
        let s = makeState(predictionCount: 10, columnCount: 3)
        // Through row 2: (2+1)*3 - 1 = 8
        XCTAssertEqual(s.maxPredictionIndexNeeded(throughRow: 2), 8)
    }

    func testMaxPredictionIndexNeededC7() {
        let s = makeState(predictionCount: 10, columnCount: 7)
        // Through row 1: (1+1)*7 - 1 = 13
        XCTAssertEqual(s.maxPredictionIndexNeeded(throughRow: 1), 13)
    }

    // MARK: - columnCountForRow

    func testColumnCountForFullRow() {
        let s = makeState(predictionCount: 15, columnCount: 5)
        // 15 predictions, 5 cols → 3 full rows. Each has 5 cols.
        XCTAssertEqual(s.columnCountForRow(0), 5)
        XCTAssertEqual(s.columnCountForRow(1), 5)
        XCTAssertEqual(s.columnCountForRow(2), 5)
    }

    func testColumnCountForPartialRow() {
        let s = makeState(predictionCount: 7, columnCount: 5)
        // 7 predictions, 5 cols → row 0: 5, row 1: 2
        XCTAssertEqual(s.columnCountForRow(0), 5)
        XCTAssertEqual(s.columnCountForRow(1), 2)
    }

    func testColumnCountForRowBeyondTotalReturnsZero() {
        let s = makeState(predictionCount: 5, columnCount: 5)
        // Only 1 row. Row 1 is beyond → 0.
        XCTAssertEqual(s.columnCountForRow(1), 0)
    }

    func testColumnCountForEmptyPredictions() {
        let s = makeState(predictionCount: 0)
        XCTAssertEqual(s.columnCountForRow(0), 0)
    }

    func testColumnCountWithLiteralRow0() {
        // Literal occupies slot 0 of row 0, but columnCountForRow still returns the
        // total filled columns (literal + predictions share the unified array).
        let s = makeState(predictionCount: 4, hasLiteral: true, columnCount: 5)
        // unified = ["lit", "p0", "p1", "p2", "p3"] → 5 items → row 0 has 5 cols
        XCTAssertEqual(s.columnCountForRow(0), 5)
    }

    // MARK: - totalRows edge cases

    func testTotalRowsOnePrediction() {
        let s = makeState(predictionCount: 1, columnCount: 5)
        XCTAssertEqual(s.totalRows, 1)
    }

    func testTotalRowsExactMultiple() {
        let s = makeState(predictionCount: 15, columnCount: 5)
        XCTAssertEqual(s.totalRows, 3)
    }

    func testTotalRowsOffByOne() {
        let s = makeState(predictionCount: 16, columnCount: 5)
        XCTAssertEqual(s.totalRows, 4)
    }

    func testTotalRowsC3() {
        let s = makeState(predictionCount: 10, columnCount: 3)
        // ceil(10/3) = 4
        XCTAssertEqual(s.totalRows, 4)
    }
}
