@testable import SwiftType
import XCTest

/// Tests for the default implementations of the `TypingRules` protocol.
///
/// `preserveCapitalization` is tested indirectly via `EnglishTypingRules` in
/// `InputLogicTests` and `ContextTrimmingTests`.  This file closes the gap by
/// testing `applyCapitalization` — the display-time helper that delegates to
/// `preserveCapitalization` — again using `EnglishTypingRules` as the conformer.
@MainActor final class TypingRulesTests: XCTestCase {
    private let rules: any TypingRules = EnglishTypingRules.shared

    // MARK: - applyCapitalization — preserves original case

    func testApplyCapitalizationUppercaseOriginalUppercasesSuggested() {
        let result = rules.applyCapitalization(original: "Hel", suggested: "hello", context: "Done. ")
        XCTAssertEqual(result, "Hello")
    }

    func testApplyCapitalizationLowercaseOriginalKeepsSuggestedLowercase() {
        let result = rules.applyCapitalization(original: "hel", suggested: "hello", context: "Done. ")
        XCTAssertEqual(result, "hello")
    }

    func testApplyCapitalizationEmptyContextUppercaseOriginal() {
        let result = rules.applyCapitalization(original: "Hel", suggested: "hello", context: "")
        XCTAssertEqual(result, "Hello")
    }

    func testApplyCapitalizationEmptyContextLowercaseOriginal() {
        let result = rules.applyCapitalization(original: "hel", suggested: "hello", context: "")
        XCTAssertEqual(result, "hello")
    }

    func testApplyCapitalizationMidSentenceUppercaseOriginalPreservesCapital() {
        let result = rules.applyCapitalization(original: "He", suggested: "hello", context: "I think ")
        XCTAssertEqual(result, "Hello")
    }

    func testApplyCapitalizationMidSentenceLowercaseOriginalUnchanged() {
        let result = rules.applyCapitalization(original: "hel", suggested: "hello", context: "I went ")
        XCTAssertEqual(result, "hello")
    }

    func testApplyCapitalizationAfterCommaDoesNotUppercase() {
        let result = rules.applyCapitalization(original: "hel", suggested: "hello", context: "one, ")
        XCTAssertEqual(result, "hello")
    }

    func testApplyCapitalizationAfterColonDoesNotUppercase() {
        let result = rules.applyCapitalization(original: "no", suggested: "note", context: "Note: ")
        XCTAssertEqual(result, "note")
    }

    // MARK: - applyCapitalization — edge inputs

    func testApplyCapitalizationEmptySuggestedReturnsEmpty() {
        let result = rules.applyCapitalization(original: "h", suggested: "", context: "")
        XCTAssertEqual(result, "")
    }

    func testApplyCapitalizationEmptyOriginalReturnsSuggestedUnchanged() {
        let result = rules.applyCapitalization(original: "", suggested: "hello", context: "End. ")
        XCTAssertEqual(result, "hello")
    }

    func testApplyCapitalizationSentenceEnderNoSpace() {
        let result = rules.applyCapitalization(original: "hel", suggested: "hello", context: "End.")
        XCTAssertEqual(result, "hello")
    }

    // MARK: - preserveCapitalization — additional cases

    func testPreserveCapitalization_allCapsOriginal_uppercasesOnlyFirstChar() {
        let result = rules.preserveCapitalization(original: "HELLO", suggested: "world")
        XCTAssertEqual(result, "World")
    }

    func testPreserveCapitalization_emptySuggested_returnsEmpty() {
        let result = rules.preserveCapitalization(original: "H", suggested: "")
        XCTAssertEqual(result, "")
    }

    // MARK: - compositionContinuationMarks

    func testCompositionContinuationMarksContainsStraightApostrophe() {
        XCTAssertTrue(rules.compositionContinuationMarks.contains("'"))
    }

    func testCompositionContinuationMarksContainsSmartApostrophe() {
        XCTAssertTrue(rules.compositionContinuationMarks.contains("\u{2019}"))
    }

    func testCompositionContinuationMarksDoesNotContainLetters() {
        XCTAssertFalse(rules.compositionContinuationMarks.contains("a"))
    }

    func testCompositionContinuationMarksDoesNotContainPeriod() {
        XCTAssertFalse(rules.compositionContinuationMarks.contains("."))
    }

    // MARK: - sentenceEndingChars

    func testSentenceEndingCharsContainsPeriod() {
        XCTAssertTrue(rules.sentenceEndingChars.contains("."))
    }

    func testSentenceEndingCharsContainsExclamation() {
        XCTAssertTrue(rules.sentenceEndingChars.contains("!"))
    }

    func testSentenceEndingCharsContainsQuestion() {
        XCTAssertTrue(rules.sentenceEndingChars.contains("?"))
    }

    func testSentenceEndingCharsDoesNotContainComma() {
        XCTAssertFalse(rules.sentenceEndingChars.contains(","))
    }

    func testSentenceEndingCharsDoesNotContainColon() {
        XCTAssertFalse(rules.sentenceEndingChars.contains(":"))
    }
}
