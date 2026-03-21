@testable import SwiftType
import XCTest

/// Tests for `LatinKeyHandler` — the KeyHandler implementation for English/German.
///
/// These tests verify the pure logic of the key handler without requiring an IMKServer.
/// Methods that require `InputController` + `IMKTextInput` are tested via their
/// return values and side-effect contracts documented in CLAUDE.md.
@MainActor final class LatinKeyHandlerTests: XCTestCase {
    let handler = LatinKeyHandler()

    // MARK: - literalText

    func testLiteralTextReturnsCompositionBuffer() {
        XCTAssertEqual(handler.literalText(compositionBuffer: "hel"), "hel")
    }

    func testLiteralTextReturnsEmptyStringForEmptyBuffer() {
        XCTAssertEqual(handler.literalText(compositionBuffer: ""), "")
    }

    func testLiteralTextPreservesCaseOfBuffer() {
        XCTAssertEqual(handler.literalText(compositionBuffer: "Hello"), "Hello")
    }

    func testLiteralTextPreservesUnicode() {
        XCTAssertEqual(handler.literalText(compositionBuffer: "über"), "über")
    }

    // MARK: - unifiedPredictions

    func testUnifiedPredictionsPrependsBufferToRawWords() {
        let result = handler.unifiedPredictions(from: ["hello", "help"], compositionBuffer: "hel")
        XCTAssertEqual(result, ["hel", "hello", "help"])
    }

    func testUnifiedPredictionsWithEmptyRawWordsReturnsBufferOnly() {
        let result = handler.unifiedPredictions(from: [], compositionBuffer: "test")
        XCTAssertEqual(result, ["test"])
    }

    func testUnifiedPredictionsWithEmptyBufferStillPrepends() {
        // Edge case: empty buffer is prepended as first element.
        let result = handler.unifiedPredictions(from: ["word"], compositionBuffer: "")
        XCTAssertEqual(result, ["", "word"])
    }

    func testUnifiedPredictionsPreservesRawWordOrder() {
        let raw = ["apple", "banana", "cherry"]
        let result = handler.unifiedPredictions(from: raw, compositionBuffer: "a")
        XCTAssertEqual(result, ["a", "apple", "banana", "cherry"])
    }

    func testUnifiedPredictionsFirstElementIsAlwaysBuffer() {
        let result = handler.unifiedPredictions(from: ["x", "y", "z"], compositionBuffer: "buf")
        XCTAssertEqual(result.first, "buf")
    }

    func testUnifiedPredictionsCountIsRawWordsPlusOne() {
        let raw = ["a", "b", "c", "d", "e"]
        let result = handler.unifiedPredictions(from: raw, compositionBuffer: "x")
        XCTAssertEqual(result.count, raw.count + 1)
    }
}
