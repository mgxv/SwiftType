@testable import SwiftType
import XCTest

/// Tests for the interaction between InputState and TypingRules.
///
/// InputState stores typingRules as a property that persists across reset() calls.
/// These tests verify the contract: rules survive resets, can be swapped, and
/// affect composition behavior correctly.
@MainActor final class InputStateRulesInteractionTests: XCTestCase {
    var state: InputState!

    override func setUp() async throws {
        state = InputState()
    }

    // MARK: - Default rules

    func testDefaultRulesAreEnglish() {
        XCTAssertTrue(state.typingRules is EnglishTypingRules)
    }

    func testDefaultRulesInsertTrailingSpace() {
        XCTAssertTrue(state.typingRules.insertsTrailingSpace)
    }

    // MARK: - Rules survive reset

    func testResetPreservesEnglishRules() {
        state.typingRules = EnglishTypingRules.shared
        state.compositionBuffer = "test"
        state.reset()
        XCTAssertTrue(state.typingRules is EnglishTypingRules)
    }

    func testResetPreservesGermanRules() {
        state.typingRules = GermanTypingRules.shared
        state.compositionBuffer = "test"
        state.reset()
        XCTAssertTrue(state.typingRules is GermanTypingRules)
    }

    func testResetPreservesRulesWhileClearingComposition() {
        state.typingRules = GermanTypingRules.shared
        state.compositionBuffer = "Hallo"
        state.currentPredictions = ["Hallo", "Halt"]
        state.isNextWordMode = true

        state.reset()

        XCTAssertTrue(state.typingRules is GermanTypingRules, "Rules must survive reset")
        XCTAssertEqual(state.compositionBuffer, "", "Buffer must be cleared")
        XCTAssertTrue(state.currentPredictions.isEmpty, "Predictions must be cleared")
        XCTAssertFalse(state.isNextWordMode, "Next-word mode must be cleared")
    }

    // MARK: - Rules can be swapped

    func testSwappingRulesFromEnglishToGerman() {
        XCTAssertTrue(state.typingRules is EnglishTypingRules)
        state.typingRules = GermanTypingRules.shared
        XCTAssertTrue(state.typingRules is GermanTypingRules)
    }

    func testSwappedRulesAffectCharacterSets() {
        state.typingRules = EnglishTypingRules.shared
        XCTAssertFalse(state.typingRules.compositionContinuationMarks.contains("-"))

        state.typingRules = GermanTypingRules.shared
        XCTAssertTrue(state.typingRules.compositionContinuationMarks.contains("-"),
                      "German rules include hyphen as continuation mark")
    }

    func testSwappedRulesAffectSentenceEnders() {
        state.typingRules = EnglishTypingRules.shared
        XCTAssertFalse(state.typingRules.sentenceEndingChars.contains(":"))

        state.typingRules = GermanTypingRules.shared
        XCTAssertTrue(state.typingRules.sentenceEndingChars.contains(":"),
                      "German rules include colon as sentence ender")
    }

    // MARK: - Context + rules interaction

    func testAppendToContextWorksRegardlessOfRules() {
        state.typingRules = GermanTypingRules.shared
        state.appendToContext("Hallo Welt. ")
        XCTAssertEqual(state.typingContext, "Hallo Welt. ")
    }

    func testContextTrimmingWorksWithGermanRules() {
        state.typingRules = GermanTypingRules.shared
        let longText = String(repeating: "Wort ", count: 100)
        state.appendToContext(longText)
        XCTAssertLessThanOrEqual(state.typingContext.count, InputState.maxContextLength)
    }

    // MARK: - Multiple resets

    func testMultipleResetsPreserveRules() {
        state.typingRules = GermanTypingRules.shared
        state.reset()
        state.compositionBuffer = "test"
        state.reset()
        state.reset()
        XCTAssertTrue(state.typingRules is GermanTypingRules)
    }
}
