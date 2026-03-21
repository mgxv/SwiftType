import AppKit
@testable import SwiftType
import XCTest

/// Tests for the CandidateWindow lazy-loading signal and prediction buffer update.
///
/// `predictionsNeededCountForDownArrow()` is the sole entry point through which
/// `InputController` decides whether to fetch more predictions before expanding the
/// grid. This critical path had zero test coverage before these tests were added.
///
/// All tests use the default column count (5) and the default `maxVisibleRows` as
/// configured in `ThemeManager.shared` at test time (3 by default). Prediction counts
/// in each test are calculated from the grid geometry documented in `GridCandidateState`.
@MainActor final class CandidateWindowGridTests: XCTestCase {
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

    // MARK: - predictionsNeededCountForDownArrow — nil when hidden

    func testPredictionsNeededNilWhenHidden() {
        // gridState == nil after hide() — the function must return nil.
        XCTAssertNil(CandidateWindow.shared.predictionsNeededCountForDownArrow())
    }

    // MARK: - predictionsNeededCountForDownArrow — no literal

    /// With C=5, hasLiteral=false, activeRow=0:
    ///   nextRow = 1, targetRow = 3
    ///   maxIdx = maxPredictionIndexNeeded(throughRow:3, noLiteral) = (3+1)*5 - 1 = 19
    ///   Need ≥ 20 predictions for the buffer to cover the prefetch window.
    func testPredictionsNeededReturnsFetchCountWhenBufferIsTooShort() {
        // 5 predictions loaded — nowhere near the 20 needed to cover prefetch to row 3.
        show(candidates: Array(repeating: "word", count: 5), literal: nil)
        let needed = CandidateWindow.shared.predictionsNeededCountForDownArrow()
        XCTAssertNotNil(needed)
        XCTAssertEqual(needed, 20,
                       "Should request 20 predictions (maxIdx=19, return maxIdx+1)")
    }

    func testPredictionsNeededNilWhenBufferCoversPreFetch() {
        // 20 predictions covers rows 0-3 fully (maxIdx = 19, 19 < 20 is false → nil).
        show(candidates: Array(repeating: "word", count: 20), literal: nil)
        XCTAssertNil(CandidateWindow.shared.predictionsNeededCountForDownArrow(),
                     "Buffer already covers the prefetch window — no fetch needed")
    }

    func testPredictionsNeededBoundary19ReturnsCount() {
        // 19 predictions: maxIdx=19, 19 >= 19 → must fetch.
        show(candidates: Array(repeating: "word", count: 19), literal: nil)
        let needed = CandidateWindow.shared.predictionsNeededCountForDownArrow()
        XCTAssertNotNil(needed)
        XCTAssertEqual(needed, 20)
    }

    // MARK: - predictionsNeededCountForDownArrow — with literal

    /// With C=5, hasLiteral=true, activeRow=0:
    ///   nextRow = 1, targetRow = 3
    ///   Unified array = ["hel"] + 5 words = 6 items.
    ///   maxIdx = maxPredictionIndexNeeded(throughRow:3) = (3+1)*5 - 1 = 19
    ///   19 >= 6 → need 20 items in unified array (literal + 19 words).
    func testPredictionsNeededWithLiteralReturnsFetchCount() {
        show(candidates: Array(repeating: "word", count: 5), literal: "hel")
        let needed = CandidateWindow.shared.predictionsNeededCountForDownArrow()
        XCTAssertNotNil(needed)
        XCTAssertEqual(needed, 20,
                       "With literal, unified maxIdx=19 so return 20")
    }

    func testPredictionsNeededWithLiteralNilWhenCovered() {
        // Unified array = ["hel"] + 19 words = 20 items; maxIdx=19, 19 < 20 → nil.
        show(candidates: Array(repeating: "word", count: 19), literal: "hel")
        XCTAssertNil(CandidateWindow.shared.predictionsNeededCountForDownArrow())
    }

    // MARK: - updatePredictions — replaces buffer without resetting navigation

    func testUpdatePredictionsReplacesBuffer() {
        // Show 2 predictions, then expand to add more via updatePredictions.
        show(candidates: ["alpha", "beta"], literal: nil)
        CandidateWindow.shared.updatePredictions(["alpha", "beta", "gamma", "delta", "epsilon"])
        // After update, the selected candidate at col 0 is the first of the new buffer.
        XCTAssertEqual(CandidateWindow.shared.selectedCandidate(), "alpha")
    }

    func testUpdatePredictionsPreservesActiveColumn() {
        // Advance to col 1, then update — column must be preserved.
        show(candidates: ["first", "second", "third"], literal: nil)
        CandidateWindow.shared.moveActiveColumnRight() // → col 1, "second"
        CandidateWindow.shared.updatePredictions(["first", "second", "third", "fourth", "fifth"])
        XCTAssertEqual(CandidateWindow.shared.selectedCandidate(), "second",
                       "Active column must be preserved after updatePredictions")
    }

