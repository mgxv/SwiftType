@testable import SwiftType
import XCTest

/// Tests for `CandidateWindow` updatePredictions, show/hide edge cases, and
/// the interaction between literal preservation and lazy loading.
@MainActor final class CandidateWindowUpdateTests: XCTestCase {
    override func setUp() async throws {
        CandidateWindow.shared.hide()
    }

    override func tearDown() async throws {
        CandidateWindow.shared.hide()
    }

    // MARK: - show() guard: empty candidates + nil literal hides

    func testShowWithEmptyCandidatesAndNilLiteralHides() {
        // First show something
        CandidateWindow.shared.show(candidates: ["alpha"], client: nil)
        XCTAssertTrue(CandidateWindow.shared.isVisible)

        // Then show empty
        CandidateWindow.shared.show(candidates: [], client: nil)
        XCTAssertFalse(CandidateWindow.shared.isVisible)
    }

    func testShowWithEmptyCandidatesButLiteralTextStaysVisible() {
        CandidateWindow.shared.show(candidates: [], literalText: "hel", client: nil)
        XCTAssertTrue(CandidateWindow.shared.isVisible)
    }

    // MARK: - hide() resets grid state

    func testHideResetsIsLiteralSelected() {
        CandidateWindow.shared.show(candidates: ["a"], literalText: "x", client: nil)
        XCTAssertTrue(CandidateWindow.shared.isLiteralSelected)
        CandidateWindow.shared.hide()
        XCTAssertFalse(CandidateWindow.shared.isLiteralSelected)
    }

    func testHideResetsSelectedCandidate() {
        CandidateWindow.shared.show(candidates: ["a", "b"], client: nil)
        XCTAssertNotNil(CandidateWindow.shared.selectedCandidate())
        CandidateWindow.shared.hide()
        XCTAssertNil(CandidateWindow.shared.selectedCandidate())
    }

    func testHideResetsPredictionIndexAt() {
        CandidateWindow.shared.show(candidates: ["a"], client: nil)
        XCTAssertNotNil(CandidateWindow.shared.predictionIndexAt(gridColumn: 0))
        CandidateWindow.shared.hide()
        XCTAssertNil(CandidateWindow.shared.predictionIndexAt(gridColumn: 0))
    }

    // MARK: - updatePredictions preserves literal

    func testUpdatePredictionsPreservesLiteralText() {
        CandidateWindow.shared.show(candidates: ["old"], literalText: "hel", client: nil)
        CandidateWindow.shared.updatePredictions(["new1", "new2"])

        // Literal at col 0 must still be present
        XCTAssertTrue(CandidateWindow.shared.isLiteralAt(gridColumn: 0))
        // Predictions updated
        XCTAssertEqual(CandidateWindow.shared.predictionIndexAt(gridColumn: 1), 1)
    }

    func testUpdatePredictionsWithoutLiteralReplacesAll() {
        CandidateWindow.shared.show(candidates: ["old1", "old2"], client: nil)
        CandidateWindow.shared.updatePredictions(["new1", "new2", "new3"])

        XCTAssertFalse(CandidateWindow.shared.isLiteralAt(gridColumn: 0))
        XCTAssertEqual(CandidateWindow.shared.selectedCandidate(), "new1")
    }

    // MARK: - needsMorePredictionsForDownArrow

    func testNeedsMorePredictionsReturnsFalseWhenHidden() {
        XCTAssertFalse(CandidateWindow.shared.needsMorePredictionsForDownArrow())
    }

    func testNeedsMorePredictionsReturnsFalseWhenBufferSufficient() {
        // Show enough predictions to cover row 0 + down + 1-row prefetch at C=5
        // That's row 2 max index = (2+1)*5 - 1 = 14, so 15 predictions needed
        CandidateWindow.shared.show(candidates: (0 ..< 20).map { "p\($0)" }, client: nil)
        XCTAssertFalse(CandidateWindow.shared.needsMorePredictionsForDownArrow())
    }

    func testNeedsMorePredictionsReturnsTrueWhenInsufficient() {
        // Only 5 predictions (1 row at C=5). Down needs row 2 coverage.
        CandidateWindow.shared.show(candidates: (0 ..< 5).map { "p\($0)" }, client: nil)
        XCTAssertTrue(CandidateWindow.shared.needsMorePredictionsForDownArrow())
    }

    // MARK: - isLiteralAt edge cases

    func testIsLiteralAtCol0WhenNoLiteralIsFalse() {
        CandidateWindow.shared.show(candidates: ["a", "b"], client: nil)
        XCTAssertFalse(CandidateWindow.shared.isLiteralAt(gridColumn: 0))
    }

    func testIsLiteralAtCol1WithLiteralIsFalse() {
        CandidateWindow.shared.show(candidates: ["a"], literalText: "x", client: nil)
        XCTAssertFalse(CandidateWindow.shared.isLiteralAt(gridColumn: 1))
    }

    func testIsLiteralAtWhenHiddenIsFalse() {
        XCTAssertFalse(CandidateWindow.shared.isLiteralAt(gridColumn: 0))
    }

    // MARK: - show() replaces previous state

    func testShowReplacesGridState() {
        CandidateWindow.shared.show(candidates: ["a"], literalText: "x", client: nil)
        XCTAssertTrue(CandidateWindow.shared.isLiteralSelected)

        // Show without literal replaces the state
        CandidateWindow.shared.show(candidates: ["b", "c"], client: nil)
        XCTAssertFalse(CandidateWindow.shared.isLiteralSelected)
        XCTAssertEqual(CandidateWindow.shared.selectedCandidate(), "b")
    }

    // MARK: - Navigation after updatePredictions

    func testNavigationWorksAfterUpdatePredictions() {
        CandidateWindow.shared.show(candidates: (0 ..< 5).map { "p\($0)" }, client: nil)
        CandidateWindow.shared.updatePredictions((0 ..< 15).map { "p\($0)" })

        CandidateWindow.shared.moveActiveRowDown() // expand
        CandidateWindow.shared.moveActiveRowDown() // row 1
        CandidateWindow.shared.moveActiveColumnRight() // col 1

        let selected = CandidateWindow.shared.selectedCandidate()
        XCTAssertNotNil(selected)
    }
}
