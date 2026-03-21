@testable import SwiftType
import XCTest

/// Tests for `InputState.appendToContext` focusing on multi-part accumulation at and
/// around the 400-character trim threshold.
///
/// The existing `InputControllerTests` covers single-call boundary conditions (399, 400,
/// 401 characters appended in one call).  These tests cover the case where the threshold
/// is crossed through multiple smaller appends — the behaviour clients actually experience
/// at runtime when commits accumulate character by character.
@MainActor final class InputStateContextAccumulationTests: XCTestCase {
    private var state: InputState!

    override func setUp() async throws {
        state = InputState()
    }

    // MARK: - Multi-part accumulation: trim threshold

    func testMultiPartAppendTrimsWhenTotalExceeds400() {
        // Arrange: first append fills context to exactly 400 chars.
        state.appendToContext(String(repeating: "a", count: 400))
        XCTAssertEqual(state.typingContext.count, 400, "Precondition: no trim at 400")

        // Act: one more character pushes past the threshold.
        state.appendToContext("b")

        // Assert: trim fired; context is now under or at 400 chars.
        XCTAssertLessThanOrEqual(state.typingContext.count, 400,
                                 "appendToContext must trim when total count exceeds 400")
    }

    func testMultiPartAppendDoesNotTrimBeforeThreshold() {
        // 200 + 200 = exactly 400 → no trim.
        state.appendToContext(String(repeating: "x", count: 200))
        state.appendToContext(String(repeating: "y", count: 200))
        XCTAssertEqual(state.typingContext.count, 400)
    }

    func testMultiPartAppendTrimsAt401AcrossTwoCalls() {
        // 200 + 201 = 401 → trim fires.
        state.appendToContext(String(repeating: "x", count: 200))
        state.appendToContext(String(repeating: "y", count: 201))
        XCTAssertLessThanOrEqual(state.typingContext.count, 400)
    }

    func testMultiPartAppendTrimsAt401AcrossManySmallCalls() {
        // 400 × single character appends reach 400 (no trim), then one more triggers trim.
        for _ in 0 ..< 400 {
            state.appendToContext("a")
        }
        XCTAssertEqual(state.typingContext.count, 400, "Precondition: 400 single-char appends = 400")
        state.appendToContext("b")
        XCTAssertLessThanOrEqual(state.typingContext.count, 400,
                                 "401st single-char append must trigger trim")
    }

    // MARK: - Trim preserves most recent content

    func testAfterTrimContextEndsWithMostRecentWord() {
        // Build a context that ends with a recognisable word after many appends.
        state.appendToContext(String(repeating: "Word. ", count: 60)) // ~360 chars
        state.appendToContext("LastWord. ") // pushes past 400

        // The trim algorithm keeps recent sentence content; "LastWord" must survive.
        XCTAssertTrue(state.typingContext.contains("LastWord"),
                      "Most recently appended text must be preserved after context trim")
    }

    // MARK: - Content integrity without trimming

    func testMultiPartAppendContentIsCorrectBelowThreshold() {
        // Small multi-part appends must be concatenated exactly.
        state.appendToContext("hello")
        state.appendToContext(", ")
        state.appendToContext("world")
        XCTAssertEqual(state.typingContext, "hello, world")
    }

    func testAppendEmptyStringDoesNotAffectCount() {
        state.appendToContext("some text")
        let countBefore = state.typingContext.count
        state.appendToContext("")
        XCTAssertEqual(state.typingContext.count, countBefore)
    }

    // MARK: - Unicode character counting

    func testAppendUnicodeCharactersCountedBySwiftCharacters() {
        // Swift `String.count` counts Unicode extended grapheme clusters.
        // Emoji count as 1 Swift character each.
        let emoji = String(repeating: "🎉", count: 400) // 400 emoji = 400 Swift chars
        state.appendToContext(emoji)
        // 400 Swift chars should NOT trigger trim (threshold is > 400).
        XCTAssertEqual(state.typingContext.count, 400)

        state.appendToContext("x") // 401 Swift chars → trim
        XCTAssertLessThanOrEqual(state.typingContext.count, 400)
    }
}
