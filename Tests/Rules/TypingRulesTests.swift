@testable import SwiftType
import XCTest

/// Tests for the default implementations of the `TypingRules` protocol.
///
/// `preserveCapitalization` is tested indirectly via `EnglishTypingRules` in
/// `InputLogicTests` and `ContextTrimmingTests`.  This file closes the gap by
/// testing `applyCapitalization` — the context-aware display-time helper — again
/// using `EnglishTypingRules` as the conformer.
@MainActor final class TypingRulesTests: XCTestCase {
    private let rules: any TypingRules = EnglishTypingRules.shared

    // MARK: - applyCapitalization — context-aware capitalisation

    func testApplyCapitalizationUppercaseOriginalUppercasesSuggested() {
        let result = rules.applyCapitalization(original: "Hel", suggested: "hello", context: "Done. ")
        XCTAssertEqual(result, "Hello")
    }

    func testApplyCapitalizationLowercaseOriginalAtSentenceStartCapitalises() {
        let result = rules.applyCapitalization(original: "hel", suggested: "hello", context: "Done. ")
        XCTAssertEqual(result, "Hello")
    }

    func testApplyCapitalizationEmptyContextUppercaseOriginal() {
        let result = rules.applyCapitalization(original: "Hel", suggested: "hello", context: "")
        XCTAssertEqual(result, "Hello")
    }

    func testApplyCapitalizationEmptyContextLowercaseOriginalCapitalises() {
        let result = rules.applyCapitalization(original: "hel", suggested: "hello", context: "")
        XCTAssertEqual(result, "Hello", "Empty context = sentence start → auto-capitalise")
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

    func testApplyCapitalizationSentenceEnderNoSpaceCapitalises() {
        let result = rules.applyCapitalization(original: "hel", suggested: "hello", context: "End.")
        XCTAssertEqual(result, "Hello", "Period without trailing space still triggers auto-cap")
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
