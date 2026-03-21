@testable import SwiftType
import XCTest

/// Additional navigation tests for `GridCandidateState` focusing on the default
/// `maxVisibleRows = 3` setting and boundary conditions not covered by the main suite.
@MainActor final class GridCandidateStateNavigationTests: XCTestCase {
    // MARK: - Helpers

    private func makeState(
        predictions: [String],
        hasLiteral: Bool,
        columnCount: Int = 5,
        maxVisibleRows: Int = 3,
    ) -> GridCandidateState {
        let unified = hasLiteral ? ["lit"] + predictions : predictions
        return GridCandidateState(
            columnCount: columnCount,
            hasLiteral: hasLiteral,
            maxVisibleRows: maxVisibleRows,
            predictions: unified,
        )
    }

    private func preds(_ count: Int) -> [String] {
        (1 ... max(1, count)).map { "p\($0)" }
    }

    // MARK: - renderedRowCount with maxVisibleRows = 3

    func testRenderedRowCountCollapsedIsOneWithMaxVisible3() {
        let s = makeState(predictions: preds(25), hasLiteral: false)
        XCTAssertEqual(s.renderedRowCount, 1)
    }

    func testRenderedRowCountExpandedCapsAt3() {
        var s = makeState(predictions: preds(25), hasLiteral: false)
        s.isExpanded = true
        XCTAssertEqual(s.renderedRowCount, 3)
    }

    func testRenderedRowCountExpandedFewerThan3Rows() {
        var s = makeState(predictions: preds(7), hasLiteral: false)
        s.isExpanded = true
        XCTAssertEqual(s.renderedRowCount, 2)
    }

    // MARK: - Visible window scrolling with maxVisibleRows = 3

    func testVisibleWindowScrollsDownWithMaxVisible3() {
        var s = makeState(predictions: preds(35), hasLiteral: false) // 7 rows
        s.isExpanded = true
        s.activeRow = 2
        s.visibleRowOffset = 0
        s.moveRowDown() // activeRow -> 3
        // 3 >= 0 + 3, so offset = 3 - 3 + 1 = 1
        XCTAssertEqual(s.activeRow, 3)
        XCTAssertEqual(s.visibleRowOffset, 1)
    }

    func testVisibleWindowScrollsUpWithMaxVisible3() {
        var s = makeState(predictions: preds(35), hasLiteral: false)
        s.isExpanded = true
        s.activeRow = 3
        s.visibleRowOffset = 2
        s.moveRowUp() // activeRow -> 2
        // 2 < 2 is false, so offset stays 2? No: 2 >= 2, so no scroll up either. Let's check.
        // Actually: activeRow=2, visibleRowOffset=2. 2 < 2 is false, 2 >= 2+3=5 is false. So stays 2.
        XCTAssertEqual(s.activeRow, 2)
        XCTAssertEqual(s.visibleRowOffset, 2)
    }

    func testVisibleWindowScrollsUpWhenActiveAboveWindow() {
        var s = makeState(predictions: preds(35), hasLiteral: false)
        s.isExpanded = true
        s.activeRow = 2
        s.visibleRowOffset = 3
        s.moveRowUp() // activeRow -> 1
        // 1 < 3 → visibleRowOffset = 1
        XCTAssertEqual(s.activeRow, 1)
        XCTAssertEqual(s.visibleRowOffset, 1)
    }

    // MARK: - Full navigation sequence (expand → down → down → up → up → collapse)

    func testFullNavigationCycleWithLiteral() {
        var s = makeState(predictions: preds(14), hasLiteral: true) // unified: 15 items = 3 rows
        XCTAssertFalse(s.isExpanded)
        XCTAssertEqual(s.activeRow, 0)
        XCTAssertEqual(s.activeCol, 0)
        XCTAssertTrue(s.isLiteralSelected)

        // Down: expand (stay at row 0)
        s.moveRowDown()
        XCTAssertTrue(s.isExpanded)
        XCTAssertEqual(s.activeRow, 0)

        // Down: move to row 1
        s.moveRowDown()
        XCTAssertEqual(s.activeRow, 1)
        XCTAssertFalse(s.isLiteralSelected)

        // Down: move to row 2
        s.moveRowDown()
        XCTAssertEqual(s.activeRow, 2)

        // Down: at last row, no-op
        s.moveRowDown()
        XCTAssertEqual(s.activeRow, 2)

        // Up: row 1
        s.moveRowUp()
        XCTAssertEqual(s.activeRow, 1)
        XCTAssertTrue(s.isExpanded)

        // Up: row 0, stays expanded
        s.moveRowUp()
        XCTAssertEqual(s.activeRow, 0)
        XCTAssertTrue(s.isExpanded)

        // Up at row 0: collapse
        let collapsed = s.moveRowUp()
        XCTAssertTrue(collapsed)
        XCTAssertFalse(s.isExpanded)
        XCTAssertEqual(s.activeRow, 0)
        XCTAssertEqual(s.visibleRowOffset, 0)
    }

    // MARK: - Column wrapping with partial rows

    func testColumnCycleOnPartialRow() {
        // 7 predictions, 5 cols, no literal → row 1 has 2 cells
        var s = makeState(predictions: preds(7), hasLiteral: false)
        s.isExpanded = true
        s.activeRow = 1
        s.activeCol = 0

        s.moveColumnRight() // col 1
        XCTAssertEqual(s.activeCol, 1)

        s.moveColumnRight() // wraps to col 0
        XCTAssertEqual(s.activeCol, 0)
    }

    func testColumnLeftWrapOnPartialRow() {
        var s = makeState(predictions: preds(7), hasLiteral: false)
        s.isExpanded = true
        s.activeRow = 1
        s.activeCol = 0

        s.moveColumnLeft() // wraps to col 1 (last in partial row)
        XCTAssertEqual(s.activeCol, 1)
    }

    // MARK: - Empty predictions edge case

    func testMoveRowDownOnEmptyPredictionsNoLiteral() {
        var s = makeState(predictions: [], hasLiteral: false)
        s.moveRowDown()
        // Just expands, doesn't crash
        XCTAssertTrue(s.isExpanded)
        XCTAssertEqual(s.activeRow, 0)
    }

    func testMoveColumnRightOnEmptyPredictions() {
        var s = makeState(predictions: [], hasLiteral: false)
        // columnCountForRow(0) = 0 → guard returns
        s.moveColumnRight()
        XCTAssertEqual(s.activeCol, 0)
    }

    // MARK: - Column clamping across rows with different widths

    func testColumnClampedWhenNavigatingToShorterRow() {
        // 12 predictions, 5 cols → row 0: 5, row 1: 5, row 2: 2
        var s = makeState(predictions: preds(12), hasLiteral: false)
        s.isExpanded = true
        s.activeRow = 1
        s.activeCol = 4 // last col of row 1

        s.moveRowDown() // row 2 has 2 cols → clamped to col 1
        XCTAssertEqual(s.activeRow, 2)
        XCTAssertEqual(s.activeCol, 1)
    }

    func testColumnPreservedWhenNavigatingToEqualWidthRow() {
        // 15 predictions, 5 cols → 3 full rows
        var s = makeState(predictions: preds(15), hasLiteral: false)
        s.isExpanded = true
        s.activeRow = 0
        s.activeCol = 4

        s.moveRowDown() // row 1 also has 5 cols → col preserved
        XCTAssertEqual(s.activeCol, 4)
    }
}
