@testable import SwiftType
import XCTest

/// Unit tests for `GridCandidateState`.
///
/// All tests use C = 5 (columnCount = 5) as the baseline, matching the default
/// `gridCols`. Selected tests also cover C = 4 (minimum) and C = 6 (maximum).
@MainActor final class GridCandidateStateTests: XCTestCase {
    // MARK: - Helpers

    private func makeState(
        predictions: [String],
        hasLiteral: Bool,
        columnCount: Int = 5,
        maxVisibleRows: Int = 5,
    ) -> GridCandidateState {
        // When hasLiteral=true, prepend the literal so predictions[0] = literal,
        // matching the production contract where CandidateWindow.show() unifies the array.
        let unified = hasLiteral ? ["lit"] + predictions : predictions
        return GridCandidateState(columnCount: columnCount, hasLiteral: hasLiteral, maxVisibleRows: maxVisibleRows, predictions: unified)
    }

    private func preds(_ count: Int) -> [String] {
        (1 ... max(1, count)).map { "p\($0)" }
    }

    // MARK: - totalRows

    func testTotalRowsEmptyNoPredictionsNoLiteral() {
        let s = makeState(predictions: [], hasLiteral: false)
        XCTAssertEqual(s.totalRows, 0)
    }

    func testTotalRowsEmptyPredictionsWithLiteral() {
        let s = makeState(predictions: [], hasLiteral: true)
        XCTAssertEqual(s.totalRows, 1) // row 0 = literal only
    }

    func testTotalRowsExactlyOneFullRowNoLiteral() {
        let s = makeState(predictions: preds(5), hasLiteral: false)
        XCTAssertEqual(s.totalRows, 1)
    }

    func testTotalRowsPartialSecondRowNoLiteral() {
        let s = makeState(predictions: preds(7), hasLiteral: false)
        XCTAssertEqual(s.totalRows, 2)
    }

    func testTotalRowsExactlyTwoFullRowsNoLiteral() {
        let s = makeState(predictions: preds(10), hasLiteral: false)
        XCTAssertEqual(s.totalRows, 2)
    }

    func testTotalRowsFiveFullRowsNoLiteral() {
        let s = makeState(predictions: preds(25), hasLiteral: false)
        XCTAssertEqual(s.totalRows, 5)
    }

    func testTotalRowsWithLiteralRow0FullPlusOneExtra() {
        // Unified: 6 items. (6+4)/5 = 2 rows.
        let s = makeState(predictions: preds(5), hasLiteral: true)
        XCTAssertEqual(s.totalRows, 2)
    }

    func testTotalRowsWithLiteralExactlyFiveRows() {
        // Unified: 25 items. (25+4)/5 = 5 rows.
        let s = makeState(predictions: preds(24), hasLiteral: true)
        XCTAssertEqual(s.totalRows, 5)
    }

    func testTotalRowsWithLiteralPartialLastRow() {
        // Unified: 27 items. (27+4)/5 = 31/5 = 6 rows.
        let s = makeState(predictions: preds(26), hasLiteral: true)
        XCTAssertEqual(s.totalRows, 6)
    }

    // MARK: - columnCountForRow

    func testColumnCountRow0NoLiteralFullRow() {
        let s = makeState(predictions: preds(5), hasLiteral: false)
        XCTAssertEqual(s.columnCountForRow(0), 5)
    }

    func testColumnCountRow0NoLiteralPartialRow() {
        let s = makeState(predictions: preds(3), hasLiteral: false)
        XCTAssertEqual(s.columnCountForRow(0), 3)
    }

    func testColumnCountRow0WithLiteralFullPredictions() {
        // Unified: 5 items. min(5, 5-0) = 5 columns.
        let s = makeState(predictions: preds(4), hasLiteral: true)
        XCTAssertEqual(s.columnCountForRow(0), 5)
    }

    func testColumnCountRow0WithLiteralNoAdditionalPredictions() {
        // Only the literal slot.
        let s = makeState(predictions: [], hasLiteral: true)
        XCTAssertEqual(s.columnCountForRow(0), 1)
    }

