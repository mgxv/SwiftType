@testable import SwiftType
import XCTest

/// Tests for `LanguageDescriptor.makeStrategy()` factory and the relationship between
/// descriptors, rules, and strategies. Locks in the contract that adding a language
/// requires only a new entry in `LanguageDescriptor.all`.
@MainActor final class LanguageDescriptorStrategyTests: XCTestCase {
    // MARK: - Strategy factories produce correct types

    func testEnglishDescriptorProducesLatinStrategy() throws {
        let desc = try XCTUnwrap(LanguageDescriptor.descriptor(for: "en"))
        let strategy = desc.makeStrategy()
        XCTAssertTrue(strategy is LatinInputStrategy,
                      "English must use LatinInputStrategy")
    }

    func testGermanDescriptorProducesLatinStrategy() throws {
        let desc = try XCTUnwrap(LanguageDescriptor.descriptor(for: "de"))
        let strategy = desc.makeStrategy()
        XCTAssertTrue(strategy is LatinInputStrategy,
                      "German must use LatinInputStrategy")
    }

    // MARK: - Factory produces fresh instances

    func testFactoryProducesFreshInstanceEachCall() throws {
        let desc = try XCTUnwrap(LanguageDescriptor.descriptor(for: "en"))
        let a = desc.makeStrategy()
        let b = desc.makeStrategy()
        XCTAssertFalse(a === b, "Factory must return a new instance on each call")
    }

    // MARK: - Every descriptor has a non-nil strategy factory

    func testAllDescriptorsHaveStrategyFactory() {
        for desc in LanguageDescriptor.all {
            let strategy = desc.makeStrategy()
            XCTAssertNotNil(strategy, "Descriptor for '\(desc.code)' must produce a non-nil strategy")
        }
    }

    // MARK: - Rules type consistency

    func testEnglishRulesType() throws {
        let desc = try XCTUnwrap(LanguageDescriptor.descriptor(for: "en"))
        XCTAssertTrue(desc.rules is EnglishTypingRules)
    }

    func testGermanRulesType() throws {
        let desc = try XCTUnwrap(LanguageDescriptor.descriptor(for: "de"))
        XCTAssertTrue(desc.rules is GermanTypingRules)
    }

    // MARK: - descriptor(for:) edge cases

    func testDescriptorForUnknownCodeReturnsNil() {
        XCTAssertNil(LanguageDescriptor.descriptor(for: "xx"))
    }

    func testDescriptorForEmptyStringReturnsNil() {
        XCTAssertNil(LanguageDescriptor.descriptor(for: ""))
    }

    func testDescriptorIsCaseSensitive() {
        // BCP-47 codes are lowercase; uppercase should not match.
        XCTAssertNil(LanguageDescriptor.descriptor(for: "EN"))
        XCTAssertNil(LanguageDescriptor.descriptor(for: "De"))
    }

    func testDescriptorDoesNotMatchSubtags() {
        // "en-US" should not match the "en" entry (baseLanguageCode stripping
        // happens in callers like refreshRules, not in descriptor lookup).
        XCTAssertNil(LanguageDescriptor.descriptor(for: "en-US"))
    }

    // MARK: - Strategy refreshLanguage does not crash

    func testLatinStrategyRefreshLanguageDoesNotCrash() {
        let strategy = LatinInputStrategy()
        XCTAssertNoThrow(strategy.refreshLanguage())
    }

    // MARK: - Display names are non-empty

    func testAllDescriptorsHaveNonEmptyDisplayName() {
        for desc in LanguageDescriptor.all {
            XCTAssertFalse(desc.displayName.isEmpty,
                           "Display name for '\(desc.code)' must not be empty")
        }
    }

    func testDisplayNamesDifferFromCodes() {
        for desc in LanguageDescriptor.all {
            XCTAssertNotEqual(desc.displayName, desc.code,
                              "Display name for '\(desc.code)' should be a human-readable name, not the code itself")
        }
    }
}
