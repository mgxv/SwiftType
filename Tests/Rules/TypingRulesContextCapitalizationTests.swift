@testable import SwiftType
import XCTest

/// Tests verifying that `applyCapitalization` and `preserveCapitalization` behave
/// identically — the default `applyCapitalization` delegates to `preserveCapitalization`
/// and ignores the context parameter.
///
/// These tests lock in the current behavior: context is accepted but unused.
/// If a future change makes `applyCapitalization` context-aware (e.g. auto-capitalizing
/// at sentence start), these tests will catch the intentional behavior change.
@MainActor final class TypingRulesContextCapitalizationTests: XCTestCase {
    let english = EnglishTypingRules.shared
    let german = GermanTypingRules.shared

    // MARK: - applyCapitalization ignores context

    func testApplyCapitalizationIgnoresContextForEnglish() {
        // Even with sentence-ending context, applyCapitalization only uses preserveCapitalization.
        let withSentenceEnd = english.applyCapitalization(original: "h", suggested: "hello", context: "Go. ")
        let withMidSentence = english.applyCapitalization(original: "h", suggested: "hello", context: "The ")
        // Both should be lowercase "h" because preserveCapitalization sees lowercase "h".
        XCTAssertEqual(withSentenceEnd, "hello")
        XCTAssertEqual(withMidSentence, "hello")
    }

    func testApplyCapitalizationIgnoresContextForGerman() {
        let withSentenceEnd = german.applyCapitalization(original: "h", suggested: "hallo", context: "Gut. ")
        let withMidSentence = german.applyCapitalization(original: "h", suggested: "hallo", context: "Das ")
        XCTAssertEqual(withSentenceEnd, "hallo")
        XCTAssertEqual(withMidSentence, "hallo")
    }

    func testApplyCapitalizationMatchesPreserveCapitalization() {
        let original = "Hel"
        let suggested = "hello"
        let context = "Go. "

        let apply = english.applyCapitalization(original: original, suggested: suggested, context: context)
        let preserve = english.preserveCapitalization(original: original, suggested: suggested)
        XCTAssertEqual(apply, preserve)
    }

    func testApplyCapitalizationWithEmptyContext() {
        let result = english.applyCapitalization(original: "H", suggested: "hello", context: "")
        XCTAssertEqual(result, "Hello", "Empty context + uppercase original → preserve case")
    }

    // MARK: - preserveCapitalization edge cases

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
}
