@testable import SwiftType
import XCTest

// MARK: - InputStateTests

@MainActor final class InputStateTests: XCTestCase {
    var state: InputState!

    override func setUp() async throws {
        state = InputState()
    }

    func testResetClearsAllFields() {
        // Populate all resettable fields with non-default values.
        state.compositionBuffer = "hello"
        state.currentPredictions = ["world"]
        state.typingContext = "some context"
        state.isNextWordMode = true
        state.didAutoInsertTrailingSpace = true

        state.reset()

        XCTAssertEqual(state.compositionBuffer, "")
        XCTAssertTrue(state.currentPredictions.isEmpty)
        XCTAssertEqual(state.typingContext, "")
        XCTAssertFalse(state.isNextWordMode)
        XCTAssertFalse(state.didAutoInsertTrailingSpace)
    }

    func testResetDoesNotClearTypingRules() {
        // typingRules is managed by refreshRules(), not reset().
        let rules = state.typingRules
        state.reset()
        XCTAssertTrue(type(of: state.typingRules) == type(of: rules))
    }

    func testAppendToContextAccumulates() {
        state.appendToContext("hello")
        state.appendToContext(" world")
        XCTAssertEqual(state.typingContext, "hello world")
    }

    func testAppendToContextTrimsWhenExceeding400Chars() {
        // Appending 401 chars triggers trimming.
        let longText = String(repeating: "a", count: 401)
        state.appendToContext(longText)
        XCTAssertLessThanOrEqual(state.typingContext.count, 400)
    }

    // MARK: - Context Accumulation Edge Cases

    func testAppendToContextAt399CharsDoesNotTrim() {
        // 399 characters should NOT trigger trimming (threshold is > 400).
        state.appendToContext(String(repeating: "x", count: 399))
        XCTAssertEqual(state.typingContext.count, 399)
    }

    func testAppendToContextAt400CharsDoesNotTrim() {
        // 400 characters exactly should NOT trigger trimming (threshold is > 400).
        state.appendToContext(String(repeating: "x", count: 400))
        XCTAssertEqual(state.typingContext.count, 400)
    }

    func testAppendToContextAt401CharsTrims() {
        // 401 characters triggers trimming.
        state.appendToContext(String(repeating: "x", count: 401))
        XCTAssertLessThanOrEqual(state.typingContext.count, 400)
    }

    func testAppendEmptyStringIsNoop() {
        state.appendToContext("hello")
        state.appendToContext("")
        XCTAssertEqual(state.typingContext, "hello")
    }

    func testResetAfterContextAccumulationClearsContext() {
        state.appendToContext("The quick brown fox. ")
        XCTAssertFalse(state.typingContext.isEmpty)
        state.reset()
        XCTAssertEqual(state.typingContext, "")
    }

    // MARK: - Composition State

    func testCompositionBufferDefaultsToEmpty() {
        XCTAssertEqual(state.compositionBuffer, "")
    }

    func testIsNextWordModeDefaultsToFalse() {
        XCTAssertFalse(state.isNextWordMode)
    }

    func testDidAutoInsertTrailingSpaceDefaultsToFalse() {
        XCTAssertFalse(state.didAutoInsertTrailingSpace)
    }

    func testMultipleResetsAreIdempotent() {
        state.compositionBuffer = "test"
        state.reset()
        state.reset() // second reset on already-clean state should not crash or corrupt
        XCTAssertEqual(state.compositionBuffer, "")
        XCTAssertEqual(state.typingContext, "")
    }
}

// MARK: - TrimContextTests

// InputState.trimContext(_:) is a pure static function and is directly testable
// without any IMK infrastructure. Comprehensive sentence-boundary cases are in
// ContextTrimmingTests.swift; these tests focus on the threshold boundary conditions.

@MainActor final class TrimContextBoundaryTests: XCTestCase {
    func testShortContextReturnedUnchanged() {
        let short = "Hello world."
        XCTAssertEqual(InputState.trimContext(short), short)
    }

    func testSingleSentenceReturnsLastChars() {
        // One sentence: fewer than 2 sentences → suffix(300).
        let sentence = String(repeating: "x", count: 350)
        let result = InputState.trimContext(sentence)
        XCTAssertLessThanOrEqual(result.count, 300)
    }

    func testTrimmedResultNeverExceeds400Chars() {
        // Build a string that, after trimming to the second-to-last sentence boundary,
        // might still be long. The algorithm caps at suffix(300) in that case.
        let manyShortSentences = (0 ..< 50).map { "Sentence \($0). " }.joined()
        let result = InputState.trimContext(manyShortSentences)
        XCTAssertLessThanOrEqual(result.count, 400)
    }

    func testTrimPreservesTrailingContent() {
        // The trim should always include the most recent text.
        let context = "First sentence. " + String(repeating: "x", count: 300) + ". Last word."
        let result = InputState.trimContext(context)
        XCTAssertTrue(result.hasSuffix("Last word."), "Trim must preserve the most recent sentence")
    }

    func testEmptyStringReturnsEmpty() {
        XCTAssertEqual(InputState.trimContext(""), "")
    }
}

