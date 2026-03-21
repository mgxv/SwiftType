@testable import SwiftType
import XCTest

/// Edge-case tests for `GridCandidateState` — focuses on boundary conditions, empty states,
/// and combinations not covered by the existing navigation/geometry test suites.
@MainActor final class GridCandidateStateEdgeCaseTests: XCTestCase {
    // MARK: - Helpers

    private func makeState(
        cols: Int = 5,
        hasLiteral: Bool = false,
        maxVisibleRows: Int = 3,
        predictions: [String],
    ) -> GridCandidateState {
        GridCandidateState(
            columnCount: cols,
            hasLiteral: hasLiteral,
            maxVisibleRows: maxVisibleRows,
            predictions: predictions,
        )
    }

    private func preds(_ count: Int) -> [String] {
        (0 ..< count).map { "p\($0)" }
    }

    // MARK: - Empty predictions

    func testTotalRowsIsZeroForEmptyPredictions() {
        let state = makeState(predictions: [])
        XCTAssertEqual(state.totalRows, 0)
    }

    func testColumnCountForRowReturnsZeroWhenEmpty() {
        let state = makeState(predictions: [])
        XCTAssertEqual(state.columnCountForRow(0), 0)
    }

    func testPredictionIndexReturnsNilWhenEmpty() {
        let state = makeState(predictions: [])
        XCTAssertNil(state.predictionIndex(row: 0, col: 0))
    }

    func testSelectedPredictionIsNilWhenEmpty() {
        let state = makeState(predictions: [])
        XCTAssertNil(state.selectedPrediction)
    }

    func testRenderedRowCountIsOneWhenCollapsedAndEmpty() {
        let state = makeState(predictions: [])
        XCTAssertEqual(state.renderedRowCount, 1)
    }

    // MARK: - Single prediction

    func testSinglePredictionTotalRowsIsOne() {
        let state = makeState(cols: 5, predictions: ["a"])
        XCTAssertEqual(state.totalRows, 1)
    }

    func testSinglePredictionColumnCountForRow0IsOne() {
        let state = makeState(cols: 5, predictions: ["a"])
        XCTAssertEqual(state.columnCountForRow(0), 1)
    }

    func testSinglePredictionColumnCountForRow1IsZero() {
        let state = makeState(cols: 5, predictions: ["a"])
        XCTAssertEqual(state.columnCountForRow(1), 0)
    }

    // MARK: - Literal slot edge cases

    func testLiteralSlotPredictionIndexIsNil() {
        let state = makeState(hasLiteral: true, predictions: ["literal", "p0", "p1"])
        XCTAssertNil(state.predictionIndex(row: 0, col: 0))
    }

    func testLiteralSlotNonZeroColReturnsPredictionIndex() {
        let state = makeState(cols: 3, hasLiteral: true, predictions: ["literal", "p0", "p1"])
        XCTAssertEqual(state.predictionIndex(row: 0, col: 1), 1)
        XCTAssertEqual(state.predictionIndex(row: 0, col: 2), 2)
    }

    func testIsLiteralSelectedTrueWhenAtOriginWithLiteral() {
        let state = makeState(hasLiteral: true, predictions: ["literal", "p0"])
        XCTAssertTrue(state.isLiteralSelected)
    }

    func testIsLiteralSelectedFalseWhenNotAtOrigin() {
        var state = makeState(cols: 3, hasLiteral: true, predictions: preds(6))
        state.activeCol = 1
        XCTAssertFalse(state.isLiteralSelected)
    }

    func testIsLiteralSelectedFalseWithoutLiteral() {
        let state = makeState(hasLiteral: false, predictions: ["p0"])
        XCTAssertFalse(state.isLiteralSelected)
    }

    // MARK: - Row boundary - exact fill

    func testExactlyFillOneRowTotalRowsIsOne() {
        let state = makeState(cols: 5, predictions: preds(5))
        XCTAssertEqual(state.totalRows, 1)
    }

    func testExactlyFillTwoRowsTotalRowsIsTwo() {
        let state = makeState(cols: 5, predictions: preds(10))
        XCTAssertEqual(state.totalRows, 2)
    }

    func testOverflowByOneTotalRowsIncrements() {
        let state = makeState(cols: 5, predictions: preds(6))
        XCTAssertEqual(state.totalRows, 2)
    }

    // MARK: - Navigation on partial last row

    func testMoveColumnRightWrapsOnPartialRow() {
        // Row has 3 cells but columnCount is 5
        var state = makeState(cols: 5, predictions: preds(8))
        state.isExpanded = true
        state.activeRow = 1 // second row has 3 cells (indices 5, 6, 7)
        state.activeCol = 2 // last cell in partial row

        state.moveColumnRight()
        XCTAssertEqual(state.activeCol, 0, "Should wrap to column 0")
    }

    func testMoveColumnLeftWrapsOnPartialRow() {
        var state = makeState(cols: 5, predictions: preds(8))
        state.isExpanded = true
        state.activeRow = 1
        state.activeCol = 0

        state.moveColumnLeft()
        XCTAssertEqual(state.activeCol, 2, "Should wrap to last populated column")
    }

