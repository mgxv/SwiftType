import AppKit
@testable import SwiftType
import XCTest

/// Tests for the CandidateWindow selection state machine.
///
/// `CandidateWindow.shared` is a real UI singleton hosted inside SwiftType.app.
/// Tests call the public selection API and assert the *logical* state
/// (`isLiteralSelected`, `selectedCandidate()`), not the visual state (`isVisible`),
/// so they are robust to headless test environments.
///
/// XCTest test methods run on the main thread by default, satisfying AppKit's
/// requirement that UI operations happen on the main thread.
///
/// setUp / tearDown call `hide()` so that no state leaks between tests.
@MainActor final class CandidateWindowSelectionTests: XCTestCase {
    override func setUp() async throws {
        CandidateWindow.shared.hide()
    }

    override func tearDown() async throws {
        CandidateWindow.shared.hide()
    }

    // MARK: - Helpers

    private func show(candidates: [String] = [], literal: String? = nil) {
        CandidateWindow.shared.show(candidates: candidates, literalText: literal, client: nil)
    }

    // MARK: - show() guard: both empty → state reset

    func testShowWithNoCandidatesAndNoLiteralResetsState() {
        // Arrange: prime with real content.
        show(candidates: ["word"], literal: "wo")
        // Act: show nothing.
        show(candidates: [], literal: nil)
        // Assert: logical state is as if hide() was called.
        XCTAssertFalse(CandidateWindow.shared.isLiteralSelected)
        XCTAssertNil(CandidateWindow.shared.selectedCandidate())
    }

    func testShowWithNoCandidatesAndNoLiteralFromCleanStateIsHarmless() {
        // Calling with nothing from a clean state must not crash or corrupt state.
        show(candidates: [], literal: nil)
        XCTAssertFalse(CandidateWindow.shared.isLiteralSelected)
        XCTAssertNil(CandidateWindow.shared.selectedCandidate())
    }

    // MARK: - Initial state after show()

    func testWithLiteralAndCandidates_initialIsLiteralSelectedTrue() {
        show(candidates: ["hello", "help"], literal: "hel")
        XCTAssertTrue(CandidateWindow.shared.isLiteralSelected)
    }

    func testWithLiteralAndCandidates_initialSelectedCandidateIsNil() {
        // Literal occupies slot 0; selectedCandidate() returns nil for the literal slot.
        show(candidates: ["hello", "help"], literal: "hel")
        XCTAssertNil(CandidateWindow.shared.selectedCandidate())
    }

    func testWithCandidatesOnly_initialIsLiteralSelectedFalse() {
        show(candidates: ["hello", "help"], literal: nil)
        XCTAssertFalse(CandidateWindow.shared.isLiteralSelected)
    }

    func testWithCandidatesOnly_initialSelectedCandidateIsFirst() {
        show(candidates: ["alpha", "beta"], literal: nil)
        XCTAssertEqual(CandidateWindow.shared.selectedCandidate(), "alpha")
    }

    // MARK: - show() resets selection index

    func testShowResetsSelectionAfterPreviousAdvance() {
        // Arrange: advance past the first slot.
        show(candidates: ["first", "second"], literal: nil)
        CandidateWindow.shared.moveActiveColumnRight()
        XCTAssertEqual(CandidateWindow.shared.selectedCandidate(), "second")
        // Act: re-show with different content.
        show(candidates: ["newA", "newB"], literal: nil)
        // Assert: selection resets to index 0.
        XCTAssertEqual(CandidateWindow.shared.selectedCandidate(), "newA")
    }

    func testShowResetsLiteralSelectionAfterPreviousAdvance() {
        show(candidates: ["hello"], literal: "hel")
        CandidateWindow.shared.moveActiveColumnRight() // advance off literal
        // Re-show: literal should be selected again at index 0.
        show(candidates: ["world"], literal: "wor")
        XCTAssertTrue(CandidateWindow.shared.isLiteralSelected)
        XCTAssertNil(CandidateWindow.shared.selectedCandidate())
    }

    // MARK: - moveActiveColumnRight() — literal + candidates

    func testSelectNextMovesFromLiteralToFirstCandidate() {
        show(candidates: ["hello", "help"], literal: "hel")
        CandidateWindow.shared.moveActiveColumnRight()
        XCTAssertFalse(CandidateWindow.shared.isLiteralSelected)
        XCTAssertEqual(CandidateWindow.shared.selectedCandidate(), "hello")
    }

    func testSelectNextMovesFromFirstToSecondCandidate() {
        show(candidates: ["hello", "help"], literal: "hel")
        CandidateWindow.shared.moveActiveColumnRight() // → "hello"
        CandidateWindow.shared.moveActiveColumnRight() // → "help"
        XCTAssertEqual(CandidateWindow.shared.selectedCandidate(), "help")
    }

