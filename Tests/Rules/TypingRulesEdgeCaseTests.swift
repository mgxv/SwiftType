@testable import SwiftType
import XCTest

/// Edge-case tests for the `TypingRules` protocol default implementations and
/// the English/German conformers.
///
/// These supplement the existing TypingRulesTests, GermanRulesTests, and
/// InputLogicTests by covering:
///   - `preserveCapitalization` when original starts with an emoji or numeric
///   - Exact cross-language differences between English and German quote characters
///   - `compositionContinuationMarks` asymmetry (German has hyphen, English does not)
///   - Exact character-set sizes to catch accidental additions/removals
@MainActor final class TypingRulesEdgeCaseTests: XCTestCase {
    private let english = EnglishTypingRules.shared
    private let german = GermanTypingRules.shared

    // MARK: - preserveCapitalization — non-letter first character in original

    func testPreserveCapitalization_emojiOriginal_returnsSuggestedUnchanged() {
        // Arrange: original starts with an emoji.  Emoji have no case →
        // `firstChar.isUppercase` is false → suggested is returned unchanged.
        let result = english.preserveCapitalization(original: "🎉hello", suggested: "world")
        XCTAssertEqual(result, "world",
                       "Emoji first character is not uppercase; suggested must be returned unchanged")
    }

    func testPreserveCapitalization_numericOriginal_returnsSuggestedUnchanged() {
        // Arrange: original starts with a digit (not uppercase) → unchanged.
        // (Also covered in InputLogicTests; retained here for Rules grouping.)
        let result = english.preserveCapitalization(original: "42nd", suggested: "hello")
        XCTAssertEqual(result, "hello")
    }

    func testPreserveCapitalization_punctuationOriginal_returnsSuggestedUnchanged() {
        // Arrange: original starts with punctuation (not uppercase).
        let result = german.preserveCapitalization(original: "-mal", suggested: "wieder")
        XCTAssertEqual(result, "wieder")
    }

    // MARK: - Cross-language quote-character asymmetry

    // English and German use DIFFERENT closing quotation marks.
    // These tests make the divergence explicit and prevent regressions
    // when editing either conformer.

    func testEnglishAutoRemoveSpace_containsRightDoubleQuote_U201D() {
        // U+201D " — English closing double quote (as in "text").
        XCTAssertTrue(english.autoRemoveSpaceChars.contains("\u{201D}"))
    }

    func testEnglishAutoRemoveSpace_doesNotContainLeftDoubleQuote_U201C() {
        // U+201C " — German closing quote; must NOT appear in English set.
        XCTAssertFalse(english.autoRemoveSpaceChars.contains("\u{201C}"),
                       "English autoRemoveSpaceChars must not contain U+201C (the German closing quote)")
    }

    func testEnglishAutoRemoveSpace_containsRightGuillemet_U00BB() {
        // U+00BB » — English closing guillemet.
        XCTAssertTrue(english.autoRemoveSpaceChars.contains("\u{00BB}"))
    }

    func testEnglishAutoRemoveSpace_doesNotContainLeftGuillemet_U00AB() {
        // U+00AB « — German closing guillemet (Swiss); must NOT appear in English set.
        XCTAssertFalse(english.autoRemoveSpaceChars.contains("\u{00AB}"),
                       "English autoRemoveSpaceChars must not contain U+00AB (the German closing guillemet)")
    }

    // MARK: - compositionContinuationMarks — hyphen asymmetry

    func testEnglishCompositionContinuationMarks_doesNotContainHyphen() {
        // English has no compound-word convention requiring a hyphen to stay in-buffer.
        XCTAssertFalse(english.compositionContinuationMarks.contains("-"),
                       "English compositionContinuationMarks must not contain a hyphen")
    }

    func testGermanCompositionContinuationMarks_containsHyphen() {
        // German includes hyphens for compound words like "E-Mail" and "U-Bahn".
        // (Also tested in GermanRulesTests; retained here for cross-language comparison.)
        XCTAssertTrue(german.compositionContinuationMarks.contains("-"))
    }