// MARK: - TypingRules Capitalization Edge Cases

// These directly test the protocol default implementations that feed into
// InputController.updatePredictions — ensuring the rules component is solid
// before the full routing layer is exercised.

@MainActor final class CapitalizationEdgeCaseTests: XCTestCase {
    let rules = EnglishTypingRules.shared

    func testPreserveCapitalizationUppercaseOriginal() {
        let result = rules.preserveCapitalization(original: "Hello", suggested: "hello")
        XCTAssertEqual(result, "Hello")
    }

    func testPreserveCapitalizationLowercaseOriginalUnchanged() {
        let result = rules.preserveCapitalization(original: "hello", suggested: "world")
        XCTAssertEqual(result, "world")
    }

    func testPreserveCapitalizationEmptyOriginalUnchanged() {
        let result = rules.preserveCapitalization(original: "", suggested: "word")
        XCTAssertEqual(result, "word")
    }

    func testApplyCapitalizationUppercaseOriginalPreservesCase() {
        let result = rules.applyCapitalization(original: "H", suggested: "hello", context: "Go. ")
        XCTAssertEqual(result.first, "H")
    }

    func testApplyCapitalizationLowercaseOriginalStaysLowercase() {
        let result = rules.applyCapitalization(original: "h", suggested: "hello", context: "Go. ")
        XCTAssertEqual(result.first, "h")
    }

    func testApplyCapitalizationMidSentencePreservesOriginalCase() {
        let result = rules.applyCapitalization(original: "H", suggested: "hello", context: "The quick ")
        XCTAssertEqual(result.first, "H")
    }
}

// MARK: - KeyCode Candidate Selection Logic

@MainActor final class KeyCodeCandidateLogicTests: XCTestCase {
    func testCandidateKeysHaveSevenEntries() {
        XCTAssertEqual(KeyCode.candidateKeys.count, 7)
    }

    func testCandidateKeysAreOrdered1Through7() {
        // The order determines which slot each number key selects.
        for (index, key) in KeyCode.candidateKeys.enumerated() {
            XCTAssertEqual(key.digit, index + 1,
                           "candidateKeys[\(index)] should map to digit \(index + 1)")
        }
    }

    func testKey1IsFirstCandidateKey() {
        XCTAssertEqual(KeyCode.candidateKeys.first, .key1)
    }

    func testKey7IsLastCandidateKey() {
        XCTAssertEqual(KeyCode.candidateKeys.last, .key7)
    }

    func testSelectNextKeysContainTabAndRightArrow() {
        // Column-right navigation. Down arrow is now a dedicated grid-row key.
        XCTAssertTrue(KeyCode.selectNextKeys.contains(.tab))
        XCTAssertTrue(KeyCode.selectNextKeys.contains(.rightArrow))
        XCTAssertFalse(KeyCode.selectNextKeys.contains(.downArrow))
    }

    func testSelectNextKeysDoNotContainLeftArrowOrUpArrow() {
        // Left/Up move backward — they should trigger selectPrevious / row-up, not selectNext.
        XCTAssertFalse(KeyCode.selectNextKeys.contains(.leftArrow))
        XCTAssertFalse(KeyCode.selectNextKeys.contains(.upArrow))
    }

    func testNavigationKeysContainAllArrowsAndTab() {
        XCTAssertTrue(KeyCode.navigationKeys.contains(.tab))
        XCTAssertTrue(KeyCode.navigationKeys.contains(.leftArrow))
        XCTAssertTrue(KeyCode.navigationKeys.contains(.rightArrow))
        XCTAssertTrue(KeyCode.navigationKeys.contains(.upArrow))
        XCTAssertTrue(KeyCode.navigationKeys.contains(.downArrow))
    }

    func testBackspaceIsNotANavigationKey() {
        XCTAssertFalse(KeyCode.navigationKeys.contains(.backspace))
    }

    func testSpaceIsNotACandidateKey() {
        XCTAssertFalse(KeyCode.candidateKeys.contains(.space))
    }

    func testReturnKeyIsNotACandidateKey() {
        XCTAssertFalse(KeyCode.candidateKeys.contains(.returnKey))
    }
}

// MARK: - Note on InputController.handle() Integration Tests

//
// Full key-routing integration tests (simulating letter keypresses, space commits,
// backspace, etc.) require an instantiated InputController connected to a real or
// mocked IMKServer via IMKInputController(server:delegate:client:). IMKServer demands
// a live Mach connection bootstrapped from Info.plist's InputMethodConnectionName,
// which is unavailable in the unit-test process.
//
// The routing logic IS covered at the component level:
//   - InputState fields and transitions       → InputStateTests above
//   - trimContext sentence-boundary algorithm → TrimContextBoundaryTests + ContextTrimmingTests
//   - Capitalization rules                    → AutoCapitalizationEdgeCaseTests + TypingRulesTests
//   - Candidate window selection state        → CandidateWindowSelectionTests
//   - SpellCheckPredictor deduplication/limit → SpellCheckPredictorTests
//
// A future integration test harness could use XCTestCase with a custom NSApplication
// subclass that boots IMKServer in setUp, but this is currently out of scope.