    func testSelectNextWrapsFromLastCandidateBackToLiteral() {
        // Row 0 has 3 columns: literal, "hello", "help".
        // Three right moves cycle back to col 0 (literal).
        show(candidates: ["hello", "help"], literal: "hel")
        CandidateWindow.shared.moveActiveColumnRight() // col 1 → "hello"
        CandidateWindow.shared.moveActiveColumnRight() // col 2 → "help"
        CandidateWindow.shared.moveActiveColumnRight() // col 0 → literal (wrap)
        XCTAssertTrue(CandidateWindow.shared.isLiteralSelected)
        XCTAssertNil(CandidateWindow.shared.selectedCandidate())
    }

    // MARK: - moveActiveColumnLeft() — literal + candidates

    func testSelectPreviousWrapsFromLiteralToLastCandidate() {
        // From col 0 (literal), going left wraps to the last populated column.
        show(candidates: ["hello", "help"], literal: "hel")
        CandidateWindow.shared.moveActiveColumnLeft()
        XCTAssertFalse(CandidateWindow.shared.isLiteralSelected)
        XCTAssertEqual(CandidateWindow.shared.selectedCandidate(), "help")
    }

    func testSelectPreviousMovesFromSecondToFirstCandidate() {
        show(candidates: ["hello", "help"], literal: "hel")
        CandidateWindow.shared.moveActiveColumnRight() // → "hello"
        CandidateWindow.shared.moveActiveColumnRight() // → "help"
        CandidateWindow.shared.moveActiveColumnLeft() // → "hello"
        XCTAssertEqual(CandidateWindow.shared.selectedCandidate(), "hello")
    }

    func testSelectPreviousFromFirstCandidateGoesToLiteral() {
        show(candidates: ["hello", "help"], literal: "hel")
        CandidateWindow.shared.moveActiveColumnRight() // → "hello"
        CandidateWindow.shared.moveActiveColumnLeft() // → literal
        XCTAssertTrue(CandidateWindow.shared.isLiteralSelected)
        XCTAssertNil(CandidateWindow.shared.selectedCandidate())
    }

    // MARK: - moveActiveColumnRight() — candidates only (no literal)

    func testSelectNextWithoutLiteralMovesFromFirstToSecond() {
        show(candidates: ["alpha", "beta", "gamma"], literal: nil)
        CandidateWindow.shared.moveActiveColumnRight()
        XCTAssertEqual(CandidateWindow.shared.selectedCandidate(), "beta")
    }

    func testSelectNextWithoutLiteralWrapsFromLastToFirst() {
        // Row 0 has 3 columns; three right moves cycle back to col 0.
        show(candidates: ["alpha", "beta", "gamma"], literal: nil)
        CandidateWindow.shared.moveActiveColumnRight() // → "beta"
        CandidateWindow.shared.moveActiveColumnRight() // → "gamma"
        CandidateWindow.shared.moveActiveColumnRight() // → "alpha" (wrap)
        XCTAssertEqual(CandidateWindow.shared.selectedCandidate(), "alpha")
    }

    // MARK: - moveActiveColumnLeft() — candidates only (no literal)

    func testSelectPreviousWithoutLiteralWrapsFromFirstToLast() {
        show(candidates: ["alpha", "beta", "gamma"], literal: nil)
        CandidateWindow.shared.moveActiveColumnLeft() // wrap to "gamma"
        XCTAssertEqual(CandidateWindow.shared.selectedCandidate(), "gamma")
    }

    func testSelectPreviousWithoutLiteralMovesBackward() {
        show(candidates: ["alpha", "beta", "gamma"], literal: nil)
        CandidateWindow.shared.moveActiveColumnRight() // → "beta"
        CandidateWindow.shared.moveActiveColumnLeft() // → "alpha"
        XCTAssertEqual(CandidateWindow.shared.selectedCandidate(), "alpha")
    }

    // MARK: - Degenerate: single candidate, no literal

    func testSingleCandidateNoLiteralSelectNextWrapsToItself() {
        // Row 0 has 1 column; cycling right stays at col 0.
        show(candidates: ["only"], literal: nil)
        CandidateWindow.shared.moveActiveColumnRight()
        XCTAssertEqual(CandidateWindow.shared.selectedCandidate(), "only")
    }

    func testSingleCandidateNoLiteralSelectPreviousWrapsToItself() {
        show(candidates: ["only"], literal: nil)
        CandidateWindow.shared.moveActiveColumnLeft()
        XCTAssertEqual(CandidateWindow.shared.selectedCandidate(), "only")
    }

    // MARK: - Degenerate: literal only, no candidates

    func testLiteralOnlyIsLiteralSelectedTrue() {
        // guard !candidates.isEmpty || literalText != nil: passes with literal even when candidates=[].
        show(candidates: [], literal: "hel")
        XCTAssertTrue(CandidateWindow.shared.isLiteralSelected)
        XCTAssertNil(CandidateWindow.shared.selectedCandidate())
    }

    func testLiteralOnlySelectNextStaysOnLiteral() {
        // Row 0 has 1 column (literal only); cycling right stays at col 0.
        show(candidates: [], literal: "hel")
        CandidateWindow.shared.moveActiveColumnRight()
        XCTAssertTrue(CandidateWindow.shared.isLiteralSelected)
        XCTAssertNil(CandidateWindow.shared.selectedCandidate())
    }

