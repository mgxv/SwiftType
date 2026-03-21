import AppKit
@testable import SwiftType
import XCTest

/// Tests for CandidateWindow row navigation (Down/Up arrows) and the helper
/// queries `isLiteralAt(gridColumn:)` and `predictionIndexAt(gridColumn:)`.
///
/// Row navigation was previously tested only at the `GridCandidateState` level.
/// These tests exercise the full `CandidateWindow` surface so that both the
/// state transitions AND the public-API contract are locked in.
///
/// All tests run on the main thread (XCTest default for macOS) — required by AppKit.
/// setUp/tearDown call `hide()` to prevent state leaking between tests.
@MainActor final class CandidateWindowRowNavigationTests: XCTestCase {
    override func setUp() async throws {
        CandidateWindow.shared.hide()
    }

    override func tearDown() async throws {
        CandidateWindow.shared.hide()
    }

    // MARK: - Helpers

    private func show(candidates: [String], literal: String? = nil) {
        CandidateWindow.shared.show(candidates: candidates, literalText: literal, client: nil)
    }

    private func words(_ count: Int) -> [String] {
        (1 ... max(1, count)).map { "word\($0)" }
    }

    // MARK: - moveActiveRowDown — expand on first press

    func testFirstDownPressExpandsWithoutMovingRow() {
        // Arrange: show enough words to have multiple rows.
        show(candidates: words(15), literal: nil)
        // selectedCandidate() starts at row 0, col 0 → "word1".
        XCTAssertEqual(CandidateWindow.shared.selectedCandidate(), "word1")

        // Act: first Down press — must expand without moving the active row.
        CandidateWindow.shared.moveActiveRowDown()

        // Assert: still at row 0, col 0 → "word1".
        XCTAssertEqual(CandidateWindow.shared.selectedCandidate(), "word1",
                       "First Down press must expand the grid without moving the active row")
    }

    func testSecondDownPressMovesToRow1() {
        // Arrange: show enough words to fill rows 0 and 1.
        let cols = ThemeManager.shared.gridCols
        show(candidates: words(cols * 2), literal: nil)

        // Act: expand then move down.
        CandidateWindow.shared.moveActiveRowDown() // expand
        CandidateWindow.shared.moveActiveRowDown() // row 0 → row 1

        // Assert: active row is 1, col 0 → word at index (cols + 0).
        let expected = "word\(cols + 1)"
        XCTAssertEqual(CandidateWindow.shared.selectedCandidate(), expected,
                       "Second Down press must move active row to 1")
    }

    func testDownAtLastRowDoesNothing() {
        // Arrange: show exactly one row of words (no row below to move to).
        let cols = ThemeManager.shared.gridCols
        show(candidates: words(cols), literal: nil) // exactly 1 row

        // Act: expand, then try to move down (should be a no-op since no row 1).
        CandidateWindow.shared.moveActiveRowDown() // expand
        CandidateWindow.shared.moveActiveRowDown() // attempt to move — should not move

        // Assert: still at row 0, col 0 → "word1".
        XCTAssertEqual(CandidateWindow.shared.selectedCandidate(), "word1",
                       "Down at the last row must not move the active row")
    }

    func testDownWhenHiddenDoesNothing() {
        // gridState == nil after hide() — moveActiveRowDown must early-return.
        CandidateWindow.shared.moveActiveRowDown()
        XCTAssertNil(CandidateWindow.shared.selectedCandidate())
        XCTAssertFalse(CandidateWindow.shared.isLiteralSelected)
    }

    // MARK: - moveActiveRowUp — collapse / move up

    func testUpWhenCollapsedDoesNothing() {
        // Arrange: show words but do NOT expand.
        show(candidates: words(10), literal: nil)
        // Active row is 0, grid collapsed — pressing Up must be a no-op.
        CandidateWindow.shared.moveActiveRowUp()
        XCTAssertEqual(CandidateWindow.shared.selectedCandidate(), "word1",
                       "Up when collapsed must leave state unchanged")
    }

