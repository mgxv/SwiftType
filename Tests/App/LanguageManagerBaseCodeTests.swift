@testable import SwiftType
import XCTest

/// Tests for `String.baseLanguageCode` — the BCP-47 subtag-stripping extension
/// defined in `LanguageManager.swift`.
///
/// This is a pure computed property and the critical path through which
/// `InputController.refreshRules()` maps the active language to a `TypingRules`
/// conformer. Every edge case here is a real input that macOS returns from
/// `NSSpellChecker.shared.language()` or from `LanguageManager.selectedCode`.
@MainActor final class LanguageManagerBaseCodeTests: XCTestCase {
    // MARK: - Plain language codes (no separator)

    func testPlainCodeIsReturnedUnchanged() {
        // "en" has no separator — the base code is the full string.
        XCTAssertEqual("en".baseLanguageCode, "en")
    }

    func testPlainCodeDeIsReturnedUnchanged() {
        XCTAssertEqual("de".baseLanguageCode, "de")
    }

    // MARK: - Hyphen-separated BCP-47 codes

    func testHyphenSeparatedRegionSubtagIsStripped() {
        // "en-US" → "en" — the region subtag is discarded.
        XCTAssertEqual("en-US".baseLanguageCode, "en")
    }

    func testHyphenSeparatedDeRegionIsStripped() {
        XCTAssertEqual("de-DE".baseLanguageCode, "de")
    }

    func testHyphenSeparatedChRegionIsStripped() {
        XCTAssertEqual("de-CH".baseLanguageCode, "de")
    }

    func testHyphenSeparatedMultipleSubtagsReturnsFirst() {
        // "en-Latn-US" — script + region subtags; only the language code matters.
        XCTAssertEqual("en-Latn-US".baseLanguageCode, "en")
    }

    // MARK: - Underscore-separated locale identifiers

    func testUnderscoreSeparatedRegionSubtagIsStripped() {
        // macOS locale identifiers sometimes use underscores (e.g. "en_US").
        XCTAssertEqual("en_US".baseLanguageCode, "en")
    }

    // MARK: - Mixed separators

    func testMixedSeparatorSplitsOnFirst() {
        // CharacterSet(charactersIn: "_-") splits on both; first component wins.
        // "en-US_variant" → split on "-" → ["en", "US_variant"] → "en"
        XCTAssertEqual("en-US_variant".baseLanguageCode, "en")
    }

    // MARK: - Edge cases

    func testEmptyStringReturnsEmpty() {
        // `components(separatedBy:).first ?? self` returns "" for "".
        XCTAssertEqual("".baseLanguageCode, "")
    }

    func testCodeWithLeadingHyphenReturnsEmptyFirstComponent() {
        // "-en" splits into ["", "en"]; first component is "".
        // This is an invalid BCP-47 code in practice, but the function must not crash.
        XCTAssertEqual("-en".baseLanguageCode, "")
    }

    func testSingleHyphenReturnsEmptyFirstComponent() {
        // "-" splits into ["", ""]; first component is "".
        XCTAssertEqual("-".baseLanguageCode, "")
    }

    func testUnknownCodeWithNoSeparatorIsReturnedAsIs() {
        // "xx" is not a known language but has no separator.
        XCTAssertEqual("xx".baseLanguageCode, "xx")
    }

    func testNumericCodeWithHyphenStripsRegion() {
        // Unusual but structurally valid input; function must not crash.
        XCTAssertEqual("123-456".baseLanguageCode, "123")
    }
}