    func testLiteralOnlySelectPreviousStaysOnLiteral() {
        show(candidates: [], literal: "hel")
        CandidateWindow.shared.moveActiveColumnLeft()
        XCTAssertTrue(CandidateWindow.shared.isLiteralSelected)
        XCTAssertNil(CandidateWindow.shared.selectedCandidate())
    }

    // MARK: - hide() resets logical state

    func testHideResetsSelectedCandidateToNil() {
        show(candidates: ["hello"], literal: nil)
        CandidateWindow.shared.moveActiveColumnRight() // advance past "hello" → wraps, but still "hello"
        CandidateWindow.shared.hide()
        XCTAssertNil(CandidateWindow.shared.selectedCandidate())
    }

    func testHideResetsIsLiteralSelectedToFalse() {
        show(candidates: ["hello"], literal: "hel")
        // isLiteralSelected is true at col 0 (literal slot).
        CandidateWindow.shared.hide()
        XCTAssertFalse(CandidateWindow.shared.isLiteralSelected)
    }

    func testSelectNextAfterHideDoesNothing() {
        // After hide(): gridState is nil — moveActiveColumnRight() early-returns, nothing changes.
        show(candidates: ["hello"], literal: nil)
        CandidateWindow.shared.hide()
        CandidateWindow.shared.moveActiveColumnRight()
        XCTAssertNil(CandidateWindow.shared.selectedCandidate())
        XCTAssertFalse(CandidateWindow.shared.isLiteralSelected)
    }

    func testSelectPreviousAfterHideDoesNothing() {
        show(candidates: ["hello"], literal: nil)
        CandidateWindow.shared.hide()
        CandidateWindow.shared.moveActiveColumnLeft()
        XCTAssertNil(CandidateWindow.shared.selectedCandidate())
    }

    // MARK: - selectedCandidate() column mapping with literal slot

    func testSelectedCandidateReturnsCorrectElementAtEachColumn() {
        // Row 0 with literal: col 0 = literal (nil), col 1-3 = candidates.
        let candidates = ["first", "second", "third"]
        show(candidates: candidates, literal: "test")

        // col 0 → literal → nil
        XCTAssertNil(CandidateWindow.shared.selectedCandidate())

        CandidateWindow.shared.moveActiveColumnRight() // col 1 → predictions[0]
        XCTAssertEqual(CandidateWindow.shared.selectedCandidate(), "first")

        CandidateWindow.shared.moveActiveColumnRight() // col 2 → predictions[1]
        XCTAssertEqual(CandidateWindow.shared.selectedCandidate(), "second")

        CandidateWindow.shared.moveActiveColumnRight() // col 3 → predictions[2]
        XCTAssertEqual(CandidateWindow.shared.selectedCandidate(), "third")
    }

    func testSelectedCandidateWithoutLiteralMapsDirectly() {
        // Without a literal: col 0 → predictions[0], col 1 → predictions[1].
        let candidates = ["alpha", "beta"]
        show(candidates: candidates, literal: nil)

        XCTAssertEqual(CandidateWindow.shared.selectedCandidate(), "alpha") // col 0
        CandidateWindow.shared.moveActiveColumnRight()
        XCTAssertEqual(CandidateWindow.shared.selectedCandidate(), "beta") // col 1
    }

    // MARK: - isLiteralSelected false when literal is absent

    func testIsLiteralSelectedIsFalseWhenNoLiteralEvenAtCol0() {
        // Col 0 + no literal: isLiteralSelected = false (hasLiteral = false).
        show(candidates: ["word"], literal: nil)
        XCTAssertFalse(CandidateWindow.shared.isLiteralSelected)
    }

    // MARK: - Full round-trip: navigate to every column and back

    func testFullCycleWithLiteralAndTwoCandidates() {
        // Cycle: literal → A → B → literal (right) then
        //        literal → B → A → literal (left).
        show(candidates: ["A", "B"], literal: "ab")

        // Forward cycle
        XCTAssertNil(CandidateWindow.shared.selectedCandidate()) // literal
        CandidateWindow.shared.moveActiveColumnRight()
        XCTAssertEqual(CandidateWindow.shared.selectedCandidate(), "A")
        CandidateWindow.shared.moveActiveColumnRight()
        XCTAssertEqual(CandidateWindow.shared.selectedCandidate(), "B")
        CandidateWindow.shared.moveActiveColumnRight()
        XCTAssertNil(CandidateWindow.shared.selectedCandidate()) // wrapped to literal

        // Backward from literal
        CandidateWindow.shared.moveActiveColumnLeft()
        XCTAssertEqual(CandidateWindow.shared.selectedCandidate(), "B")
        CandidateWindow.shared.moveActiveColumnLeft()
        XCTAssertEqual(CandidateWindow.shared.selectedCandidate(), "A")
        CandidateWindow.shared.moveActiveColumnLeft()
        XCTAssertNil(CandidateWindow.shared.selectedCandidate()) // wrapped to literal
    }
}