    func testUpFromRow1MovesToRow0StaysExpanded() {
        // Arrange: expand, then move to row 1.
        let cols = ThemeManager.shared.gridCols
        show(candidates: words(cols * 3), literal: nil)
        CandidateWindow.shared.moveActiveRowDown() // expand
        CandidateWindow.shared.moveActiveRowDown() // → row 1

        // Act: move up.
        CandidateWindow.shared.moveActiveRowUp() // → row 0, stays expanded

        // Assert: back to row 0, col 0 → "word1"; grid still expanded so
        // selectedCandidate() should still return "word1".
        XCTAssertEqual(CandidateWindow.shared.selectedCandidate(), "word1",
                       "Up from row 1 must move to row 0 without collapsing")
    }

    func testUpFromRow0WhileExpandedCollapses() {
        // Arrange: expand to row 0 (just expand, don't move the row).
        show(candidates: words(10), literal: nil)
        CandidateWindow.shared.moveActiveRowDown() // expand (activeRow stays 0)

        // Act: press Up while at row 0 in expanded state — must collapse.
        CandidateWindow.shared.moveActiveRowUp()

        // Assert: grid is collapsed; selectedCandidate() still returns the row-0 selection.
        // We verify indirectly: after collapse the window is still visible with row 0 content.
        XCTAssertEqual(CandidateWindow.shared.selectedCandidate(), "word1",
                       "Up at row 0 while expanded must collapse but keep row 0 as active")
    }

    func testUpWhenHiddenDoesNothing() {
        CandidateWindow.shared.moveActiveRowUp()
        XCTAssertNil(CandidateWindow.shared.selectedCandidate())
    }

    // MARK: - Row navigation preserves active column

    func testDownPreservesActiveColumn() {
        // Arrange: advance to col 1, then expand and move to row 1.
        let cols = ThemeManager.shared.gridCols
        show(candidates: words(cols * 3), literal: nil)
        CandidateWindow.shared.moveActiveColumnRight() // col 0 → col 1
        CandidateWindow.shared.moveActiveRowDown() // expand
        CandidateWindow.shared.moveActiveRowDown() // → row 1, col 1

        // Assert: col 1 of row 1 = word at index (cols + 1).
        let expected = "word\(cols + 2)" // 0-based index = cols+1, word label is 1-based
        XCTAssertEqual(CandidateWindow.shared.selectedCandidate(), expected,
                       "Column must be preserved when moving between rows")
    }

    func testUpPreservesActiveColumn() {
        // Arrange: expand, go to row 1 col 1, then move up.
        let cols = ThemeManager.shared.gridCols
        show(candidates: words(cols * 3), literal: nil)
        CandidateWindow.shared.moveActiveRowDown() // expand
        CandidateWindow.shared.moveActiveRowDown() // → row 1
        CandidateWindow.shared.moveActiveColumnRight() // col 0 → col 1
        CandidateWindow.shared.moveActiveRowUp() // → row 0, col 1

        // Assert: row 0, col 1 → "word2".
        XCTAssertEqual(CandidateWindow.shared.selectedCandidate(), "word2",
                       "Column must be preserved when moving up between rows")
    }

    // MARK: - isLiteralAt(gridColumn:) — composition mode

    func testIsLiteralAtCol0WithLiteralReturnsTrue() {
        // Arrange: show with a literal in the first slot.
        show(candidates: ["hello", "help"], literal: "hel")
        // Active row is 0. Column 0 is the literal slot.
        XCTAssertTrue(CandidateWindow.shared.isLiteralAt(gridColumn: 0),
                      "isLiteralAt(0) must be true when a literal is shown and active row is 0")
    }

    func testIsLiteralAtCol1WithLiteralReturnsFalse() {
        show(candidates: ["hello", "help"], literal: "hel")
        XCTAssertFalse(CandidateWindow.shared.isLiteralAt(gridColumn: 1),
                       "col 1 is a prediction slot, not the literal")
    }

    func testIsLiteralAtWhenNoLiteralAlwaysReturnsFalse() {
        show(candidates: ["hello", "help"], literal: nil)
        XCTAssertFalse(CandidateWindow.shared.isLiteralAt(gridColumn: 0),
                       "isLiteralAt must return false when hasLiteral is false")
    }

