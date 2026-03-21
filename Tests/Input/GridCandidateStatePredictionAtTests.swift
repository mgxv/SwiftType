@testable import SwiftType
import XCTest

/// Tests for `GridCandidateState.predictionAt(col:)` which returns the prediction
/// string at a given column of the active row. This method is used by
/// `CandidateWindow.selectedCandidate()` and number-key commit logic.
@MainActor final class GridCandidateStatePredictionAtTests: XCTestCase {
    // MARK: - Helpers

    private func makeState(
        predictions: [String],
        hasLiteral: Bool,
        columnCount: Int = 5,
        maxVisibleRows: Int = 3,
    ) -> GridCandidateState {
        GridCandidateState(
            columnCount: columnCount,
            hasLiteral: hasLiteral,
            maxVisibleRows: maxVisibleRows,
            predictions: predictions,
        )
    }

    // MARK: - predictionAt without literal

    func testPredictionAtCol0NoLiteralReturnsFirstPrediction() {
        let s = makeState(predictions: ["alpha", "beta", "gamma"], hasLiteral: false)
        XCTAssertEqual(s.predictionAt(col: 0), "alpha")
    }

    func testPredictionAtCol1NoLiteralReturnsSecondPrediction() {
        let s = makeState(predictions: ["alpha", "beta", "gamma"], hasLiteral: false)
        XCTAssertEqual(s.predictionAt(col: 1), "beta")
    }

    func testPredictionAtBeyondBufferReturnsNil() {
        let s = makeState(predictions: ["alpha", "beta"], hasLiteral: false)
        XCTAssertNil(s.predictionAt(col: 3))
    }

    // MARK: - predictionAt with literal

    func testPredictionAtCol0WithLiteralReturnsNil() {
        // col 0 on row 0 with literal is the literal slot, not a prediction
        let s = makeState(predictions: ["lit", "alpha", "beta"], hasLiteral: true)
        XCTAssertNil(s.predictionAt(col: 0))
    }

    func testPredictionAtCol1WithLiteralReturnsFirstPrediction() {
        let s = makeState(predictions: ["lit", "alpha", "beta"], hasLiteral: true)
        XCTAssertEqual(s.predictionAt(col: 1), "alpha")
    }

    // MARK: - predictionAt on non-active row

    func testPredictionAtReflectsActiveRow() {
        // 10 predictions, 5 cols → row 0: [p0..p4], row 1: [p5..p9]
        var s = makeState(predictions: (0 ..< 10).map { "p\($0)" }, hasLiteral: false)
        s.isExpanded = true
        s.activeRow = 1
        XCTAssertEqual(s.predictionAt(col: 0), "p5")
        XCTAssertEqual(s.predictionAt(col: 4), "p9")
    }

    // MARK: - predictionAt on partial row

    func testPredictionAtPartialRowReturnsNilForEmptySlots() {
        // 7 predictions, 5 cols → row 1: [p5, p6, nil, nil, nil]
        var s = makeState(predictions: (0 ..< 7).map { "p\($0)" }, hasLiteral: false)
        s.isExpanded = true
        s.activeRow = 1
        XCTAssertEqual(s.predictionAt(col: 0), "p5")
        XCTAssertEqual(s.predictionAt(col: 1), "p6")
        XCTAssertNil(s.predictionAt(col: 2))
    }

    // MARK: - selectedPrediction

    func testSelectedPredictionReturnsNilWhenLiteralSelected() {
        let s = makeState(predictions: ["lit", "alpha"], hasLiteral: true)
        XCTAssertTrue(s.isLiteralSelected)
        XCTAssertNil(s.selectedPrediction)
    }

    func testSelectedPredictionReturnsPredictionWhenNotLiteral() {
        var s = makeState(predictions: ["lit", "alpha", "beta"], hasLiteral: true)
        s.activeCol = 1
        XCTAssertEqual(s.selectedPrediction, "alpha")
    }

    func testSelectedPredictionNoLiteralAtOrigin() {
        let s = makeState(predictions: ["alpha", "beta"], hasLiteral: false)
        XCTAssertEqual(s.selectedPrediction, "alpha")
    }

    // MARK: - Empty state

    func testPredictionAtOnEmptyReturnsNil() {
        let s = makeState(predictions: [], hasLiteral: false)
        XCTAssertNil(s.predictionAt(col: 0))
    }

    func testSelectedPredictionOnEmptyReturnsNil() {
        let s = makeState(predictions: [], hasLiteral: false)
        XCTAssertNil(s.selectedPrediction)
    }

    // MARK: - C=3 variant

    func testPredictionAtC3Row1() {
        // 6 predictions in 3 cols → row 0: [p0,p1,p2], row 1: [p3,p4,p5]
        var s = makeState(predictions: (0 ..< 6).map { "p\($0)" }, hasLiteral: false, columnCount: 3)
        s.isExpanded = true
        s.activeRow = 1
        XCTAssertEqual(s.predictionAt(col: 0), "p3")
        XCTAssertEqual(s.predictionAt(col: 2), "p5")
    }

    // MARK: - C=7 variant

    func testPredictionAtC7WithLiteral() {
        // literal + 6 predictions in 7 cols → row 0: [lit, p0..p5]
        let predictions = ["lit"] + (0 ..< 6).map { "p\($0)" }
        let s = makeState(predictions: predictions, hasLiteral: true, columnCount: 7)
        XCTAssertNil(s.predictionAt(col: 0)) // literal
        XCTAssertEqual(s.predictionAt(col: 1), "p0")
        XCTAssertEqual(s.predictionAt(col: 6), "p5")
    }
}
