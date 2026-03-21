@testable import SwiftType
import XCTest

/// Tests for `LanguageDescriptor`.
///
/// Locks in the content and structure of `LanguageDescriptor.all` so that accidental
/// removal of a language or a missing TypingRules implementation surfaces as a test
/// failure rather than a silent runtime fallback.
@MainActor final class LanguageDescriptorTests: XCTestCase {
    // MARK: - Catalog completeness

    func testAllContainsEnglish() {
        XCTAssertTrue(
            LanguageDescriptor.all.contains(where: { $0.code == "en" }),
            "LanguageDescriptor.all must contain an English entry",
        )
    }

    func testAllContainsGerman() {
        XCTAssertTrue(
            LanguageDescriptor.all.contains(where: { $0.code == "de" }),
            "LanguageDescriptor.all must contain a German entry",
        )
    }

    func testAllHasAtLeastTwoEntries() {
        // Lock in the minimum size so a mistaken deletion fails loudly.
        XCTAssertGreaterThanOrEqual(LanguageDescriptor.all.count, 2)
    }

    func testAllContainsExactlyTwoEntries() {
        // Exact count ensures a newly added language is not silently omitted from
        // this assertion. Update this test when adding a third language.
        XCTAssertEqual(LanguageDescriptor.all.count, 2,
                       "LanguageDescriptor.all must contain exactly 2 entries (en, de); update this test when adding a new language")
    }

    // MARK: - Code uniqueness

    func testAllCodesAreUnique() {
        let codes = LanguageDescriptor.all.map(\.code)
        let uniqueCodes = Set(codes)
        XCTAssertEqual(codes.count, uniqueCodes.count,
                       "LanguageDescriptor.all must not contain duplicate language codes")
    }

    // MARK: - Entry validity

    func testAllEntriesHaveNonEmptyCode() {
        for descriptor in LanguageDescriptor.all {
            XCTAssertFalse(descriptor.code.isEmpty,
                           "LanguageDescriptor entry must have a non-empty code")
        }
    }

    func testAllEntriesHaveNonEmptyDisplayName() {
        for descriptor in LanguageDescriptor.all {
            XCTAssertFalse(descriptor.displayName.isEmpty,
                           "LanguageDescriptor '\(descriptor.code)' must have a non-empty display name")
        }
    }

    // MARK: - Rules association

    func testEnglishDescriptorRulesAutoRemoveSpaceCharsContainsPeriod() throws {
        // Smoke test: the rules attached to "en" behave like EnglishTypingRules.
        let englishDescriptor = LanguageDescriptor.all.first(where: { $0.code == "en" })
        XCTAssertNotNil(englishDescriptor)
        XCTAssertTrue(try XCTUnwrap(englishDescriptor?.rules.autoRemoveSpaceChars.contains(".")))
    }

    func testGermanDescriptorRulesContainsHyphenInContinuationMarks() throws {
        // Smoke test: the rules attached to "de" behave like GermanTypingRules.
        let germanDescriptor = LanguageDescriptor.all.first(where: { $0.code == "de" })
        XCTAssertNotNil(germanDescriptor)
        XCTAssertTrue(try XCTUnwrap(germanDescriptor?.rules.compositionContinuationMarks.contains("-")))
    }

    func testGermanDescriptorRulesColonIsSentenceEnder() throws {
        // German capitalises after a colon; English does not.
        let germanDescriptor = LanguageDescriptor.all.first(where: { $0.code == "de" })
        XCTAssertNotNil(germanDescriptor)
        XCTAssertTrue(try XCTUnwrap(germanDescriptor?.rules.sentenceEndingChars.contains(":")))
    }

    // MARK: - make helper (display name derivation)

    func testEnglishDisplayNameIsNonEmpty() throws {
        // The display name is derived from the maximal locale identifier.
        // We only assert it's non-empty because the exact locale string varies by platform.
        let descriptor = try XCTUnwrap(LanguageDescriptor.all.first(where: { $0.code == "en" }))
        XCTAssertFalse(descriptor.displayName.isEmpty)
    }

    func testGermanDisplayNameIsNonEmpty() throws {
        let descriptor = try XCTUnwrap(LanguageDescriptor.all.first(where: { $0.code == "de" }))
        XCTAssertFalse(descriptor.displayName.isEmpty)
    }
}