    func testGermanHasMoreContinuationMarksThanEnglish() {
        // German's extra hyphen means its set is strictly larger than English's.
        XCTAssertGreaterThan(
            german.compositionContinuationMarks.count,
            english.compositionContinuationMarks.count,
            "German compositionContinuationMarks must have more entries than English",
        )
    }

    // MARK: - Character-set cardinalities

    func testEnglishAutoRemoveSpaceCharsExactCount() {
        XCTAssertEqual(english.autoRemoveSpaceChars.count, 14,
                       "English autoRemoveSpaceChars must contain exactly 14 characters")
    }

    func testGermanAutoRemoveSpaceCharsExactCount() {
        XCTAssertEqual(german.autoRemoveSpaceChars.count, 14,
                       "German autoRemoveSpaceChars must contain exactly 14 characters")
    }

    func testEnglishCompositionContinuationMarksExactCount() {
        XCTAssertEqual(english.compositionContinuationMarks.count, 2,
                       "English compositionContinuationMarks must contain exactly 2 characters")
    }

    func testGermanCompositionContinuationMarksExactCount() {
        XCTAssertEqual(german.compositionContinuationMarks.count, 3,
                       "German compositionContinuationMarks must contain exactly 3 characters")
    }

    // MARK: - autoRemoveSpaceChars — false-positive guards

    func testEnglishAutoRemoveSpaceChars_doesNotContainHyphen() {
        XCTAssertFalse(english.autoRemoveSpaceChars.contains("-"),
                       "Hyphen must not be in English autoRemoveSpaceChars")
    }

    func testEnglishAutoRemoveSpaceChars_doesNotContainSlash() {
        XCTAssertFalse(english.autoRemoveSpaceChars.contains("/"),
                       "Slash must not be in English autoRemoveSpaceChars")
    }

    func testEnglishAutoRemoveSpaceChars_doesNotContainAt() {
        XCTAssertFalse(english.autoRemoveSpaceChars.contains("@"),
                       "@ must not be in English autoRemoveSpaceChars")
    }

    func testEnglishAutoRemoveSpaceChars_doesNotContainDigit() {
        XCTAssertFalse(english.autoRemoveSpaceChars.contains("1"),
                       "Digits must not be in English autoRemoveSpaceChars")
    }

    func testEnglishAutoRemoveSpaceChars_doesNotContainLetter() {
        XCTAssertFalse(english.autoRemoveSpaceChars.contains("a"),
                       "Letters must not be in English autoRemoveSpaceChars")
    }

    func testGermanAutoRemoveSpaceChars_doesNotContainHyphen() {
        // Hyphen is in compositionContinuationMarks only, never in autoRemoveSpaceChars.
        XCTAssertFalse(german.autoRemoveSpaceChars.contains("-"),
                       "Hyphen must not be in German autoRemoveSpaceChars; it belongs only in compositionContinuationMarks")
    }

    // MARK: - sentenceEndingChars — size invariants

    func testEnglishSentenceEndingCharsExactCount() {
        // Lock in exact size: {., !, ?} — 3 characters.
        XCTAssertEqual(english.sentenceEndingChars.count, 3,
                       "English sentenceEndingChars must contain exactly 3 characters")
    }

    func testGermanSentenceEndingCharsExactCount() {
        // Lock in exact size: {., !, ?, :} — 4 characters.
        XCTAssertEqual(german.sentenceEndingChars.count, 4,
                       "German sentenceEndingChars must contain exactly 4 characters (adds ':')")
    }

    func testGermanSentenceEndingCharsIsStrictSupersetOfEnglish() {
        // Every English sentence ender must also be a German sentence ender.
        XCTAssertTrue(
            english.sentenceEndingChars.isSubset(of: german.sentenceEndingChars),
            "German sentenceEndingChars must be a strict superset of English's",
        )
    }
}