    func testColumnCountRow1WithLiteralFullRow() {
        // Unified: 10 items. Row 1: min(5, 10-5) = 5 columns.
        let s = makeState(predictions: preds(9), hasLiteral: true)
        XCTAssertEqual(s.columnCountForRow(1), 5)
    }

    func testColumnCountRow1WithLiteralPartialRow() {
        // Unified: 7 items. Row 1: min(5, 7-5) = 2 columns.
        let s = makeState(predictions: preds(6), hasLiteral: true)
        XCTAssertEqual(s.columnCountForRow(1), 2)
    }

    func testColumnCountRow2NoLiteralPartialRow() {
        // Row 2 base = 10. With 12 predictions: min(5, 12-10) = 2.
        let s = makeState(predictions: preds(12), hasLiteral: false)
        XCTAssertEqual(s.columnCountForRow(2), 2)
    }

    // MARK: - predictionIndex

    func testPredictionIndexLiteralCellReturnsNil() {
        let s = makeState(predictions: preds(4), hasLiteral: true)
        XCTAssertNil(s.predictionIndex(row: 0, col: 0))
    }

    func testPredictionIndexRow0Col1WithLiteral() {
        // Unified: ["lit", "p1".."p4"]. (row 0, col 1) → 0*5+1 = 1.
        let s = makeState(predictions: preds(4), hasLiteral: true)
        XCTAssertEqual(s.predictionIndex(row: 0, col: 1), 1)
    }

    func testPredictionIndexRow0Col4WithLiteral() {
        // (row 0, col 4) → 0*5+4 = 4.
        let s = makeState(predictions: preds(4), hasLiteral: true)
        XCTAssertEqual(s.predictionIndex(row: 0, col: 4), 4)
    }

    func testPredictionIndexRow1Col0WithLiteral() {
        // Unified: ["lit", "p1".."p9"]. (row 1, col 0) → 1*5+0 = 5.
        let s = makeState(predictions: preds(9), hasLiteral: true)
        XCTAssertEqual(s.predictionIndex(row: 1, col: 0), 5)
    }

    func testPredictionIndexRow1Col4WithLiteral() {
        // (row 1, col 4) → 1*5+4 = 9.
        let s = makeState(predictions: preds(9), hasLiteral: true)
        XCTAssertEqual(s.predictionIndex(row: 1, col: 4), 9)
    }

    func testPredictionIndexRow0Col0NoLiteral() {
        let s = makeState(predictions: preds(5), hasLiteral: false)
        XCTAssertEqual(s.predictionIndex(row: 0, col: 0), 0)
    }

    func testPredictionIndexRow0Col4NoLiteral() {
        let s = makeState(predictions: preds(5), hasLiteral: false)
        XCTAssertEqual(s.predictionIndex(row: 0, col: 4), 4)
    }

    func testPredictionIndexRow2Col0NoLiteral() {
        let s = makeState(predictions: preds(15), hasLiteral: false)
        XCTAssertEqual(s.predictionIndex(row: 2, col: 0), 10)
    }

    func testPredictionIndexBeyondLoadedBufferReturnsNil() {
        let s = makeState(predictions: preds(3), hasLiteral: false)
        XCTAssertNil(s.predictionIndex(row: 1, col: 0)) // index 5 out of range
    }

    // MARK: - maxPredictionIndexNeeded

    func testMaxIndexNeededRow0WithLiteral() {
        let s = makeState(predictions: [], hasLiteral: true)
        // Unified formula: (0+1)*C - 1 = 4.
        XCTAssertEqual(s.maxPredictionIndexNeeded(throughRow: 0), 4)
    }

    func testMaxIndexNeededRow1WithLiteral() {
        let s = makeState(predictions: [], hasLiteral: true)
        // (1+1)*5 - 1 = 9.
        XCTAssertEqual(s.maxPredictionIndexNeeded(throughRow: 1), 9)
    }

