@testable import SwiftType
import XCTest

/// Tests for KenLMPredictor.
///
/// KenLM model files may or may not be present in the test bundle — these tests verify
/// the structural contract (limit enforcement, no crashes, empty-input handling) regardless
/// of whether a model is loaded.  Tests that require KenLM to return results skip gracefully
/// when the model is absent.
@MainActor final class KenLMPredictorTests: XCTestCase {
    private var predictor: KenLMPredictor!

    override func setUp() async throws {
        predictor = KenLMPredictor()
    }

    override func tearDown() async throws {
        predictor = nil
    }

    // MARK: - Limit enforcement

    func testNextWordPredictionsWithLimitZeroAlwaysReturnsEmpty() {
        let results = predictor.nextWordPredictions(context: "I went to the ", limit: 0)
        XCTAssertEqual(results.count, 0)
    }

    func testNextWordPredictionsResultCountNeverExceedsLimitOfOne() {
        let results = predictor.nextWordPredictions(context: "I went to the ", limit: 1)
        XCTAssertLessThanOrEqual(results.count, 1)
    }

    func testNextWordPredictionsResultCountNeverExceedsLimitOfFive() {
        let results = predictor.nextWordPredictions(context: "I went to the ", limit: 5)
        XCTAssertLessThanOrEqual(results.count, 5)
    }

    func testNextWordPredictionsResultCountNeverExceedsLargeLimit() {
        let results = predictor.nextWordPredictions(context: "The quick brown fox ", limit: 100)
        XCTAssertLessThanOrEqual(results.count, 100)
    }

    // MARK: - Crash safety on edge inputs

    func testNextWordPredictionsDoesNotCrashOnEmptyContext() {
        XCTAssertNoThrow(
            _ = predictor.nextWordPredictions(context: "", limit: 5),
        )
    }

    func testNextWordPredictionsDoesNotCrashOnSingleWord() {
        XCTAssertNoThrow(
            _ = predictor.nextWordPredictions(context: "hello", limit: 5),
        )
    }

    func testNextWordPredictionsDoesNotCrashOnVeryLongContext() {
        let longContext = String(repeating: "word ", count: 500)
        XCTAssertNoThrow(
            _ = predictor.nextWordPredictions(context: longContext, limit: 5),
        )
    }

    func testNextWordPredictionsDoesNotCrashOnWhitespaceOnlyContext() {
        XCTAssertNoThrow(
            _ = predictor.nextWordPredictions(context: "   \n\t  ", limit: 5),
        )
    }

    func testNextWordPredictionsEmptyContextReturnsEmpty() {
        let results = predictor.nextWordPredictions(context: "", limit: 5)
        XCTAssertEqual(results.count, 0)
    }

    func testRefreshLanguageDoesNotCrash() {
        XCTAssertNoThrow(predictor.refreshLanguage())
    }

    // MARK: - Result quality (best-effort; skipped when model is absent)

    func testNextWordPredictionsResultsAreAllNonEmptyStrings() {
        let results = predictor.nextWordPredictions(context: "I love ", limit: 7)
        guard !results.isEmpty else { return }
        for word in results {
            XCTAssertFalse(word.isEmpty, "Next-word prediction must not be an empty string")
        }
    }

    func testNextWordPredictionsContainNoDuplicates() {
        let results = predictor.nextWordPredictions(context: "I am going to ", limit: 7)
        guard results.count > 1 else { return }
        let unique = Set(results)
        XCTAssertEqual(unique.count, results.count,
                       "Next-word predictions must not contain duplicates: \(results)")
    }

    // MARK: - Multiple calls are stable

    func testRepeatedCallsProduceSameCount() {
        let first = predictor.nextWordPredictions(context: "He walked to the ", limit: 5)
        let second = predictor.nextWordPredictions(context: "He walked to the ", limit: 5)
        XCTAssertEqual(first.count, second.count)
    }

    func testRefreshLanguageFollowedByPredictionsDoesNotCrash() {
        predictor.refreshLanguage()
        XCTAssertNoThrow(
            _ = predictor.nextWordPredictions(context: "The quick ", limit: 3),
        )
    }

    // MARK: - KenLMBridge singleton

    func testBridgeSingletonIsStable() {
        let a = KenLMBridge.shared()
        let b = KenLMBridge.shared()
        XCTAssertTrue(a === b, "KenLMBridge.shared() must return the same instance")
    }

    func testBridgeSetLanguageDoesNotCrashOnUnknownLanguage() {
        XCTAssertNoThrow(KenLMBridge.shared().setLanguage("xx"))
    }

    func testBridgeSetLanguageDoesNotCrashOnEmptyCode() {
        XCTAssertNoThrow(KenLMBridge.shared().setLanguage(""))
    }

    func testBridgeNextWordPredictionsReturnsEmptyWhenNoModel() {
        KenLMBridge.shared().setLanguage("xx") // No model for "xx"
        let results = KenLMBridge.shared().nextWordPredictions("hello world ", limit: 5)
        XCTAssertEqual((results as? [String])?.count ?? 0, 0)
    }
}
