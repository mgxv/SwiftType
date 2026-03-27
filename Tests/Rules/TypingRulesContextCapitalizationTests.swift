@testable import SwiftType
import XCTest

/// Tests verifying that `applyCapitalization` uses context to auto-capitalise suggestions
/// at sentence start, while `preserveCapitalization` remains context-unaware.
@MainActor final class TypingRulesContextCapitalizationTests: XCTestCase {
    let english = EnglishTypingRules.shared
    let german = GermanTypingRules.shared

    // MARK: - Sentence-start auto-capitalisation

    func testAutoCapAfterPeriodEnglish() {
        let result = english.applyCapitalization(original: "h", suggested: "hello", context: "Go. ")
        XCTAssertEqual(result, "Hello")
    }

    func testAutoCapAfterPeriodGerman() {
        let result = german.applyCapitalization(original: "h", suggested: "hallo", context: "Gut. ")
        XCTAssertEqual(result, "Hallo")
    }

    func testAutoCapAfterExclamation() {
        let result = english.applyCapitalization(original: "w", suggested: "wow", context: "Amazing! ")
        XCTAssertEqual(result, "Wow")
    }

    func testAutoCapAfterQuestion() {
        let result = english.applyCapitalization(original: "y", suggested: "yes", context: "Really? ")
        XCTAssertEqual(result, "Yes")
    }

    func testAutoCapAfterColonGerman() {
        let result = german.applyCapitalization(original: "e", suggested: "es", context: "Er sagte: ")
        XCTAssertEqual(result, "Es")
    }

    func testNoAutoCapAfterColonEnglish() {
        let result = english.applyCapitalization(original: "t", suggested: "the", context: "Note: ")
        XCTAssertEqual(result, "the", "Colon is not a sentence ender in English")
    }

    func testAutoCapWithEmptyContext() {
        let result = english.applyCapitalization(original: "h", suggested: "hello", context: "")
        XCTAssertEqual(result, "Hello", "Empty context = sentence start")
    }

    func testAutoCapWithWhitespaceOnlyContext() {
        let result = english.applyCapitalization(original: "h", suggested: "hello", context: "   ")
        XCTAssertEqual(result, "Hello", "Whitespace-only context = sentence start")
    }

    func testAutoCapAfterPeriodNoTrailingSpace() {
        let result = english.applyCapitalization(original: "h", suggested: "hello", context: "End.")
        XCTAssertEqual(result, "Hello", "Period without trailing space still triggers auto-cap")
    }

    func testAutoCapAfterPeriodMultipleTrailingSpaces() {
        let result = english.applyCapitalization(original: "h", suggested: "hello", context: "End.   ")
        XCTAssertEqual(result, "Hello")
    }

    // MARK: - Mid-sentence: no auto-capitalisation

    func testNoAutoCapMidSentenceEnglish() {
        let result = english.applyCapitalization(original: "h", suggested: "hello", context: "The ")
        XCTAssertEqual(result, "hello")
    }

    func testNoAutoCapMidSentenceGerman() {
        let result = german.applyCapitalization(original: "h", suggested: "hallo", context: "Das ")
        XCTAssertEqual(result, "hallo")
    }

    func testNoAutoCapAfterComma() {
        let result = english.applyCapitalization(original: "b", suggested: "but", context: "Yes, ")
        XCTAssertEqual(result, "but")
    }

    // MARK: - User's explicit case wins over context

    func testUserUppercaseWinsOverMidSentence() {
        let result = english.applyCapitalization(original: "H", suggested: "hello", context: "The quick ")
        XCTAssertEqual(result, "Hello", "User typed uppercase — preserve it regardless of context")
    }

    func testUserUppercaseWinsAtSentenceStart() {
        let result = english.applyCapitalization(original: "H", suggested: "hello", context: "Go. ")
        XCTAssertEqual(result, "Hello")
    }

    // MARK: - applyCapitalization differs from preserveCapitalization at sentence start

    func testApplyDiffersFromPreserveAtSentenceStart() {
        let apply = english.applyCapitalization(original: "h", suggested: "hello", context: "Go. ")
        let preserve = english.preserveCapitalization(original: "h", suggested: "hello")
        XCTAssertEqual(apply, "Hello")
        XCTAssertEqual(preserve, "hello")
        XCTAssertNotEqual(apply, preserve)
    }

    func testApplyMatchesPreserveMidSentence() {
        let original = "h"
        let suggested = "hello"
        let context = "The quick "
        let apply = english.applyCapitalization(original: original, suggested: suggested, context: context)
        let preserve = english.preserveCapitalization(original: original, suggested: suggested)
        XCTAssertEqual(apply, preserve)
    }

    // MARK: - preserveCapitalization edge cases (unchanged)

    func testPreserveCapitalizationEmptyOriginal() {
        let result = english.preserveCapitalization(original: "", suggested: "world")
        XCTAssertEqual(result, "world", "Empty original should not modify suggested")
    }

    func testPreserveCapitalizationEmptySuggested() {
        let result = english.preserveCapitalization(original: "H", suggested: "")
        XCTAssertEqual(result, "", "Empty suggested stays empty")
    }

    func testPreserveCapitalizationBothEmpty() {
        let result = english.preserveCapitalization(original: "", suggested: "")
        XCTAssertEqual(result, "")
    }

    func testPreserveCapitalizationNonLetterOriginal() {
        let result = english.preserveCapitalization(original: "123", suggested: "hello")
        XCTAssertEqual(result, "hello", "Non-letter original should not modify suggested")
    }

    func testPreserveCapitalizationLowercaseOriginalPassesSuggestedThrough() {
        let result = english.preserveCapitalization(original: "hello", suggested: "World")
        XCTAssertEqual(result, "World")
    }

    func testPreserveCapitalizationUppercaseOriginalUppercasesSuggested() {
        let result = english.preserveCapitalization(original: "Hello", suggested: "world")
        XCTAssertEqual(result, "World")
    }

    func testPreserveCapitalizationSingleCharOriginalUppercase() {
        let result = english.preserveCapitalization(original: "H", suggested: "hello")
        XCTAssertEqual(result, "Hello")
    }

    func testPreserveCapitalizationUnicodeUppercase() {
        let result = english.preserveCapitalization(original: "Über", suggested: "über")
        XCTAssertEqual(result, "Über")
    }

    // MARK: - insertsTrailingSpace

    func testEnglishInsertsTrailingSpace() {
        XCTAssertTrue(english.insertsTrailingSpace)
    }

    func testGermanInsertsTrailingSpace() {
        XCTAssertTrue(german.insertsTrailingSpace)
    }

    // MARK: - Empty original with context

    func testEmptyOriginalAtSentenceStart() {
        let result = english.applyCapitalization(original: "", suggested: "hello", context: "End. ")
        XCTAssertEqual(result, "hello", "Empty original — preserveCapitalization returns unchanged")
    }

    func testEmptySuggestedAtSentenceStart() {
        let result = english.applyCapitalization(original: "h", suggested: "", context: "End. ")
        XCTAssertEqual(result, "", "Empty suggested stays empty even at sentence start")
    }
}