    func testMaxIndexNeededRow4WithLiteral() {
        let s = makeState(predictions: [], hasLiteral: true)
        // (4+1)*5 - 1 = 24.
        XCTAssertEqual(s.maxPredictionIndexNeeded(throughRow: 4), 24)
    }

    func testMaxIndexNeededRow0NoLiteral() {
        let s = makeState(predictions: [], hasLiteral: false)
        // (0+1)*C - 1 = 4.
        XCTAssertEqual(s.maxPredictionIndexNeeded(throughRow: 0), 4)
    }

    func testMaxIndexNeededRow4NoLiteral() {
        let s = makeState(predictions: [], hasLiteral: false)
        // (4+1)*5 - 1 = 24.
        XCTAssertEqual(s.maxPredictionIndexNeeded(throughRow: 4), 24)
    }

    // MARK: - isLiteralSelected / selectedPrediction

    func testIsLiteralSelectedInitiallyTrueWithLiteral() {
        // Unified: ["lit", "p1".."p4"]; cursor at (row 0, col 0) → literal selected.
        let s = makeState(predictions: preds(4), hasLiteral: true)
        XCTAssertTrue(s.isLiteralSelected)
    }

    func testIsLiteralSelectedFalseWithoutLiteral() {
        let s = makeState(predictions: preds(5), hasLiteral: false)
        XCTAssertFalse(s.isLiteralSelected)
    }

    func testSelectedPredictionNilWhenLiteralSelected() {
        // Cursor at literal slot → predictionIndex returns nil → selectedPrediction nil.
        let s = makeState(predictions: preds(4), hasLiteral: true)
        XCTAssertNil(s.selectedPrediction)
    }

    func testSelectedPredictionFirstItemNoLiteral() {
        let s = makeState(predictions: ["alpha", "beta"], hasLiteral: false)
        XCTAssertEqual(s.selectedPrediction, "alpha")
    }

    // MARK: - renderedRowCount

    func testRenderedRowCountCollapsedAlwaysOne() {
        let s = makeState(predictions: preds(25), hasLiteral: false)
        XCTAssertEqual(s.renderedRowCount, 1)
    }

    func testRenderedRowCountExpandedMaxFive() {
        var s = makeState(predictions: preds(25), hasLiteral: false)
        s.isExpanded = true
        s.activeRow = 1
        XCTAssertEqual(s.renderedRowCount, 5)
    }

    func testRenderedRowCountExpandedFewerThanFiveRows() {
        var s = makeState(predictions: preds(7), hasLiteral: false)
        s.isExpanded = true
        s.activeRow = 1
        XCTAssertEqual(s.renderedRowCount, 2) // only 2 rows loaded
    }

    // MARK: - moveRowDown

    func testMoveRowDownFromCollapsedExpandsOnly() {
        var s = makeState(predictions: preds(25), hasLiteral: false)
        s.moveRowDown()
        XCTAssertTrue(s.isExpanded)
        XCTAssertEqual(s.activeRow, 0)
        XCTAssertEqual(s.activeCol, 0)
    }

    func testMoveRowDownFromExpandedRow0MovesToRow1() {
        var s = makeState(predictions: preds(25), hasLiteral: false)
        s.isExpanded = true
        s.moveRowDown()
        XCTAssertEqual(s.activeRow, 1)
    }

    func testMoveRowDownFromExpandedIncrementsRow() {
        var s = makeState(predictions: preds(25), hasLiteral: false)
        s.isExpanded = true
        s.activeRow = 1
        s.moveRowDown()
        XCTAssertEqual(s.activeRow, 2)
    }

    func testMoveRowDownDoesNothingWhenAtBottom() {
        var s = makeState(predictions: preds(5), hasLiteral: false) // totalRows = 1
        s.isExpanded = true
        s.moveRowDown()
        // totalRows is 1, nextRow=1 is not < 1, so activeRow stays 0.
        XCTAssertEqual(s.activeRow, 0)
    }