    func testUpdatePredictionsWhenHiddenIsHarmless() {
        // Calling updatePredictions() when gridState == nil must not crash.
        CandidateWindow.shared.hide()
        CandidateWindow.shared.updatePredictions(["a", "b", "c"])
        XCTAssertNil(CandidateWindow.shared.selectedCandidate())
    }

    // MARK: - updatePredictions — hasLiteral=true preserves the literal slot

    func testUpdatePredictionsWithLiteralPreservesLiteralSlot() {
        // Arrange: show with a literal at row-0, col-0.
        // The cursor starts on the literal slot (col 0 → isLiteralSelected = true).
        show(candidates: ["hello", "help"], literal: "hel")
        XCTAssertTrue(CandidateWindow.shared.isLiteralSelected,
                      "Precondition: literal slot must be selected after show()")

        // Act: simulate the lazy-load path — InputController passes only the new prediction
        // batch (no literal) to updatePredictions; the window preserves predictions[0] internally.
        CandidateWindow.shared.updatePredictions(["hello", "help", "helmet", "held", "helm"])

        // Assert: the literal slot is still selected after the update.
        XCTAssertTrue(CandidateWindow.shared.isLiteralSelected,
                      "updatePredictions must preserve the literal slot when hasLiteral is true")
        XCTAssertNil(CandidateWindow.shared.selectedCandidate(),
                     "selectedCandidate() must return nil when the literal is selected")
    }

    func testUpdatePredictionsWithLiteralNewPredictionsAccessible() {
        // Arrange: show with a literal; advance past it to column 1 (first prediction).
        show(candidates: ["hello"], literal: "hel")
        CandidateWindow.shared.moveActiveColumnRight() // col 0 → col 1, "hello"
        XCTAssertEqual(CandidateWindow.shared.selectedCandidate(), "hello",
                       "Precondition: col 1 should show 'hello' before update")

        // Act: update predictions with a larger batch.
        CandidateWindow.shared.updatePredictions(["hello", "help", "helmet"])

        // Assert: col 1 still shows "hello" (active column preserved).
        XCTAssertEqual(CandidateWindow.shared.selectedCandidate(), "hello",
                       "Col 1 must still show 'hello' after update (active column preserved)")

        // Verify the new predictions are accessible by cycling forward.
        CandidateWindow.shared.moveActiveColumnRight() // col 2 → "help"
        XCTAssertEqual(CandidateWindow.shared.selectedCandidate(), "help",
                       "Col 2 must show the second new prediction 'help'")
    }

    func testUpdatePredictionsWithLiteralDoesNotDuplicateLiteral() {
        // The literal "hel" lives at predictions[0] and must not appear again in the
        // prediction slots after updatePredictions replaces predictions[1…].
        show(candidates: ["hello", "help"], literal: "hel")

        // Advance to col 1 to read the first prediction slot.
        CandidateWindow.shared.moveActiveColumnRight()
        let beforeUpdate = CandidateWindow.shared.selectedCandidate()
        XCTAssertEqual(beforeUpdate, "hello")

        // Act: update with a fresh set of predictions.
        CandidateWindow.shared.updatePredictions(["world", "words"])

        // After update, col 1 must contain the first *new* prediction, not the literal.
        XCTAssertEqual(CandidateWindow.shared.selectedCandidate(), "world",
                       "Col 1 after update must be 'world' — the new batch — not the literal 'hel'")
    }

    // MARK: - predictionsNeededCountForDownArrow after row navigation

    func testPredictionsNeededUpdatesAfterMovingDown() {
        // Show enough to expand but not enough to pre-fill far ahead.
        // With 20 predictions (no literal), initial check returns nil (fully covered).
        // After expanding row down once (activeRow moves from 0 to 1):
        //   nextRow = 2, targetRow = 4
        //   maxIdx (noLiteral, row 4) = (4+1)*5 - 1 = 24
        //   20 < 25 → should now require a fetch of 25.
        show(candidates: Array(repeating: "word", count: 20), literal: nil)
        // Initial check: covered (row 0 → prefetch to row 3 costs ≤ 20 preds).
        XCTAssertNil(CandidateWindow.shared.predictionsNeededCountForDownArrow())

        // Expand grid (first Down press): isExpanded = true, activeRow stays 0.
        CandidateWindow.shared.moveActiveRowDown()
        // Second Down press would move activeRow to 1 — check again.
        CandidateWindow.shared.moveActiveRowDown() // activeRow = 1
        let needed = CandidateWindow.shared.predictionsNeededCountForDownArrow()
        XCTAssertNotNil(needed)
        XCTAssertEqual(needed, 25,
                       "After moving to row 1, prefetch window extends to row 4 (maxIdx=24, return 25)")
    }
}
