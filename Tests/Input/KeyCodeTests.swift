@testable import SwiftType
import XCTest

@MainActor final class KeyCodeTests: XCTestCase {
    func testRawValues() {
        XCTAssertEqual(KeyCode.key1.rawValue, 18)
        XCTAssertEqual(KeyCode.key2.rawValue, 19)
        XCTAssertEqual(KeyCode.key3.rawValue, 20)
        XCTAssertEqual(KeyCode.key4.rawValue, 21)
        XCTAssertEqual(KeyCode.key5.rawValue, 23)
        XCTAssertEqual(KeyCode.key6.rawValue, 22)
        XCTAssertEqual(KeyCode.key7.rawValue, 26)
        XCTAssertEqual(KeyCode.backspace.rawValue, 51)
        XCTAssertEqual(KeyCode.escape.rawValue, 53)
        XCTAssertEqual(KeyCode.returnKey.rawValue, 36)
        XCTAssertEqual(KeyCode.space.rawValue, 49)
        XCTAssertEqual(KeyCode.tab.rawValue, 48)
        XCTAssertEqual(KeyCode.leftArrow.rawValue, 123)
        XCTAssertEqual(KeyCode.rightArrow.rawValue, 124)
        XCTAssertEqual(KeyCode.downArrow.rawValue, 125)
        XCTAssertEqual(KeyCode.upArrow.rawValue, 126)
    }

    func testCandidateKeysCount() {
        XCTAssertEqual(KeyCode.candidateKeys.count, 7)
    }

    func testCandidateKeysContents() {
        let expected: [KeyCode] = [.key1, .key2, .key3, .key4, .key5, .key6, .key7]
        XCTAssertEqual(KeyCode.candidateKeys, expected)
    }

    func testDigitMapping() {
        XCTAssertEqual(KeyCode.key1.digit, 1)
        XCTAssertEqual(KeyCode.key2.digit, 2)
        XCTAssertEqual(KeyCode.key3.digit, 3)
        XCTAssertEqual(KeyCode.key4.digit, 4)
        XCTAssertEqual(KeyCode.key5.digit, 5)
        XCTAssertEqual(KeyCode.key6.digit, 6)
        XCTAssertEqual(KeyCode.key7.digit, 7)
        XCTAssertNil(KeyCode.backspace.digit)
        XCTAssertNil(KeyCode.space.digit)
        XCTAssertNil(KeyCode.returnKey.digit)
        XCTAssertNil(KeyCode.escape.digit)
        XCTAssertNil(KeyCode.tab.digit)
    }

    func testAllCandidateKeysHaveDigits() {
        for key in KeyCode.candidateKeys {
            XCTAssertNotNil(key.digit, "\(key) should have a digit")
        }
    }

    func testNavigationKeys() {
        XCTAssertTrue(KeyCode.navigationKeys.contains(.tab))
        XCTAssertTrue(KeyCode.navigationKeys.contains(.leftArrow))
        XCTAssertTrue(KeyCode.navigationKeys.contains(.rightArrow))
        XCTAssertTrue(KeyCode.navigationKeys.contains(.upArrow))
        XCTAssertTrue(KeyCode.navigationKeys.contains(.downArrow))
        XCTAssertFalse(KeyCode.navigationKeys.contains(.space))
        XCTAssertFalse(KeyCode.navigationKeys.contains(.key1))
        XCTAssertFalse(KeyCode.navigationKeys.contains(.returnKey))
    }

    func testSelectNextKeys() {
        // Column-right navigation: tab and right arrow.
        XCTAssertTrue(KeyCode.selectNextKeys.contains(.tab))
        XCTAssertTrue(KeyCode.selectNextKeys.contains(.rightArrow))
        // Down arrow is now dedicated to grid-row navigation, not column cycling.
        XCTAssertFalse(KeyCode.selectNextKeys.contains(.downArrow))
        XCTAssertFalse(KeyCode.selectNextKeys.contains(.leftArrow))
        XCTAssertFalse(KeyCode.selectNextKeys.contains(.upArrow))
    }

    func testSelectPreviousKeys() {
        // Column-left navigation: left arrow only.
        XCTAssertTrue(KeyCode.selectPreviousKeys.contains(.leftArrow))
        // Up arrow is now dedicated to grid-row navigation, not column cycling.
        XCTAssertFalse(KeyCode.selectPreviousKeys.contains(.upArrow))
        XCTAssertFalse(KeyCode.selectPreviousKeys.contains(.tab))
        XCTAssertFalse(KeyCode.selectPreviousKeys.contains(.rightArrow))
        XCTAssertFalse(KeyCode.selectPreviousKeys.contains(.downArrow))
    }

    func testSelectNextAndPreviousAreDisjoint() {
        XCTAssertTrue(KeyCode.selectNextKeys.isDisjoint(with: KeyCode.selectPreviousKeys))
    }

    func testNavigationKeysUnionCoversNextAndPrevious() {
        XCTAssertTrue(KeyCode.selectNextKeys.isSubset(of: KeyCode.navigationKeys))
        XCTAssertTrue(KeyCode.selectPreviousKeys.isSubset(of: KeyCode.navigationKeys))
    }
}
