import AppKit
@testable import SwiftType
import XCTest

@MainActor final class NSColorHexTests: XCTestCase {
    // MARK: - init(hexString:)

    func testRedChannel() {
        let color = NSColor(hexString: "#FF0000")
        XCTAssertNotNil(color)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color?.getRed(&r, green: &g, blue: &b, alpha: &a)
        XCTAssertEqual(r, 1.0, accuracy: 0.01)
        XCTAssertEqual(g, 0.0, accuracy: 0.01)
        XCTAssertEqual(b, 0.0, accuracy: 0.01)
    }

    func testGreenChannel() {
        let color = NSColor(hexString: "#00FF00")
        XCTAssertNotNil(color)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color?.getRed(&r, green: &g, blue: &b, alpha: &a)
        XCTAssertEqual(r, 0.0, accuracy: 0.01)
        XCTAssertEqual(g, 1.0, accuracy: 0.01)
        XCTAssertEqual(b, 0.0, accuracy: 0.01)
    }

    func testBlueChannel() {
        let color = NSColor(hexString: "#0000FF")
        XCTAssertNotNil(color)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color?.getRed(&r, green: &g, blue: &b, alpha: &a)
        XCTAssertEqual(r, 0.0, accuracy: 0.01)
        XCTAssertEqual(g, 0.0, accuracy: 0.01)
        XCTAssertEqual(b, 1.0, accuracy: 0.01)
    }

    func testBlack() {
        let color = NSColor(hexString: "#000000")
        XCTAssertNotNil(color)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color?.getRed(&r, green: &g, blue: &b, alpha: &a)
        XCTAssertEqual(r, 0.0, accuracy: 0.01)
        XCTAssertEqual(g, 0.0, accuracy: 0.01)
        XCTAssertEqual(b, 0.0, accuracy: 0.01)
    }

    func testWhite() {
        let color = NSColor(hexString: "#FFFFFF")
        XCTAssertNotNil(color)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color?.getRed(&r, green: &g, blue: &b, alpha: &a)
        XCTAssertEqual(r, 1.0, accuracy: 0.01)
        XCTAssertEqual(g, 1.0, accuracy: 0.01)
        XCTAssertEqual(b, 1.0, accuracy: 0.01)
    }

    func testLowercaseHex() {
        XCTAssertNotNil(NSColor(hexString: "#ff0000"))
        XCTAssertNotNil(NSColor(hexString: "#00ff00"))
        XCTAssertNotNil(NSColor(hexString: "#abcdef"))
    }

    func testHashPrefixIsOptional() {
        // Without # prefix — still works because init strips it optionally
        XCTAssertNotNil(NSColor(hexString: "FF0000"))
    }

    func testMalformedInputReturnsNil() {
        XCTAssertNil(NSColor(hexString: "not-a-color"))
        XCTAssertNil(NSColor(hexString: "#GGGGGG"))
        XCTAssertNil(NSColor(hexString: "#12345")) // 5 chars
        XCTAssertNil(NSColor(hexString: ""))
        XCTAssertNil(NSColor(hexString: "#1234567")) // 7 chars
    }

    func testMidtoneValue() {
        let color = NSColor(hexString: "#804020")
        XCTAssertNotNil(color)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color?.getRed(&r, green: &g, blue: &b, alpha: &a)
        XCTAssertEqual(r, CGFloat(0x80) / 255.0, accuracy: 0.01)
        XCTAssertEqual(g, CGFloat(0x40) / 255.0, accuracy: 0.01)
        XCTAssertEqual(b, CGFloat(0x20) / 255.0, accuracy: 0.01)
    }

    func testHexStringAlphaIsAlwaysOne() {
        // The hex-string initialiser does not accept an alpha parameter;
        // the resulting colour must always be fully opaque.
        var a: CGFloat = 0
        NSColor(hexString: "#FF0000")?.getRed(nil, green: nil, blue: nil, alpha: &a)
        XCTAssertEqual(a, 1.0, accuracy: 0.001)
    }

    func testHexStringWithLeadingAndTrailingWhitespace() {
        // The init trims whitespace before parsing, so padded strings are valid.
        let color = NSColor(hexString: "  #FF0000  ")
        XCTAssertNotNil(color)
        var r: CGFloat = 0
        color?.getRed(&r, green: nil, blue: nil, alpha: nil)
        XCTAssertEqual(r, 1.0, accuracy: 0.01)
    }

    func testHexStringHashOnlyReturnsNil() {
        // "#" alone → 0 hex digits after stripping → count ≠ 6 → nil.
        XCTAssertNil(NSColor(hexString: "#"))
    }

    func testHexStringThreeCharReturnsNil() {
        // Short-form "#FFF" (3 chars) is not accepted.
        XCTAssertNil(NSColor(hexString: "#FFF"))
    }

    func testHexStringWithSpaceInMiddleReturnsNil() {
        // Internal whitespace prevents a valid 6-hex-digit parse.
        XCTAssertNil(NSColor(hexString: "#FF 000"))
    }

    // MARK: - hexString (NSColor → #RRGGBB)

    func testHexStringRoundTripRed() throws {
        let original = "#FF0000"
        let color = try XCTUnwrap(NSColor(hexString: original))
        XCTAssertEqual(color.hexString, original)
    }

    func testHexStringRoundTripGreen() throws {
        let original = "#00FF00"
        let color = try XCTUnwrap(NSColor(hexString: original))
        XCTAssertEqual(color.hexString, original)
    }

    func testHexStringRoundTripBlue() throws {
        let original = "#0000FF"
        let color = try XCTUnwrap(NSColor(hexString: original))
        XCTAssertEqual(color.hexString, original)
    }

    func testHexStringRoundTripBlack() {
        XCTAssertEqual(NSColor(hexString: "#000000")?.hexString, "#000000")
    }

    func testHexStringRoundTripWhite() {
        XCTAssertEqual(NSColor(hexString: "#FFFFFF")?.hexString, "#FFFFFF")
    }

    func testHexStringRoundTripMidtone() {
        XCTAssertEqual(NSColor(hexString: "#804020")?.hexString, "#804020")
    }

    func testHexStringOutputIsUppercase() throws {
        // Input lowercase, output should be uppercase #RRGGBB.
        let color = try XCTUnwrap(NSColor(hexString: "#abcdef"))
        XCTAssertEqual(color.hexString, "#ABCDEF")
    }
}
