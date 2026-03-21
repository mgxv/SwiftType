@testable import SwiftType
import XCTest

/// Tests for `insertsTrailingSpace` on `TypingRules`, which controls whether
/// `commitWord` appends " " after the word. The default is defined in the
/// `TypingRules` protocol extension. This test file locks in the default for
/// all supported languages.
@MainActor final class TypingRulesBoolPropertyTests: XCTestCase {
    // MARK: - Protocol defaults (English inherits)

    func testEnglishInsertsTrailingSpaceIsTrue() {
        XCTAssertTrue(EnglishTypingRules.shared.insertsTrailingSpace)
    }

    // MARK: - German inherits default

    func testGermanInsertsTrailingSpaceIsTrue() {
        XCTAssertTrue(GermanTypingRules.shared.insertsTrailingSpace)
    }

    // MARK: - Cross-language consistency

    func testLatinLanguagesShareSameDefault() {
        let en = EnglishTypingRules.shared
        let de = GermanTypingRules.shared

        XCTAssertEqual(en.insertsTrailingSpace, de.insertsTrailingSpace)
    }
}
