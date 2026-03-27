@testable import SwiftType
import XCTest

/// Tests for `applyCapitalization(original:suggested:context:)` across language conformers.
/// `applyCapitalization` is context-aware: it auto-capitalises at sentence start (based on
/// `sentenceEndingChars`) and preserves the user's typed case via `preserveCapitalization`.
@MainActor final class TypingRulesApplyCapitalizationTests: XCTestCase {
    // MARK: - English

    func testEnglishPreserveCapUppercaseOriginal() {
        let rules = EnglishTypingRules.shared
        let result = rules.applyCapitalization(original: "H", suggested: "hello", context: "Done. ")
        XCTAssertEqual(result, "Hello")
    }

    func testEnglishLowercaseOriginalAtSentenceStart() {
        let rules = EnglishTypingRules.shared
        let result = rules.applyCapitalization(original: "t", suggested: "the", context: "")
        XCTAssertEqual(result, "The", "Empty context = sentence start → auto-capitalise")
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
        XCTAssertEqual(result, "Yes", "Sentence start after '?' → auto-capitalise")
    }

    func testEnglishEmptyOriginalReturnsSuggestedUnchanged() {
        let rules = EnglishTypingRules.shared
        let result = rules.applyCapitalization(original: "", suggested: "hello", context: "End. ")
        XCTAssertEqual(result, "hello", "Empty original → preserveCapitalization returns unchanged")
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
        XCTAssertEqual(result, "Das", "Sentence start after '.' → auto-capitalise")
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

    func testColonSpaceDifferentBehaviorAcrossLanguages() {
        let context = "Note: "
        let englishResult = EnglishTypingRules.shared.applyCapitalization(
            original: "t", suggested: "the", context: context,
        )
        let germanResult = GermanTypingRules.shared.applyCapitalization(
            original: "d", suggested: "das", context: context,
        )
        // English: colon is not a sentence ender → no auto-cap.
        XCTAssertEqual(englishResult, "the")
        // German: colon is a sentence ender → auto-capitalise.
        XCTAssertEqual(germanResult, "Das")
    }
}
