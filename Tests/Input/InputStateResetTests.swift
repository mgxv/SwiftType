@testable import SwiftType
import XCTest

/// Tests that `InputState.reset()` correctly preserves `typingRules` across resets
/// while clearing all composition state, and that the named constants match the
/// documented thresholds used by the context trimming algorithm.
@MainActor final class InputStateResetTests: XCTestCase {
    private var state: InputState!

    override func setUp() async throws {
        state = InputState()
    }

    // MARK: - typingRules preservation across reset

    func testResetPreservesDefaultEnglishRules() {
        state.compositionBuffer = "test"
        state.reset()
        XCTAssertTrue(state.typingRules is EnglishTypingRules,
                      "Default typingRules must survive reset()")
    }

    func testResetPreservesGermanRulesAfterSwitch() {
        state.typingRules = GermanTypingRules.shared
        state.compositionBuffer = "test"
        state.isNextWordMode = true
        state.reset()
        XCTAssertTrue(state.typingRules is GermanTypingRules,
                      "typingRules assigned before reset() must survive")
    }

    func testResetPreservesNonDefaultRulesAfterSwitch() {
        state.typingRules = GermanTypingRules.shared
        state.didAutoInsertTrailingSpace = true
        state.reset()
        XCTAssertTrue(state.typingRules is GermanTypingRules)
    }

    func testMultipleResetsPreserveRules() {
        state.typingRules = GermanTypingRules.shared
        state.reset()
        state.compositionBuffer = "abc"
        state.reset()
        state.isNextWordMode = true
        state.reset()
        XCTAssertTrue(state.typingRules is GermanTypingRules,
                      "typingRules must survive any number of reset() calls")
    }

    func testResetAfterRulesSwitchClearsComposition() {
        state.typingRules = GermanTypingRules.shared
        state.compositionBuffer = "hallo"
        state.currentPredictions = ["hallo"]
        state.isNextWordMode = true
        state.reset()

        XCTAssertEqual(state.compositionBuffer, "")
        XCTAssertTrue(state.currentPredictions.isEmpty)
        XCTAssertFalse(state.isNextWordMode)
        XCTAssertTrue(state.typingRules is GermanTypingRules)
    }

    // MARK: - Named constants

    func testMaxContextLengthIs400() {
        XCTAssertEqual(InputState.maxContextLength, 400)
    }

    func testFallbackContextLengthIs300() {
        XCTAssertEqual(InputState.fallbackContextLength, 300)
    }

    func testFallbackIsLessThanMax() {
        XCTAssertLessThan(InputState.fallbackContextLength, InputState.maxContextLength,
                          "Fallback must be smaller than max to prevent infinite trim loops")
    }

    // MARK: - Threshold boundary with named constants

    func testAppendDoesNotTrimAtExactlyMaxContextLength() {
        state.appendToContext(String(repeating: "x", count: InputState.maxContextLength))
        XCTAssertEqual(state.typingContext.count, InputState.maxContextLength)
    }

    func testAppendTrimsAtMaxContextLengthPlusOne() {
        state.appendToContext(String(repeating: "x", count: InputState.maxContextLength + 1))
        XCTAssertLessThanOrEqual(state.typingContext.count, InputState.maxContextLength)
    }

    func testTrimContextFallbackNeverExceedsFallbackLength() {
        // No sentence boundaries → suffix(fallbackContextLength)
        let noSentences = String(repeating: "a", count: 500)
        let result = InputState.trimContext(noSentences)
        XCTAssertEqual(result.count, InputState.fallbackContextLength)
    }

    // MARK: - Default state

    func testDefaultTypingRulesIsEnglish() {
        XCTAssertTrue(state.typingRules is EnglishTypingRules)
    }

    func testDefaultCompositionBufferIsEmpty() {
        XCTAssertEqual(state.compositionBuffer, "")
    }

    func testDefaultPredictionsIsEmpty() {
        XCTAssertTrue(state.currentPredictions.isEmpty)
    }

    func testDefaultTypingContextIsEmpty() {
        XCTAssertEqual(state.typingContext, "")
    }

    func testDefaultIsNextWordModeIsFalse() {
        XCTAssertFalse(state.isNextWordMode)
    }

    func testDefaultDidAutoInsertTrailingSpaceIsFalse() {
        XCTAssertFalse(state.didAutoInsertTrailingSpace)
    }
}