    func testIsLiteralAtWhenHiddenReturnsFalse() {
        // gridState == nil → isLiteralAt must return false.
        XCTAssertFalse(CandidateWindow.shared.isLiteralAt(gridColumn: 0))
    }

    func testIsLiteralAtCol0OnRow1WithLiteralReturnsFalse() {
        // After moving to row 1, (row 1, col 0) is NOT the literal slot.
        let cols = ThemeManager.shared.gridCols
        show(candidates: words(cols * 2), literal: "hel")
        CandidateWindow.shared.moveActiveRowDown() // expand
        CandidateWindow.shared.moveActiveRowDown() // → row 1
        XCTAssertFalse(CandidateWindow.shared.isLiteralAt(gridColumn: 0),
                       "isLiteralAt is only true for (row 0, col 0) in literal mode")
    }

    // MARK: - predictionIndexAt(gridColumn:)

    func testPredictionIndexAtCol0WithLiteralReturnsNil() {
        // Col 0 on row 0 is the literal slot — predictionIndexAt returns nil.
        show(candidates: ["hello", "help"], literal: "hel")
        XCTAssertNil(CandidateWindow.shared.predictionIndexAt(gridColumn: 0),
                     "Literal cell must return nil from predictionIndexAt")
    }

    func testPredictionIndexAtCol1WithLiteralReturnsOne() {
        // Col 1 on row 0 maps to predictions[1] (predictions[0] is the literal).
        show(candidates: ["hello", "help"], literal: "hel")
        XCTAssertEqual(CandidateWindow.shared.predictionIndexAt(gridColumn: 1), 1)
    }

    func testPredictionIndexAtCol0WithoutLiteralReturnsZero() {
        // No literal: col 0 maps to predictions[0].
        show(candidates: ["alpha", "beta"], literal: nil)
        XCTAssertEqual(CandidateWindow.shared.predictionIndexAt(gridColumn: 0), 0)
    }

    func testPredictionIndexAtBeyondLoadedBufferReturnsNil() {
        // Only 1 candidate shown; col 3 is beyond the buffer.
        show(candidates: ["only"], literal: nil)
        XCTAssertNil(CandidateWindow.shared.predictionIndexAt(gridColumn: 3))
    }

    func testPredictionIndexAtWhenHiddenReturnsNil() {
        XCTAssertNil(CandidateWindow.shared.predictionIndexAt(gridColumn: 0))
    }

    func testPredictionIndexAtOnRow1AfterNavigation() {
        // After expanding and moving to row 1, predictionIndexAt maps to the correct
        // unified-array index for (activeRow=1, col).
        let cols = ThemeManager.shared.gridCols
        show(candidates: words(cols * 2), literal: nil)
        CandidateWindow.shared.moveActiveRowDown() // expand
        CandidateWindow.shared.moveActiveRowDown() // → row 1

        // Col 0 of row 1 maps to unified index = 1*cols + 0 = cols.
        XCTAssertEqual(CandidateWindow.shared.predictionIndexAt(gridColumn: 0), cols)
    }

    // MARK: - Round-trip: navigate down then select via predictionIndexAt

    func testPredictionIndexMatchesSelectedCandidateAfterRowNavigation() {
        // Verify that predictionIndexAt(activeCol) == the index of selectedCandidate().
        let cols = ThemeManager.shared.gridCols
        let allWords = words(cols * 2)
        show(candidates: allWords, literal: nil)
        CandidateWindow.shared.moveActiveRowDown() // expand
        CandidateWindow.shared.moveActiveRowDown() // → row 1
        CandidateWindow.shared.moveActiveColumnRight() // → col 1

        // predictionIndexAt(1) should give the index of the selected candidate.
        if let idx = CandidateWindow.shared.predictionIndexAt(gridColumn: 1) {
            XCTAssertEqual(CandidateWindow.shared.selectedCandidate(), allWords[idx],
                           "predictionIndexAt must match the selected candidate's position in the array")
        } else {
            XCTFail("predictionIndexAt(1) must not return nil for row 1 with \(cols * 2) predictions")
        }
    }
}
