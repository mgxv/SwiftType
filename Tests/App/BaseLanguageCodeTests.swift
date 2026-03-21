@testable import SwiftType
import XCTest

/// Tests for the `String.baseLanguageCode` extension.
///
/// This property strips BCP-47 region and script subtags, returning only the
/// bare language code. It is used by LanguageManager, InputController, and predictors
/// to normalize language identifiers.
@MainActor final class BaseLanguageCodeTests: XCTestCase {
    // MARK: - Standard cases

    func testEnglishUSStripsRegion() {
        XCTAssertEqual("en-US".baseLanguageCode, "en")
    }

    func testGermanDEStripsRegion() {
        XCTAssertEqual("de-DE".baseLanguageCode, "de")
    }

    func testEnglishUSUnderscoreStripsRegion() {
        XCTAssertEqual("en_US".baseLanguageCode, "en")
    }

    func testGermanDEUnderscoreStripsRegion() {
        XCTAssertEqual("de_DE".baseLanguageCode, "de")
    }

    // MARK: - No subtags

    func testBareCodeIsUnchanged() {
        XCTAssertEqual("en".baseLanguageCode, "en")
    }

    func testSingleCharCodeIsUnchanged() {
        XCTAssertEqual("x".baseLanguageCode, "x")
    }

    // MARK: - Multiple subtags

    func testThreePartCodeStripsAll() {
        // zh-Hans-CN → zh
        XCTAssertEqual("zh-Hans-CN".baseLanguageCode, "zh")
    }

    func testMultipleUnderscores() {
        XCTAssertEqual("pt_BR_variant".baseLanguageCode, "pt")
    }

    // MARK: - Edge cases

    func testEmptyStringReturnsEmpty() {
        XCTAssertEqual("".baseLanguageCode, "")
    }

    func testStringWithOnlySeparatorReturnsEmpty() {
        XCTAssertEqual("-".baseLanguageCode, "")
    }

    func testStringWithOnlyUnderscoreReturnsEmpty() {
        XCTAssertEqual("_".baseLanguageCode, "")
    }

    func testMixedSeparators() {
        // "en-US_variant" should split on both - and _
        XCTAssertEqual("en-US_variant".baseLanguageCode, "en")
    }

    func testLeadingSeparatorReturnsEmpty() {
        XCTAssertEqual("-en".baseLanguageCode, "")
    }
}
