@testable import SwiftType
import XCTest

/// Tests for LanguageDescriptor factory methods and the consistency of the language catalog.
///
/// These tests verify that each entry in LanguageDescriptor.all produces correct types
/// and that the factories are consistent with each other.
@MainActor final class LanguageDescriptorFactoryTests: XCTestCase {
    // MARK: - Catalog completeness

    func testAllDescriptorsHaveNonEmptyCode() {
        for descriptor in LanguageDescriptor.all {
            XCTAssertFalse(descriptor.code.isEmpty, "Descriptor must have a non-empty code")
        }
    }

    func testAllDescriptorsHaveNonEmptyDisplayName() {
        for descriptor in LanguageDescriptor.all {
            XCTAssertFalse(descriptor.displayName.isEmpty,
                           "Descriptor for '\(descriptor.code)' must have a display name")
        }
    }

    func testAllCodesAreUnique() {
        let codes = LanguageDescriptor.all.map(\.code)
        let unique = Set(codes)
        XCTAssertEqual(codes.count, unique.count, "All language codes must be unique")
    }

    // MARK: - Factory output types

    func testEnglishFactoriesProduceCorrectTypes() {
        guard let descriptor = LanguageDescriptor.descriptor(for: "en") else {
            XCTFail("English descriptor must exist")
            return
        }
        XCTAssertTrue(descriptor.rules is EnglishTypingRules)
        XCTAssertTrue(descriptor.makeStrategy() is LatinInputStrategy)
        XCTAssertTrue(descriptor.makeKeyHandler() is LatinKeyHandler)
    }

    func testGermanFactoriesProduceCorrectTypes() {
        guard let descriptor = LanguageDescriptor.descriptor(for: "de") else {
            XCTFail("German descriptor must exist")
            return
        }
        XCTAssertTrue(descriptor.rules is GermanTypingRules)
        XCTAssertTrue(descriptor.makeStrategy() is LatinInputStrategy)
        XCTAssertTrue(descriptor.makeKeyHandler() is LatinKeyHandler)
    }

    // MARK: - Factory creates new instances each call

    func testMakeStrategyCreatesDistinctInstances() {
        guard let descriptor = LanguageDescriptor.descriptor(for: "en") else {
            XCTFail("English descriptor must exist")
            return
        }
        let s1 = descriptor.makeStrategy() as AnyObject
        let s2 = descriptor.makeStrategy() as AnyObject
        XCTAssertFalse(s1 === s2, "makeStrategy must create a new instance each call")
    }

    // MARK: - Rules are shared singletons

    func testEnglishRulesAreSingleton() {
        guard let descriptor = LanguageDescriptor.descriptor(for: "en") else {
            XCTFail("English descriptor must exist")
            return
        }
        let r1 = descriptor.rules as? EnglishTypingRules
        let r2 = EnglishTypingRules.shared
        XCTAssertNotNil(r1)
        // Struct equality — same values
        XCTAssertEqual(r1?.autoRemoveSpaceChars, r2.autoRemoveSpaceChars)
        XCTAssertEqual(r1?.sentenceEndingChars, r2.sentenceEndingChars)
    }

    // MARK: - Lookup

    func testDescriptorForUnknownCodeReturnsNil() {
        XCTAssertNil(LanguageDescriptor.descriptor(for: "xx"))
        XCTAssertNil(LanguageDescriptor.descriptor(for: ""))
        XCTAssertNil(LanguageDescriptor.descriptor(for: "fr"))
    }

    func testDescriptorForKnownCodesReturnsNonNil() {
        XCTAssertNotNil(LanguageDescriptor.descriptor(for: "en"))
        XCTAssertNotNil(LanguageDescriptor.descriptor(for: "de"))
    }
}
