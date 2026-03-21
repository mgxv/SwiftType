@testable import SwiftType
import XCTest

/// Tests for the documented overlap between `compositionContinuationMarks` and
/// `autoRemoveSpaceChars` across all language conformers.
///
/// The protocol doc notes that U+2019 (') appears in both sets for English. This is
/// intentional: `InputController` checks continuation marks *before* auto-space removal,
/// so a mid-word smart apostrophe never reaches the auto-space path. These tests lock
/// in the exact overlap for each language.
@MainActor final class TypingRulesOverlapTests: XCTestCase {
    // MARK: - English overlap

    func testEnglishOverlapIsExactlySmartApostrophe() {
        let en = EnglishTypingRules.shared
        let overlap = en.compositionContinuationMarks.intersection(en.autoRemoveSpaceChars)
        XCTAssertEqual(overlap, ["\u{2019}"],
                       "Only U+2019 should overlap in English")
    }

    func testEnglishStraightApostropheNotInAutoRemoveSpace() {
        let en = EnglishTypingRules.shared
        XCTAssertFalse(en.autoRemoveSpaceChars.contains("'"),
                       "Straight apostrophe should NOT be in autoRemoveSpaceChars")
        XCTAssertTrue(en.compositionContinuationMarks.contains("'"),
                      "Straight apostrophe should be in compositionContinuationMarks")
    }

    // MARK: - German overlap

    func testGermanOverlapIsExactlySmartApostrophe() {
        let de = GermanTypingRules.shared
        let overlap = de.compositionContinuationMarks.intersection(de.autoRemoveSpaceChars)
        XCTAssertEqual(overlap, ["\u{2019}"],
                       "Only U+2019 should overlap in German")
    }

    func testGermanHyphenInContinuationButNotAutoRemoveSpace() {
        let de = GermanTypingRules.shared
        XCTAssertTrue(de.compositionContinuationMarks.contains("-"))
        XCTAssertFalse(de.autoRemoveSpaceChars.contains("-"),
                       "Hyphen continues composition but should not auto-remove space")
    }

    // MARK: - Sentence ending chars are disjoint from continuation marks

    func testEnglishSentenceEndersDisjointFromContinuation() {
        let en = EnglishTypingRules.shared
        let overlap = en.sentenceEndingChars.intersection(en.compositionContinuationMarks)
        XCTAssertTrue(overlap.isEmpty,
                      "Sentence enders must not extend composition")
    }

    func testGermanSentenceEndersDisjointFromContinuation() {
        let de = GermanTypingRules.shared
        let overlap = de.sentenceEndingChars.intersection(de.compositionContinuationMarks)
        XCTAssertTrue(overlap.isEmpty,
                      "Sentence enders must not extend composition")
    }

    // MARK: - Sentence ending chars are subset of autoRemoveSpaceChars

    func testEnglishSentenceEndersAreInAutoRemoveSpace() {
        let en = EnglishTypingRules.shared
        XCTAssertTrue(en.sentenceEndingChars.isSubset(of: en.autoRemoveSpaceChars),
                      "Every sentence ender should auto-remove a trailing space")
    }

    func testGermanSentenceEndersAreInAutoRemoveSpace() {
        let de = GermanTypingRules.shared
        XCTAssertTrue(de.sentenceEndingChars.isSubset(of: de.autoRemoveSpaceChars),
                      "Every sentence ender should auto-remove a trailing space")
    }

    // MARK: - No ASCII letters in any character set

    func testNoLettersInAutoRemoveSpaceChars() {
        for rules in [EnglishTypingRules.shared as TypingRules,
                      GermanTypingRules.shared]
        {
            for char in rules.autoRemoveSpaceChars {
                XCTAssertFalse(char.isLetter,
                               "'\(char)' is a letter and should not be in autoRemoveSpaceChars")
            }
        }
    }

    func testNoLettersInSentenceEndingChars() {
        for rules in [EnglishTypingRules.shared as TypingRules,
                      GermanTypingRules.shared]
        {
            for char in rules.sentenceEndingChars {
                XCTAssertFalse(char.isLetter,
                               "'\(char)' is a letter and should not be in sentenceEndingChars")
            }
        }
    }
}
