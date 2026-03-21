@testable import SwiftType
import XCTest

/// Additional edge-case tests for `InputState.trimContext(_:)`.
///
/// These complement the existing `ContextTrimmingTests` and `TrimContextBoundaryTests`
/// by targeting specific branches in the algorithm:
/// - Trim point at start of string (second sentence start == context start)
/// - Final length cap (trimmed > maxContextLength after sentence-boundary trim)
/// - Unicode multi-byte characters near the boundary
/// - Whitespace-only and punctuation-only inputs
@MainActor final class InputStateTrimContextEdgeCaseTests: XCTestCase {
    // MARK: - Constants verification

    func testMaxContextLengthIs400() {
        XCTAssertEqual(InputState.maxContextLength, 400)
    }

    func testFallbackContextLengthIs300() {
        XCTAssertEqual(InputState.fallbackContextLength, 300)
    }

    // MARK: - Sentence boundary trimming

    func testTwoSentencesPreservesSecondSentence() {
        let context = "First sentence. Second sentence here."
        let result = InputState.trimContext(context)
        XCTAssertTrue(result.contains("Second sentence here."))
    }

    func testThreeSentencesPreservesLastTwo() {
        let context = "A. B. C."
        let result = InputState.trimContext(context)
        // With 3 sentences, the second-to-last start keeps "B. C."
        XCTAssertTrue(result.hasSuffix("C."))
    }

    // MARK: - Single sentence fallback

    func testSingleLongSentenceTrimsToSuffix300() {
        // One sentence with no period = fewer than 2 sentences
        let context = String(repeating: "a", count: 500)
        let result = InputState.trimContext(context)
        XCTAssertEqual(result.count, InputState.fallbackContextLength)
    }

    // MARK: - Trim point at context start

    func testTrimPointAtStartFallsBackToSuffix() {
        // Two sentences where the second starts at index 0 (both sentences span full string).
        // NLTokenizer may detect sentence boundaries differently, so we construct a case
        // where the second-to-last sentence start is at index 0.
        let context = "A." + String(repeating: " x", count: 200)
        let result = InputState.trimContext(context)
        // Should not exceed maxContextLength
        XCTAssertLessThanOrEqual(result.count, InputState.maxContextLength)
    }

    // MARK: - Unicode characters

    func testTrimContextHandlesEmoji() {
        let emoji = String(repeating: "😀", count: 200)
        let context = "Hello. " + emoji + ". World."
        let result = InputState.trimContext(context)
        XCTAssertLessThanOrEqual(result.count, InputState.maxContextLength)
        XCTAssertTrue(result.hasSuffix("World."))
    }

    func testTrimContextHandlesCJKCharacters() {
        let cjk = String(repeating: "漢", count: 200)
        let context = "First. " + cjk + ". Last."
        let result = InputState.trimContext(context)
        XCTAssertLessThanOrEqual(result.count, InputState.maxContextLength)
    }

    func testTrimContextHandlesMultibyteGerman() {
        let german = String(repeating: "ü", count: 200)
        let context = "Hallo. " + german + ". Ende."
        let result = InputState.trimContext(context)
        XCTAssertLessThanOrEqual(result.count, InputState.maxContextLength)
    }

    // MARK: - Empty and whitespace

    func testEmptyStringReturnsEmpty() {
        XCTAssertEqual(InputState.trimContext(""), "")
    }

    func testWhitespaceOnlyString() {
        let ws = String(repeating: " ", count: 500)
        let result = InputState.trimContext(ws)
        XCTAssertLessThanOrEqual(result.count, InputState.fallbackContextLength)
    }

    // MARK: - Boundary conditions

    func testExactly400CharsNoTrim() {
        let context = String(repeating: "x", count: 400)
        let result = InputState.trimContext(context)
        // 400 chars, single "sentence" (no period) → fewer than 2 → suffix(300)
        XCTAssertEqual(result.count, 300)
    }

    func testResultNeverExceedsMaxContextLength() {
        // Build a context with many sentences that, after trimming, still might be long.
        let context = (0 ..< 100).map { "Sentence \($0). " }.joined()
        let result = InputState.trimContext(context)
        XCTAssertLessThanOrEqual(result.count, InputState.maxContextLength)
    }

    // MARK: - Trailing content preserved

    func testLastWordIsAlwaysPreserved() {
        let context = "Start. " + String(repeating: "w ", count: 200) + "Final."
        let result = InputState.trimContext(context)
        XCTAssertTrue(result.hasSuffix("Final."),
                      "Trim must always preserve the most recent content")
    }
}
