@testable import SwiftType
import XCTest

@MainActor final class InputLogicTests: XCTestCase {
    // MARK: - preserveCapitalization

    func testPreserveCapitalizationLowercaseOriginal() {
        XCTAssertEqual(EnglishTypingRules.shared.preserveCapitalization(original: "hel", suggested: "hello"), "hello")
    }

    func testPreserveCapitalizationUppercaseOriginal() {
        XCTAssertEqual(EnglishTypingRules.shared.preserveCapitalization(original: "Hel", suggested: "hello"), "Hello")
    }

    func testPreserveCapitalizationEmptyOriginal() {
        // Empty original has no first char — returns suggested unchanged
        XCTAssertEqual(EnglishTypingRules.shared.preserveCapitalization(original: "", suggested: "hello"), "hello")
    }

    func testPreserveCapitalizationEmptySuggested() {
        XCTAssertEqual(EnglishTypingRules.shared.preserveCapitalization(original: "Hello", suggested: ""), "")
    }

    func testPreserveCapitalizationAlreadyUpperSuggested() {
        XCTAssertEqual(EnglishTypingRules.shared.preserveCapitalization(original: "H", suggested: "Hello"), "Hello")
    }

    func testLowercaseOriginalReturnsSuggestedUnchanged() {
        // Original is lowercase so suggested case is returned as-is
        XCTAssertEqual(EnglishTypingRules.shared.preserveCapitalization(original: "h", suggested: "Hello"), "Hello")
    }

    // MARK: - autoRemoveSpaceChars

    func testAutoRemoveSpaceCharsContainsExpectedPunctuation() {
        let chars = EnglishTypingRules.shared.autoRemoveSpaceChars
        XCTAssertTrue(chars.contains("."))
        XCTAssertTrue(chars.contains(","))
        XCTAssertTrue(chars.contains("!"))
        XCTAssertTrue(chars.contains("?"))
        XCTAssertTrue(chars.contains(":"))
        XCTAssertTrue(chars.contains(";"))
        XCTAssertTrue(chars.contains(")"))
        XCTAssertTrue(chars.contains("]"))
        XCTAssertTrue(chars.contains("}"))
        XCTAssertTrue(chars.contains("%"))
        XCTAssertTrue(chars.contains("\u{201D}")) // right double quote "
        XCTAssertTrue(chars.contains("\u{2019}")) // right single quote '
        XCTAssertTrue(chars.contains("\u{00BB}")) // »
        XCTAssertTrue(chars.contains("\u{2026}")) // …
    }

    func testAutoRemoveSpaceCharsDoesNotContainLettersOrSpace() {
        let chars = EnglishTypingRules.shared.autoRemoveSpaceChars
        XCTAssertFalse(chars.contains("a"))
        XCTAssertFalse(chars.contains("z"))
        XCTAssertFalse(chars.contains(" "))
        XCTAssertFalse(chars.contains("\t"))
    }

    func testAutoRemoveSpaceCharsDoesNotContainOpeningBrackets() {
        // Only the closing/right-hand variants are in the set; opening brackets are not.
        let chars = EnglishTypingRules.shared.autoRemoveSpaceChars
        XCTAssertFalse(chars.contains("("), "Opening paren should not be in set")
        XCTAssertFalse(chars.contains("["), "Opening bracket should not be in set")
        XCTAssertFalse(chars.contains("{"), "Opening brace should not be in set")
    }

    func testAutoRemoveSpaceCharsDoesNotContainDigits() {
        let chars = EnglishTypingRules.shared.autoRemoveSpaceChars
        for digit: Character in ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9"] {
            XCTAssertFalse(chars.contains(digit), "Digit '\(digit)' should not be in set")
        }
    }

    func testAutoRemoveSpaceCharsDoesNotContainHyphenOrUnderscore() {
        let chars = EnglishTypingRules.shared.autoRemoveSpaceChars
        XCTAssertFalse(chars.contains("-"))
        XCTAssertFalse(chars.contains("_"))
    }

    func testAutoRemoveSpaceCharsContainsExactly14Characters() {
        // Lock in the exact size of the set: adding or removing a character is a
        // behaviour change that warrants an explicit test failure.
        XCTAssertEqual(EnglishTypingRules.shared.autoRemoveSpaceChars.count, 14)
    }

    // MARK: - preserveCapitalization (additional cases)

    func testPreserveCapitalizationSingleUppercaseChar() {
        // Single-char original that is uppercase.
        XCTAssertEqual(EnglishTypingRules.shared.preserveCapitalization(original: "A", suggested: "apple"), "Apple")
    }

    func testPreserveCapitalizationFirstCharIsDigitReturnsSuggestedUnchanged() {
        // A digit is not uppercase, so the suggested word is returned as-is.
        XCTAssertEqual(EnglishTypingRules.shared.preserveCapitalization(original: "1st", suggested: "hello"), "hello")
    }

    func testPreserveCapitalizationAllCapsOriginalOnlyUppcasesFirstLetterOfSuggested() {
        // Only the first character of `original` is checked — the rest are irrelevant.
        XCTAssertEqual(EnglishTypingRules.shared.preserveCapitalization(original: "HELLO", suggested: "world"), "World")
    }

    func testPreserveCapitalizationLowercaseOriginalLeavesAlreadyCapitalisedSuggested() {
        // Original starts lowercase → suggested is returned unchanged, even if it starts uppercase.
        XCTAssertEqual(EnglishTypingRules.shared.preserveCapitalization(original: "h", suggested: "Hello"), "Hello")
    }

    func testPreserveCapitalizationUppercaseOriginalWithAllCapssuggested() {
        // Uppercasing the first char of "HELLO" is idempotent.
        XCTAssertEqual(EnglishTypingRules.shared.preserveCapitalization(original: "H", suggested: "HELLO"), "HELLO")
    }

    func testPreserveCapitalizationWithPunctuationFirstCharReturnsSuggestedUnchanged() {
        // An apostrophe is not considered uppercase.
        XCTAssertEqual(EnglishTypingRules.shared.preserveCapitalization(original: "'twas", suggested: "twas"), "twas")
    }
}
