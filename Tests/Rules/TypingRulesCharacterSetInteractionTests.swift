@testable import SwiftType
import XCTest

/// Tests for the interaction between TypingRules character sets.
///
/// The TypingRules protocol note says: "Members may appear in both
/// compositionContinuationMarks and autoRemoveSpaceChars (e.g. U+2019 in English).
/// This is intentional: InputController checks continuation marks before auto-space
/// removal, so an overlapping character never reaches the auto-space path mid-word."
///
/// These tests verify the set relationships and overlaps that the routing logic depends on.
@MainActor final class TypingRulesCharacterSetInteractionTests: XCTestCase {
    let english = EnglishTypingRules.shared
    let german = GermanTypingRules.shared

    // MARK: - English overlap invariants

    func testEnglishCurlyApostropheInBothSets() {
        let curly: Character = "\u{2019}"
        XCTAssertTrue(english.compositionContinuationMarks.contains(curly),
                      "U+2019 must be in compositionContinuationMarks for contractions")
        XCTAssertTrue(english.autoRemoveSpaceChars.contains(curly),
                      "U+2019 must be in autoRemoveSpaceChars for closing single quotes")
    }

    func testEnglishStraightApostropheOnlyInContinuation() {
        let straight: Character = "'"
        XCTAssertTrue(english.compositionContinuationMarks.contains(straight))
        XCTAssertFalse(english.autoRemoveSpaceChars.contains(straight),
                       "Straight apostrophe should NOT be in autoRemoveSpaceChars")
    }

    func testEnglishSentenceEndersAreSubsetOfAutoRemoveSpace() {
        // All sentence enders should also remove auto-space (period, !, ?)
        for char in english.sentenceEndingChars {
            XCTAssertTrue(english.autoRemoveSpaceChars.contains(char),
                          "Sentence ender '\(char)' should also be in autoRemoveSpaceChars")
        }
    }

    func testEnglishNoSentenceEndersInContinuationMarks() {
        let overlap = english.sentenceEndingChars.intersection(english.compositionContinuationMarks)
        XCTAssertTrue(overlap.isEmpty,
                      "Sentence enders and continuation marks must not overlap: \(overlap)")
    }

    // MARK: - German overlap invariants

    func testGermanCurlyApostropheInBothSets() {
        let curly: Character = "\u{2019}"
        XCTAssertTrue(german.compositionContinuationMarks.contains(curly))
        XCTAssertTrue(german.autoRemoveSpaceChars.contains(curly))
    }

    func testGermanHyphenOnlyInContinuation() {
        let hyphen: Character = "-"
        XCTAssertTrue(german.compositionContinuationMarks.contains(hyphen),
                      "Hyphen must be in German continuation marks for E-Mail, U-Bahn")
        XCTAssertFalse(german.autoRemoveSpaceChars.contains(hyphen),
                       "Hyphen should NOT be in autoRemoveSpaceChars")
    }

    func testGermanSentenceEndersAreSubsetOfAutoRemoveSpace() {
        for char in german.sentenceEndingChars {
            XCTAssertTrue(german.autoRemoveSpaceChars.contains(char),
                          "German sentence ender '\(char)' should also be in autoRemoveSpaceChars")
        }
    }

    func testGermanColonIsSentenceEnder() {
        XCTAssertTrue(german.sentenceEndingChars.contains(":"),
                      "German treats colon as sentence boundary")
        XCTAssertFalse(english.sentenceEndingChars.contains(":"),
                       "English does NOT treat colon as sentence boundary")
    }

    func testGermanNoSentenceEndersInContinuationMarks() {
        let overlap = german.sentenceEndingChars.intersection(german.compositionContinuationMarks)
        XCTAssertTrue(overlap.isEmpty,
                      "Sentence enders and continuation marks must not overlap: \(overlap)")
    }

    // MARK: - Cross-language quote differences

    func testClosingDoubleQuoteDiffers() {
        let englishQuote: Character = "\u{201D}" // "
        let germanQuote: Character = "\u{201C}" // "
        XCTAssertTrue(english.autoRemoveSpaceChars.contains(englishQuote))
        XCTAssertFalse(english.autoRemoveSpaceChars.contains(germanQuote))
        XCTAssertTrue(german.autoRemoveSpaceChars.contains(germanQuote))
        XCTAssertFalse(german.autoRemoveSpaceChars.contains(englishQuote))
    }

    func testClosingGuillemetDiffers() {
        let englishGuillemet: Character = "\u{00BB}" // »
        let germanGuillemet: Character = "\u{00AB}" // «
        XCTAssertTrue(english.autoRemoveSpaceChars.contains(englishGuillemet))
        XCTAssertFalse(english.autoRemoveSpaceChars.contains(germanGuillemet))
        XCTAssertTrue(german.autoRemoveSpaceChars.contains(germanGuillemet))
        XCTAssertFalse(german.autoRemoveSpaceChars.contains(englishGuillemet))
    }

    // MARK: - Shared characters between languages

    func testCommonAutoRemoveSpaceChars() {
        // These characters should be in both English and German sets
        let common: [Character] = [".", ",", "!", "?", ":", ";", ")", "]", "}", "%", "\u{2019}", "\u{2026}"]
        for char in common {
            XCTAssertTrue(english.autoRemoveSpaceChars.contains(char),
                          "'\(char)' should be in English autoRemoveSpaceChars")
            XCTAssertTrue(german.autoRemoveSpaceChars.contains(char),
                          "'\(char)' should be in German autoRemoveSpaceChars")
        }
    }

    func testCommonContinuationMarks() {
        // Straight and curly apostrophes are shared
        let common: [Character] = ["'", "\u{2019}"]
        for char in common {
            XCTAssertTrue(english.compositionContinuationMarks.contains(char))
            XCTAssertTrue(german.compositionContinuationMarks.contains(char))
        }
    }
}
