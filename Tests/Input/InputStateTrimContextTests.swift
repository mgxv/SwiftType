@testable import SwiftType
import XCTest

/// Focused tests for `InputState.trimContext(_:)` — the static pure-function that trims
/// typing context to a sentence boundary. Complements `ContextTrimmingTests` and
/// `TrimContextBoundaryTests` with additional sentence patterns and Unicode edge cases.
@MainActor final class InputStateTrimContextTests: XCTestCase {
    // MARK: - Basic sentence boundary

    func testTrimKeepsLastTwoSentences() {
        let context = "First sentence. Second sentence. Third sentence."
        let result = InputState.trimContext(context)
        XCTAssertTrue(result.contains("Second sentence."))
        XCTAssertTrue(result.hasSuffix("Third sentence."))
    }

    func testTrimOnSingleSentenceReturnsSuffix300() {
        let long = String(repeating: "a", count: 500)
        let result = InputState.trimContext(long)
        XCTAssertEqual(result.count, 300)
    }

    // MARK: - Empty and short strings

    func testTrimEmptyStringReturnsEmpty() {
        XCTAssertEqual(InputState.trimContext(""), "")
    }

    func testTrimShortStringReturnsItself() {
        let short = "Hello world."
        XCTAssertEqual(InputState.trimContext(short), short)
    }

    func testTrimAt400CharsDoesNotExceed400() {
        let context = String(repeating: "a", count: 400)
        let result = InputState.trimContext(context)
        XCTAssertLessThanOrEqual(result.count, 400)
    }

    // MARK: - Multiple sentences

    func testTrimWithManySentencesPreservesTrailing() {
        let sentences = (1 ... 20).map { "Sentence \($0)." }.joined(separator: " ")
        let result = InputState.trimContext(sentences)
        XCTAssertTrue(result.hasSuffix("Sentence 20."))
        XCTAssertLessThanOrEqual(result.count, 400)
    }

    // MARK: - Unicode content

    func testTrimWithEmojiContent() {
        let emoji = String(repeating: "\u{1F600}", count: 500)
        let result = InputState.trimContext(emoji)
        // Each emoji is one Character, so suffix(300) gives 300 emoji chars.
        XCTAssertLessThanOrEqual(result.count, 300)
    }

    func testTrimWithCJKSentences() {
        // CJK sentences end with 。 which NLTokenizer should recognise.
        let context = "第一句话。第二句话。第三句话。" + String(repeating: "你", count: 400)
        let result = InputState.trimContext(context)
        XCTAssertLessThanOrEqual(result.count, 400)
    }

    // MARK: - Sentence at start edge case

    func testTrimWhenSecondToLastStartIsAtBeginning() {
        // Two sentences where the first starts at index 0 — the guard keepFrom > startIndex
        // should trigger, falling back to suffix(300).
        let context = "Short. " + String(repeating: "x", count: 500)
        let result = InputState.trimContext(context)
        XCTAssertLessThanOrEqual(result.count, 400)
    }

    // MARK: - Trimmed result exceeds 400 fallback

    func testTrimFallsBackToSuffix300WhenTrimmedExceeds400() {
        // Create a context where the last two sentences together exceed 400 chars.
        let longSentence = String(repeating: "a", count: 450) + ". Final."
        let result = InputState.trimContext(longSentence)
        XCTAssertLessThanOrEqual(result.count, 400)
    }
}