    func testMoveRowDownPreservesActiveCol() {
        // 25 predictions, 5 cols, no literal — row 2 has 5 full columns, so col 3 stays.
        var s = makeState(predictions: preds(25), hasLiteral: false)
        s.isExpanded = true
        s.activeRow = 1
        s.activeCol = 3
        s.moveRowDown()
        XCTAssertEqual(s.activeCol, 3)
    }

    func testMoveRowDownClampsActiveColOnPartialRow() {
        // 22 predictions, 5 cols, no literal — row 4 has only 2 cells (indices 20–21).
        // Navigating from row 3 col 4 should clamp to col 1 (last valid col of row 4).
        var s = makeState(predictions: preds(22), hasLiteral: false)
        s.isExpanded = true
        s.activeRow = 3
        s.activeCol = 4
        s.moveRowDown() // row 4: columnCountForRow(4) = min(5, 22-20) = 2
        XCTAssertEqual(s.activeRow, 4)
        XCTAssertEqual(s.activeCol, 1)
    }

    func testMoveRowDownScrollsVisibleWindowWhenNeeded() {
        var s = makeState(predictions: preds(35), hasLiteral: false) // 7 rows
        s.isExpanded = true
        s.activeRow = 4
        s.visibleRowOffset = 0
        s.moveRowDown() // moves to row 5
        // Row 5 >= 0 + 5, so offset shifts to 5 - 5 + 1 = 1.
        XCTAssertEqual(s.activeRow, 5)
        XCTAssertEqual(s.visibleRowOffset, 1)
    }

    // MARK: - moveRowUp

    func testMoveRowUpFromRow1MovesToRow0StaysExpanded() {
        // Moving from row 1 to row 0 should NOT collapse — the user must press ↑ once more.
        var s = makeState(predictions: preds(25), hasLiteral: false)
        s.isExpanded = true
        s.activeRow = 1
        let didCollapse = s.moveRowUp()
        XCTAssertFalse(didCollapse)
        XCTAssertTrue(s.isExpanded)
        XCTAssertEqual(s.activeRow, 0)
    }

    func testMoveRowUpAtRow0WhileExpandedCollapses() {
        // Pressing ↑ a second time while already at row 0 expanded should collapse.
        var s = makeState(predictions: preds(25), hasLiteral: false)
        s.isExpanded = true
        s.activeRow = 0
        let didCollapse = s.moveRowUp()
        XCTAssertTrue(didCollapse)
        XCTAssertFalse(s.isExpanded)
        XCTAssertEqual(s.activeRow, 0)
        XCTAssertEqual(s.visibleRowOffset, 0)
    }

    func testMoveRowUpFromRow2MovesToRow1() {
        var s = makeState(predictions: preds(25), hasLiteral: false)
        s.isExpanded = true
        s.activeRow = 2
        let didCollapse = s.moveRowUp()
        XCTAssertFalse(didCollapse)
        XCTAssertEqual(s.activeRow, 1)
        XCTAssertTrue(s.isExpanded)
    }

    func testMoveRowUpFromCollapsedIsNoOp() {
        var s = makeState(predictions: preds(25), hasLiteral: false)
        let didCollapse = s.moveRowUp()
        XCTAssertFalse(didCollapse)
        XCTAssertEqual(s.activeRow, 0)
        XCTAssertFalse(s.isExpanded)
    }

    func testMoveRowUpPreservesActiveCol() {
        // 25 predictions, 5 cols, no literal — row 1 has 5 full columns, so col 4 stays.
        var s = makeState(predictions: preds(25), hasLiteral: false)
        s.isExpanded = true
        s.activeRow = 2
        s.activeCol = 4
        s.moveRowUp()
        XCTAssertEqual(s.activeCol, 4)
    }

    func testMoveRowUpPreservesActiveColWhenMovingToRow0() {
        // Row 1→0 uses the same "stays expanded" branch — col must be preserved there too.
        // 25 predictions, 5 cols, no literal — row 0 has 5 full columns, so col 3 stays.
        var s = makeState(predictions: preds(25), hasLiteral: false)
        s.isExpanded = true
        s.activeRow = 1
        s.activeCol = 3
        s.moveRowUp()
        XCTAssertEqual(s.activeRow, 0)
        XCTAssertTrue(s.isExpanded)
        XCTAssertEqual(s.activeCol, 3)
    }

