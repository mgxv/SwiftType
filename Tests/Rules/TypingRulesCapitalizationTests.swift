@testable import SwiftType
import XCTest

/// Focused tests for the `TypingRules` capitalisation protocol defaults across all
/// three language conformers.
@MainActor final class TypingRulesCapitalizationTests: XCTestCase {
    // MARK: - preserveCapitalization

    func testPreserveCapitalizationUpperFirst() {
        let result = EnglishTypingRules.shared.preserveCapitalization(
            original: "Hello", suggested: "hello",
        )
        XCTAssertEqual(result, "Hello")
    }

    func testPreserveCapitalizationLowerFirst() {
        let result = EnglishTypingRules.shared.preserveCapitalization(
            original: "hello", suggested: "world",
        )
        XCTAssertEqual(result, "world")
    }

    func testPreserveCapitalizationEmptyOriginal() {
        let result = EnglishTypingRules.shared.preserveCapitalization(
            original: "", suggested: "word",
        )
        XCTAssertEqual(result, "word")
    }

    func testPreserveCapitalizationEmptySuggested() {
        let result = EnglishTypingRules.shared.preserveCapitalization(
            original: "Hello", suggested: "",
        )
        XCTAssertEqual(result, "")
    }

    func testPreserveCapitalizationSingleChar() {
        let result = EnglishTypingRules.shared.preserveCapitalization(
            original: "H", suggested: "hello",
        )
        XCTAssertEqual(result, "Hello")
    }

    func testPreserveCapitalizationNonLetterFirst() {
        let result = EnglishTypingRules.shared.preserveCapitalization(
            original: "1test", suggested: "one",
        )
        XCTAssertEqual(result, "one")
    }

    // MARK: - applyCapitalization

    func testApplyCapitalizationUppercaseOriginalUppercases() {
        let result = EnglishTypingRules.shared.applyCapitalization(
            original: "H", suggested: "hello", context: "Done. ",
        )
        XCTAssertEqual(result, "Hello")
    }

    func testApplyCapitalizationMidSentenceUsesPreserve() {
        let result = EnglishTypingRules.shared.applyCapitalization(
            original: "H", suggested: "hello", context: "The quick ",
        )
        XCTAssertEqual(result, "Hello")
    }

    func testApplyCapitalizationMidSentenceLowercaseOriginal() {
        let result = EnglishTypingRules.shared.applyCapitalization(
            original: "h", suggested: "hello", context: "The quick ",
        )
        XCTAssertEqual(result, "hello")
    }

    // MARK: - German-specific capitalisation

    func testGermanApplyCapitalizationPreservesUppercaseOriginal() {
        let result = GermanTypingRules.shared.applyCapitalization(
            original: "E", suggested: "es", context: "Er sagte: ",
        )
        XCTAssertEqual(result, "Es")
    }

    func testGermanPreserveCapitalizationNoun() {
        let result = GermanTypingRules.shared.preserveCapitalization(
            original: "H", suggested: "haus",
        )
        XCTAssertEqual(result, "Haus")
    }
}
