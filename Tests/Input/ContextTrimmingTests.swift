@testable import SwiftType
import XCTest

// These tests cover `InputState.trimContext(_:)` — pure function containing the
// sentence-boundary trimming algorithm used by `appendToContext`. Keeps `typingContext`
// coherent by trimming at detected sentence starts rather than chopping mid-word.
//
// Tests call the real production methods directly via `@testable import SwiftType`.

@MainActor final class ContextTrimmingTests: XCTestCase {
    // MARK: - trimContext — single / zero sentences

    func testTrimContext_emptyStringReturnsEmpty() {
        // No sentences detected → suffix(300) of "" = "".
        XCTAssertEqual(InputState.trimContext(""), "")
    }

    func testTrimContext_shortSingleSentenceFallsBackToSuffix300() {
        // Only one sentence detected — no interior trim point.
        // suffix(300) of a string shorter than 300 chars returns the whole string.
        let sentence = "This is a single sentence with one period. "
        let result = InputState.trimContext(sentence)
        XCTAssertEqual(result, String(sentence.suffix(300)))
    }

    func testTrimContext_longSingleSentenceCappedAt300() {
        // One very long sentence: suffix(300) caps the result.
        let longSentence = String(repeating: "word ", count: 100) // 500 chars, no period
        let result = InputState.trimContext(longSentence)
        XCTAssertEqual(result.count, 300)
        XCTAssertEqual(result, String(longSentence.suffix(300)))
    }

    // MARK: - trimContext — two sentences (keepFrom == startIndex edge case)

    func testTrimContext_exactlyTwoSentencesFallsBackToSuffix300() {
        // With two sentences sentenceStarts[0] == context.startIndex,
        // so the guard `keepFrom > startIndex` fails → suffix(300).
        let context = "The cat sat on the mat. The dog lay on the floor. "
        let result = InputState.trimContext(context)
        XCTAssertEqual(result, String(context.suffix(300)))
    }

    // MARK: - trimContext — three or more sentences (normal trim path)

    func testTrimContext_threeSentencesTrimsToSecondToLast() {
        // Three sentences: result should begin at the second sentence,
        // i.e., the first sentence is shed.
        let s1 = "The first sentence is here. "
        let s2 = "The second sentence follows. "
        let s3 = "The third sentence concludes. "
        let context = s1 + s2 + s3

        let result = InputState.trimContext(context)

        // Starts at the second sentence.
        XCTAssertTrue(result.hasPrefix("The second"),
                      "Expected trim from second sentence start; got: '\(result)'")
        // The first sentence must have been removed.
        XCTAssertFalse(result.hasPrefix("The first"),
                       "First sentence should be shed; got: '\(result)'")
    }

    func testTrimContext_fourSentencesKeepsTwoLastSentences() {
        // Four sentences: second-to-last is sentence[2]; trim from there.
        let s1 = "Alpha sentence here. "
        let s2 = "Beta sentence here. "
        let s3 = "Gamma sentence here. "
        let s4 = "Delta sentence here. "
        let context = s1 + s2 + s3 + s4

        let result = InputState.trimContext(context)

        XCTAssertTrue(result.hasPrefix("Gamma"),
                      "Expected result to start with 'Gamma'; got: '\(result)'")
    }

    func testTrimContext_trimmedResultExceeding400CharsIsCappedAt300() {
        // The second-to-last sentence itself is > 400 chars →
        // the hard cap applies: result is suffix(300) of trimmed.
        let s1 = "Short intro. "
        // A long second sentence (> 400 chars):
        let s2 = String(repeating: "long ", count: 90) + "sentence. " // ~460 chars
        let s3 = "Short end. "
        let context = s1 + s2 + s3

        let result = InputState.trimContext(context)

        XCTAssertLessThanOrEqual(result.count, 300,
                                 "Result should be hard-capped at 300; got \(result.count)")
    }
}