    // MARK: - moveColumnRight / Left

    func testMoveColumnRightCyclesWithinRow() {
        var s = makeState(predictions: preds(5), hasLiteral: false)
        // row 0 has 5 columns; cycle right from 0 to 4 to 0.
        for expected in [1, 2, 3, 4, 0] {
            s.moveColumnRight()
            XCTAssertEqual(s.activeCol, expected)
        }
    }

    func testMoveColumnLeftCyclesWithinRow() {
        var s = makeState(predictions: preds(5), hasLiteral: false)
        // wraps from 0 to 4.
        s.moveColumnLeft()
        XCTAssertEqual(s.activeCol, 4)
        s.moveColumnLeft()
        XCTAssertEqual(s.activeCol, 3)
    }

    func testMoveColumnRightWithLiteralRow0IncludesLiteralSlot() {
        var s = makeState(predictions: preds(4), hasLiteral: true)
        // row 0: literal + 4 preds = 5 columns. Starting at 0 (literal).
        s.moveColumnRight()
        XCTAssertEqual(s.activeCol, 1)
        XCTAssertFalse(s.isLiteralSelected)
    }

    func testMoveColumnRightSingleCellIsNoop() {
        var s = makeState(predictions: [], hasLiteral: true)
        // row 0: only the literal slot. Cycling stays at 0.
        s.moveColumnRight()
        XCTAssertEqual(s.activeCol, 0)
    }

    // MARK: - clampVisibleWindow

    func testClampVisibleWindowActiveRowAboveWindow() {
        var s = makeState(predictions: preds(35), hasLiteral: false)
        s.isExpanded = true
        s.activeRow = 2
        s.visibleRowOffset = 3 // active row is above window
        s.clampVisibleWindow()
        XCTAssertEqual(s.visibleRowOffset, 2)
    }

    func testClampVisibleWindowActiveRowBelowWindow() {
        var s = makeState(predictions: preds(35), hasLiteral: false)
        s.isExpanded = true
        s.activeRow = 7
        s.visibleRowOffset = 0 // active row is below window (0+5=5, 7>=5)
        s.clampVisibleWindow()
        XCTAssertEqual(s.visibleRowOffset, 3) // 7 - 5 + 1 = 3
    }

    func testClampVisibleWindowActiveRowInWindow() {
        var s = makeState(predictions: preds(35), hasLiteral: false)
        s.isExpanded = true
        s.activeRow = 2
        s.visibleRowOffset = 0
        s.clampVisibleWindow()
        XCTAssertEqual(s.visibleRowOffset, 0) // no change
    }

    // MARK: - Column count with C = 3 (minimum)

    func testColumnCountMinC3Row0NoLiteral() {
        let s = makeState(predictions: preds(3), hasLiteral: false, columnCount: 3)
        XCTAssertEqual(s.columnCountForRow(0), 3)
    }

    func testTotalRowsC3TwentyFivePredictions() {
        let s = makeState(predictions: preds(9), hasLiteral: false, columnCount: 3)
        XCTAssertEqual(s.totalRows, 3)
    }

    func testPredictionIndexC3Row1Col2NoLiteral() {
        let s = makeState(predictions: preds(9), hasLiteral: false, columnCount: 3)
        // row 1, col 2: 1*3 + 2 = 5.
        XCTAssertEqual(s.predictionIndex(row: 1, col: 2), 5)
    }

    // MARK: - C=7 (maximum column count) edge cases

    func testTotalRowsC7ExactlyOneFullRow() {
        // 7 predictions, 7 columns, no literal → exactly 1 row.
        let s = makeState(predictions: preds(7), hasLiteral: false, columnCount: 7)
        XCTAssertEqual(s.totalRows, 1)
    }