    // MARK: - moveRowDown clamps column to target row

    func testMoveRowDownClampsColumnToPartialRow() {
        var state = makeState(cols: 5, predictions: preds(7))
        state.isExpanded = true
        state.activeCol = 4 // last col of full first row

        state.moveRowDown()
        // Second row has 2 cells (indices 5, 6), so activeCol should clamp to 1
        XCTAssertEqual(state.activeRow, 1)
        XCTAssertEqual(state.activeCol, 1)
    }

    // MARK: - moveRowDown at last row is no-op

    func testMoveRowDownAtLastRowIsNoop() {
        var state = makeState(cols: 5, predictions: preds(5))
        state.isExpanded = true
        state.activeRow = 0 // only row

        state.moveRowDown()
        XCTAssertEqual(state.activeRow, 0)
    }

    // MARK: - moveRowUp when not expanded is no-op

    func testMoveRowUpWhenCollapsedReturnsFalse() {
        var state = makeState(predictions: preds(10))
        XCTAssertFalse(state.isExpanded)
        let didCollapse = state.moveRowUp()
        XCTAssertFalse(didCollapse)
    }

    // MARK: - Visible window clamping

    func testClampVisibleWindowAdjustsOffsetDown() {
        var state = makeState(cols: 3, maxVisibleRows: 2, predictions: preds(12))
        state.isExpanded = true
        state.activeRow = 3
        state.visibleRowOffset = 0

        state.clampVisibleWindow()
        XCTAssertEqual(state.visibleRowOffset, 2, "Window should scroll to show activeRow")
    }

    func testClampVisibleWindowAdjustsOffsetUp() {
        var state = makeState(cols: 3, maxVisibleRows: 2, predictions: preds(12))
        state.isExpanded = true
        state.activeRow = 0
        state.visibleRowOffset = 2

        state.clampVisibleWindow()
        XCTAssertEqual(state.visibleRowOffset, 0)
    }

    func testClampVisibleWindowNeverGoesNegative() {
        var state = makeState(cols: 3, maxVisibleRows: 3, predictions: preds(9))
        state.activeRow = 0
        state.visibleRowOffset = -1

        state.clampVisibleWindow()
        XCTAssertGreaterThanOrEqual(state.visibleRowOffset, 0)
    }

    // MARK: - maxPredictionIndexNeeded

    func testMaxPredictionIndexNeededForRow0() {
        let state = makeState(cols: 5, predictions: preds(10))
        // Through row 0: need indices 0..4 → max = 4
        XCTAssertEqual(state.maxPredictionIndexNeeded(throughRow: 0), 4)
    }

    func testMaxPredictionIndexNeededForRow1() {
        let state = makeState(cols: 5, predictions: preds(10))
        // Through row 1: need indices 0..9 → max = 9
        XCTAssertEqual(state.maxPredictionIndexNeeded(throughRow: 1), 9)
    }

    func testMaxPredictionIndexNeededForLargeRow() {
        let state = makeState(cols: 7, predictions: preds(21))
        // Through row 2: (2+1)*7 - 1 = 20
        XCTAssertEqual(state.maxPredictionIndexNeeded(throughRow: 2), 20)
    }

    // MARK: - predictionAt

    func testPredictionAtReturnsCorrectValue() {
        let state = makeState(cols: 3, predictions: ["a", "b", "c", "d", "e", "f"])
        XCTAssertEqual(state.predictionAt(col: 0), "a")
        XCTAssertEqual(state.predictionAt(col: 1), "b")
        XCTAssertEqual(state.predictionAt(col: 2), "c")
    }

    func testPredictionAtReturnsNilForOutOfBoundsCol() {
        let state = makeState(cols: 5, predictions: ["a", "b"])
        XCTAssertNil(state.predictionAt(col: 3))
    }

    func testPredictionAtReturnsNilForLiteralSlot() {
        let state = makeState(cols: 3, hasLiteral: true, predictions: ["literal", "p0", "p1"])
        XCTAssertNil(state.predictionAt(col: 0))
    }

    // MARK: - renderedRowCount

    func testRenderedRowCountIsOneWhenCollapsed() {
        let state = makeState(cols: 3, predictions: preds(9))
        XCTAssertEqual(state.renderedRowCount, 1)
    }

    func testRenderedRowCountIsCappedAtMaxVisibleRows() {
        var state = makeState(cols: 3, maxVisibleRows: 2, predictions: preds(12))
        state.isExpanded = true
        XCTAssertEqual(state.renderedRowCount, 2)
    }

    func testRenderedRowCountIsLessThanMaxWhenFewPredictions() {
        var state = makeState(cols: 5, maxVisibleRows: 3, predictions: preds(8))
        state.isExpanded = true
        // 8 predictions / 5 cols = 2 rows
        XCTAssertEqual(state.renderedRowCount, 2)
    }
}
