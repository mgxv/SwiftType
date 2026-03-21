@testable import SwiftType
import XCTest

/// Extended tests for `LanguageDescriptor` — catalog integrity, the `descriptor(for:)` helper,
/// and display name derivation.
@MainActor final class LanguageDescriptorExtendedTests: XCTestCase {
    // MARK: - descriptor(for:)

    func testDescriptorForKnownCodeReturnsMatch() {
        let desc = LanguageDescriptor.descriptor(for: "en")
        XCTAssertNotNil(desc)
        XCTAssertEqual(desc?.code, "en")
    }

    func testDescriptorForUnknownCodeReturnsNil() {
        XCTAssertNil(LanguageDescriptor.descriptor(for: "xx"))
    }

    func testDescriptorForEmptyStringReturnsNil() {
        XCTAssertNil(LanguageDescriptor.descriptor(for: ""))
    }

    func testDescriptorForAllKnownCodes() {
        for desc in LanguageDescriptor.all {
            XCTAssertNotNil(LanguageDescriptor.descriptor(for: desc.code),
                            "descriptor(for:) must return non-nil for catalog code '\(desc.code)'")
        }
    }

    // MARK: - Display names

    func testDisplayNameIsNonEmptyForAllDescriptors() {
        for desc in LanguageDescriptor.all {
            XCTAssertFalse(desc.displayName.isEmpty,
                           "displayName for '\(desc.code)' must not be empty")
        }
    }

    func testDisplayNameIsNotJustTheCode() {
        for desc in LanguageDescriptor.all {
            XCTAssertNotEqual(desc.displayName, desc.code,
                              "displayName for '\(desc.code)' should be a human-readable name, not the raw code")
        }
    }

    // MARK: - Strategy factory

    func testMakeStrategyReturnsNonNilForAllDescriptors() {
        for desc in LanguageDescriptor.all {
            let strategy = desc.makeStrategy()
            XCTAssertNotNil(strategy,
                            "makeStrategy() for '\(desc.code)' must return a non-nil strategy")
        }
    }

    func testEnglishStrategyIsLatin() {
        let strategy = LanguageDescriptor.descriptor(for: "en")?.makeStrategy()
        XCTAssertTrue(strategy is LatinInputStrategy)
    }

    func testGermanStrategyIsLatin() {
        let strategy = LanguageDescriptor.descriptor(for: "de")?.makeStrategy()
        XCTAssertTrue(strategy is LatinInputStrategy)
    }

    // MARK: - Rules association

    func testEnglishRulesAreEnglishTypingRules() {
        let rules = LanguageDescriptor.descriptor(for: "en")?.rules
        XCTAssertTrue(rules is EnglishTypingRules)
    }

    func testGermanRulesAreGermanTypingRules() {
        let rules = LanguageDescriptor.descriptor(for: "de")?.rules
        XCTAssertTrue(rules is GermanTypingRules)
    }
}