    func testTotalRowsC7PartialSecondRow() {
        // 8 predictions, 7 columns → row 0 full (7), row 1 partial (1).
        let s = makeState(predictions: preds(8), hasLiteral: false, columnCount: 7)
        XCTAssertEqual(s.totalRows, 2)
    }

    func testTotalRowsC7WithLiteralRow0Full() {
        // Unified: ["lit"] + preds(6) = 7 items. (7+6)/7 = 1 row total.
        let s = makeState(predictions: preds(6), hasLiteral: true, columnCount: 7)
        XCTAssertEqual(s.totalRows, 1)
    }

    func testTotalRowsC7WithLiteralOneOverflow() {
        // Unified: 8 items. (8+6)/7 = 14/7 = 2 rows.
        let s = makeState(predictions: preds(7), hasLiteral: true, columnCount: 7)
        XCTAssertEqual(s.totalRows, 2)
    }

    func testColumnCountRow0C7NoLiteralFull() {
        let s = makeState(predictions: preds(7), hasLiteral: false, columnCount: 7)
        XCTAssertEqual(s.columnCountForRow(0), 7)
    }

    func testColumnCountRow0C7WithLiteralFull() {
        // Unified: 7 items. min(7, 7-0) = 7 columns.
        let s = makeState(predictions: preds(6), hasLiteral: true, columnCount: 7)
        XCTAssertEqual(s.columnCountForRow(0), 7)
    }

    func testColumnCountRow0C7WithLiteralOnly() {
        // Unified: ["lit"] = 1 item. min(7, 1) = 1 column.
        let s = makeState(predictions: [], hasLiteral: true, columnCount: 7)
        XCTAssertEqual(s.columnCountForRow(0), 1)
    }

    func testPredictionIndexC7Row0Col6WithLiteral() {
        // Unified: ["lit", "p1".."p6"]. (row 0, col 6) → 0*7+6 = 6.
        let s = makeState(predictions: preds(6), hasLiteral: true, columnCount: 7)
        XCTAssertEqual(s.predictionIndex(row: 0, col: 6), 6)
    }

    func testPredictionIndexC7Row1Col0NoLiteral() {
        // Row 1, col 0, no literal, C=7 → index 7.
        let s = makeState(predictions: preds(14), hasLiteral: false, columnCount: 7)
        XCTAssertEqual(s.predictionIndex(row: 1, col: 0), 7)
    }

    func testPredictionIndexC7Row1Col6NoLiteral() {
        // Row 1, col 6, no literal, C=7 → index 13.
        let s = makeState(predictions: preds(14), hasLiteral: false, columnCount: 7)
        XCTAssertEqual(s.predictionIndex(row: 1, col: 6), 13)
    }

    func testMaxIndexNeededRow0C7NoLiteral() {
        // (0+1)*7 - 1 = 6.
        let s = makeState(predictions: [], hasLiteral: false, columnCount: 7)
        XCTAssertEqual(s.maxPredictionIndexNeeded(throughRow: 0), 6)
    }

    func testMaxIndexNeededRow1C7WithLiteral() {
        // Unified formula: (1+1)*7 - 1 = 13.
        let s = makeState(predictions: [], hasLiteral: true, columnCount: 7)
        XCTAssertEqual(s.maxPredictionIndexNeeded(throughRow: 1), 13)
    }

    // MARK: - predictionAt (active row convenience)

    func testPredictionAtReturnsCorrectStringNoLiteral() {
        var s = makeState(predictions: ["alpha", "beta", "gamma", "delta", "epsilon"], hasLiteral: false)
        s.activeRow = 0
        XCTAssertEqual(s.predictionAt(col: 2), "gamma")
    }

    func testPredictionAtReturnsNilForLiteralCell() {
        let s = makeState(predictions: preds(4), hasLiteral: true)
        XCTAssertNil(s.predictionAt(col: 0))
    }

    func testPredictionAtReturnsNilForEmptyCell() {
        let s = makeState(predictions: preds(2), hasLiteral: false)
        // Only 2 predictions; col 4 is empty.
        XCTAssertNil(s.predictionAt(col: 4))
    }
}
