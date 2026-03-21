@testable import SwiftType
import XCTest

/// Extended KeyCode tests covering invariants not checked in KeyCodeTests.swift:
///   - candidateKeys contains no duplicates
///   - candidateKeys and navigationKeys are disjoint (no key handles both roles)
///   - selectNext ∪ selectPrevious == navigationKeys (complete partition)
///   - candidate digits are exactly 1–7 in order
///   - non-candidate keys all return nil for digit
@MainActor final class KeyCodeExtendedTests: XCTestCase {
    // MARK: - candidateKeys invariants

    func testCandidateKeysContainsNoDuplicates() {
        let keys = KeyCode.candidateKeys
        let unique = Set(keys)
        XCTAssertEqual(unique.count, keys.count,
                       "candidateKeys must not contain duplicate entries")
    }

    func testCandidateKeysDigitsAreConsecutiveFrom1() {
        // The digit mapping must produce exactly 1, 2, 3, 4, 5, 6, 7 in that order.
        let digits = KeyCode.candidateKeys.map(\.digit)
        XCTAssertEqual(digits, [1, 2, 3, 4, 5, 6, 7])
    }

    func testCandidateKeysAndNavigationKeysAreDisjoint() {
        // A key that is both a candidate key and a navigation key would be routed
        // ambiguously — this invariant must hold.
        let candidateSet = Set(KeyCode.candidateKeys)
        XCTAssertTrue(candidateSet.isDisjoint(with: KeyCode.navigationKeys),
                      "candidateKeys and navigationKeys must not overlap")
    }

    // MARK: - Navigation key partition

    func testSelectNextAndSelectPreviousUnionIsSubsetOfNavigationKeys() {
        // selectNextKeys and selectPreviousKeys are the column-navigation subsets of navigationKeys.
        // upArrow and downArrow are dedicated row-navigation keys handled separately in
        // InputController and are intentionally absent from both sets.
        let union = KeyCode.selectNextKeys.union(KeyCode.selectPreviousKeys)
        XCTAssertTrue(union.isSubset(of: KeyCode.navigationKeys),
                      "column nav keys must be a subset of navigationKeys")
        // Row-navigation keys are the complement.
        let rowNavKeys: Set<KeyCode> = [.upArrow, .downArrow]
        XCTAssertEqual(union.union(rowNavKeys), KeyCode.navigationKeys,
                       "column nav keys ∪ row nav keys must equal navigationKeys")
    }

    func testSelectNextAndSelectPreviousAreDisjoint() {
        // No key should be in both column-next and column-previous.
        XCTAssertTrue(KeyCode.selectNextKeys.isDisjoint(with: KeyCode.selectPreviousKeys),
                      "selectNextKeys and selectPreviousKeys must be disjoint")
    }

    func testSelectNextAndSelectPreviousAreCompleteColumnPartition() {
        // For the column-navigation keys (excluding row-nav keys), every key is in exactly one set.
        let columnNavKeys = KeyCode.navigationKeys.subtracting([.upArrow, .downArrow])
        for key in columnNavKeys {
            let inNext = KeyCode.selectNextKeys.contains(key)
            let inPrev = KeyCode.selectPreviousKeys.contains(key)
            XCTAssertTrue(inNext || inPrev,
                          "\(key) is a column nav key but is in neither selectNext nor selectPrevious")
            XCTAssertFalse(inNext && inPrev,
                           "\(key) appears in both selectNext and selectPrevious — ambiguous")
        }
    }

    func testNavigationKeysCountMatchesSelectSetsUnionPlusRowNavKeys() {
        // navigationKeys = column-nav keys (3) + row-nav keys (2) = 5.
        let columnNavUnionCount = KeyCode.selectNextKeys.union(KeyCode.selectPreviousKeys).count
        XCTAssertEqual(columnNavUnionCount + 2, KeyCode.navigationKeys.count)
    }

    // MARK: - Non-candidate keys have no digit

    func testNavigationKeysHaveNilDigit() {
        for key in KeyCode.navigationKeys {
            XCTAssertNil(key.digit, "\(key) is a navigation key and must have nil digit")
        }
    }

    func testSpecialKeysHaveNilDigit() {
        let specialKeys: [KeyCode] = [.backspace, .escape, .returnKey, .space]
        for key in specialKeys {
            XCTAssertNil(key.digit, "\(key) must have nil digit")
        }
    }

    // MARK: - Candidate key digit values are in valid range

    func testAllCandidateKeyDigitsAreWithinCandidateCountOptionsRange() {
        let maxSupported = Constants.maxSupportedGridCols
        for key in KeyCode.candidateKeys {
            guard let digit = key.digit else {
                XCTFail("\(key) should have a digit")
                continue
            }
            XCTAssertGreaterThanOrEqual(digit, 1, "\(key).digit must be ≥ 1")
            XCTAssertLessThanOrEqual(digit, maxSupported,
                                     "\(key).digit \(digit) exceeds maxSupportedGridCols \(maxSupported)")
        }
    }

    func testCandidateKeyCountMatchesMaxSupportedGridCols() {
        // The pre-allocated slot count in CandidateView equals maxSupportedGridCols.
        // If candidateKeys grows beyond that, the UI would silently ignore extra keys.
        XCTAssertEqual(KeyCode.candidateKeys.count, Constants.maxSupportedGridCols,
                       "candidateKeys.count must equal maxSupportedGridCols so every key maps to a slot")
    }

    // MARK: - Raw value uniqueness

    func testAllRawValuesAreUnique() {
        // Each KeyCode must correspond to a distinct hardware key code.
        let allCases: [KeyCode] = [
            .key1, .key2, .key3, .key4, .key5, .key6, .key7,
            .backspace, .escape, .returnKey, .space, .tab,
            .leftArrow, .rightArrow, .downArrow, .upArrow,
        ]
        let rawValues = allCases.map(\.rawValue)
        let uniqueRawValues = Set(rawValues)
        XCTAssertEqual(uniqueRawValues.count, rawValues.count,
                       "Every KeyCode case must have a unique rawValue")
    }

    // MARK: - selectNextKeys / selectPreviousKeys cross-checks

    func testSelectNextKeysContainsExactlyTwoKeys() {
        // tab, rightArrow — column-right navigation. downArrow is now a row-navigation key.
        XCTAssertEqual(KeyCode.selectNextKeys.count, 2)
    }

    func testSelectPreviousKeysContainsExactlyOneKey() {
        // leftArrow only — column-left navigation. upArrow is now a row-navigation key.
        XCTAssertEqual(KeyCode.selectPreviousKeys.count, 1)
    }
}
