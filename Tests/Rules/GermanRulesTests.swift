@testable import SwiftType
import XCTest

/// Tests for `GermanTypingRules`.
///
/// Verifies the German-specific character sets and the capitalisation behaviour
/// that differs from English.
@MainActor final class GermanRulesTests: XCTestCase {
    private let rules = GermanTypingRules.shared

    // MARK: - autoRemoveSpaceChars — core punctuation (shared with English)

    func testAutoRemoveSpaceCharsContainsPeriodCommaExclamationQuestionColonSemicolon() {
        let chars = rules.autoRemoveSpaceChars
        XCTAssertTrue(chars.contains("."))
        XCTAssertTrue(chars.contains(","))
        XCTAssertTrue(chars.contains("!"))
        XCTAssertTrue(chars.contains("?"))
        XCTAssertTrue(chars.contains(":"))
        XCTAssertTrue(chars.contains(";"))
    }

    func testAutoRemoveSpaceCharsContainsClosingBrackets() {
        let chars = rules.autoRemoveSpaceChars
        XCTAssertTrue(chars.contains(")"))
        XCTAssertTrue(chars.contains("]"))
        XCTAssertTrue(chars.contains("}"))
        XCTAssertTrue(chars.contains("%"))
    }

    // MARK: - autoRemoveSpaceChars — German-specific quotes

    func testAutoRemoveSpaceCharsContainsGermanClosingDoubleQuote() {
        // U+201C " — standard German closing quote for „text" style
        XCTAssertTrue(rules.autoRemoveSpaceChars.contains("\u{201C}"))
    }

    func testAutoRemoveSpaceCharsContainsSwissClosingGuillemet() {
        // U+00AB « — Swiss-style closing guillemet for »text« style
        XCTAssertTrue(rules.autoRemoveSpaceChars.contains("\u{00AB}"))
    }

    func testAutoRemoveSpaceCharsContainsSmartApostrophe() {
        // U+2019 ' — used both as closing single-quote and apostrophe
        XCTAssertTrue(rules.autoRemoveSpaceChars.contains("\u{2019}"))
    }

    func testAutoRemoveSpaceCharsContainsEllipsis() {
        // U+2026 … — shared with English
        XCTAssertTrue(rules.autoRemoveSpaceChars.contains("\u{2026}"))
    }

    func testAutoRemoveSpaceCharsDoesNotContainEnglishRightDoubleQuote() {
        // U+201D " is the English closing quote; German uses U+201C instead
        XCTAssertFalse(rules.autoRemoveSpaceChars.contains("\u{201D}"))
    }

    func testAutoRemoveSpaceCharsDoesNotContainEnglishRightGuillemet() {
        // U+00BB » is the English closing guillemet; German Swiss uses U+00AB «
        XCTAssertFalse(rules.autoRemoveSpaceChars.contains("\u{00BB}"))
    }

    func testAutoRemoveSpaceCharsDoesNotContainLettersOrDigits() {
        let chars = rules.autoRemoveSpaceChars
        XCTAssertFalse(chars.contains("a"))
        XCTAssertFalse(chars.contains("Z"))
        XCTAssertFalse(chars.contains("1"))
        XCTAssertFalse(chars.contains(" "))
    }

    // MARK: - compositionContinuationMarks

    func testCompositionContinuationMarksContainsStraightApostrophe() {
        XCTAssertTrue(rules.compositionContinuationMarks.contains("'"))
    }

    func testCompositionContinuationMarksContainsSmartApostrophe() {
        XCTAssertTrue(rules.compositionContinuationMarks.contains("\u{2019}"))
    }

    func testCompositionContinuationMarksContainsHyphen() {
        // Hyphen allows compound words like "E-Mail", "U-Bahn" as a single buffer
        XCTAssertTrue(rules.compositionContinuationMarks.contains("-"))
    }

    func testCompositionContinuationMarksDoesNotContainPeriodOrComma() {
        XCTAssertFalse(rules.compositionContinuationMarks.contains("."))
        XCTAssertFalse(rules.compositionContinuationMarks.contains(","))
    }

    // MARK: - sentenceEndingChars

    func testSentenceEndingCharsContainsPeriodExclamationQuestion() {
        let chars = rules.sentenceEndingChars
        XCTAssertTrue(chars.contains("."))
        XCTAssertTrue(chars.contains("!"))
        XCTAssertTrue(chars.contains("?"))
    }

    func testSentenceEndingCharsContainsColonUnlikeEnglish() {
        // German capitalises after a colon that introduces a complete sentence.
        XCTAssertTrue(rules.sentenceEndingChars.contains(":"))
    }

    func testSentenceEndingCharsDoesNotContainCommaOrSemicolon() {
        let chars = rules.sentenceEndingChars
        XCTAssertFalse(chars.contains(","))
        XCTAssertFalse(chars.contains(";"))
    }

    // MARK: - Character-set cardinalities

    func testAutoRemoveSpaceCharsExactCount() {
        XCTAssertEqual(rules.autoRemoveSpaceChars.count, 14,
                       "German autoRemoveSpaceChars must contain exactly 14 characters")
    }

    func testCompositionContinuationMarksExactCount() {
        XCTAssertEqual(rules.compositionContinuationMarks.count, 3,
                       "German compositionContinuationMarks must contain exactly 3 characters")
    }

    // MARK: - applyCapitalization — via protocol default

    func testApplyCapitalizationUppercaseOriginalPreservesCase() {
        let result = rules.applyCapitalization(original: "Es", suggested: "er", context: "Er sagte: ")
        XCTAssertEqual(result, "Er")
    }

    func testApplyCapitalizationMidSentenceLowercaseOriginalUnchanged() {
        let result = rules.applyCapitalization(original: "hau", suggested: "haus", context: "Das ")
        XCTAssertEqual(result, "haus")
    }

    func testApplyCapitalizationLowercaseOriginalAtSentenceStartCapitalises() {
        let result = rules.applyCapitalization(original: "er", suggested: "er", context: "Toll! ")
        XCTAssertEqual(result, "Er", "Sentence start after '!' → auto-capitalise")
    }
}
