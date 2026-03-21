@testable import SwiftType
import XCTest

/// Tests for `applyCapitalization(original:suggested:context:)` across all three language
/// conformers. Since `applyCapitalization` now delegates entirely to `preserveCapitalization`,
/// these tests verify that the original's case is preserved onto the suggestion regardless
/// of context.
@MainActor final class TypingRulesApplyCapitalizationTests: XCTestCase {
    // MARK: - English

    func testEnglishPreserveCapUppercaseOriginal() {
        let rules = EnglishTypingRules.shared
        let result = rules.applyCapitalization(original: "H", suggested: "hello", context: "Done. ")
        XCTAssertEqual(result, "Hello")
    }

    func testEnglishLowercaseOriginalStaysLowercase() {
        let rules = EnglishTypingRules.shared
        let result = rules.applyCapitalization(original: "t", suggested: "the", context: "")
        XCTAssertEqual(result, "the")
    }

    func testEnglishPreserveCapMidSentence() {
        let rules = EnglishTypingRules.shared
        let result = rules.applyCapitalization(original: "H", suggested: "hello", context: "The quick ")
        XCTAssertEqual(result, "Hello")
    }

    func testEnglishNoCapLowercaseMidSentence() {
        let rules = EnglishTypingRules.shared
        let result = rules.applyCapitalization(original: "h", suggested: "hello", context: "The quick ")
        XCTAssertEqual(result, "hello")
    }

    func testEnglishUppercaseOriginalAfterExclamation() {
        let rules = EnglishTypingRules.shared
        let result = rules.applyCapitalization(original: "W", suggested: "wow", context: "Amazing! ")
        XCTAssertEqual(result, "Wow")
    }

    func testEnglishLowercaseOriginalAfterQuestion() {
        let rules = EnglishTypingRules.shared
        let result = rules.applyCapitalization(original: "y", suggested: "yes", context: "Really? ")
        XCTAssertEqual(result, "yes")
    }

    func testEnglishEmptyOriginalReturnsSuggestedUnchanged() {
        let rules = EnglishTypingRules.shared
        let result = rules.applyCapitalization(original: "", suggested: "hello", context: "End. ")
        XCTAssertEqual(result, "hello")
    }

    func testEnglishEmptySuggestedReturnsEmpty() {
        let rules = EnglishTypingRules.shared
        let result = rules.applyCapitalization(original: "H", suggested: "", context: "End. ")
        XCTAssertEqual(result, "")
    }

    // MARK: - German

    func testGermanUppercaseOriginalAfterColon() {
        let rules = GermanTypingRules.shared
        let result = rules.applyCapitalization(original: "E", suggested: "es", context: "Er sagte: ")
        XCTAssertEqual(result, "Es")
    }

    func testGermanLowercaseOriginalAfterPeriod() {
        let rules = GermanTypingRules.shared
        let result = rules.applyCapitalization(original: "d", suggested: "das", context: "Ende. ")
        XCTAssertEqual(result, "das")
    }

    func testGermanPreserveCapMidSentence() {
        let rules = GermanTypingRules.shared
        let result = rules.applyCapitalization(original: "B", suggested: "berlin", context: "In ")
        XCTAssertEqual(result, "Berlin")
    }

    func testGermanNoCapAfterComma() {
        let rules = GermanTypingRules.shared
        let result = rules.applyCapitalization(original: "d", suggested: "das", context: "Ja, ")
        XCTAssertEqual(result, "das")
    }

    // MARK: - Cross-language: same input, different rules

    func testColonSpaceSameBehaviorWhenOriginalIsLowercase() {
        let context = "Note: "
        let englishResult = EnglishTypingRules.shared.applyCapitalization(
            original: "t", suggested: "the", context: context,
        )
        let germanResult = GermanTypingRules.shared.applyCapitalization(
            original: "d", suggested: "das", context: context,
        )
        // Both delegate to preserveCapitalization — lowercase original → no change.
        XCTAssertEqual(englishResult, "the")
        XCTAssertEqual(germanResult, "das")
    }
}
