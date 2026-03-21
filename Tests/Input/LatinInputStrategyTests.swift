@testable import SwiftType
import XCTest

/// Tests for `LatinInputStrategy` — the InputStrategy wrapping SpellCheckPredictor + KenLMPredictor.
///
/// These tests verify the structural contract (delegation, limit enforcement, crash safety)
/// without requiring specific dictionary or model content. Tests that need real predictions
/// skip gracefully when unavailable.
@MainActor final class LatinInputStrategyTests: XCTestCase {
    private var strategy: LatinInputStrategy!

    override func setUp() async throws {
        strategy = LatinInputStrategy()
    }

    override func tearDown() async throws {
        strategy = nil
    }

    // MARK: - completions

    func testCompletionsDoesNotCrashOnEmptyPartial() {
        XCTAssertNoThrow(
            _ = strategy.completions(context: "Hello ", partial: "", limit: 5),
        )
    }

    func testCompletionsDoesNotCrashOnEmptyContext() {
        XCTAssertNoThrow(
            _ = strategy.completions(context: "", partial: "hel", limit: 5),
        )
    }

    func testCompletionsRespectsLimit() {
        let results = strategy.completions(context: "", partial: "th", limit: 3)
        XCTAssertLessThanOrEqual(results.count, 3)
    }

    func testCompletionsWithLimitZeroReturnsEmpty() {
        let results = strategy.completions(context: "", partial: "hello", limit: 0)
        XCTAssertEqual(results.count, 0)
    }

    func testCompletionsResultsAreNonEmpty() {
        let results = strategy.completions(context: "", partial: "hel", limit: 10)
        for word in results {
            XCTAssertFalse(word.isEmpty, "Completion must not be an empty string")
        }
    }

    // MARK: - nextWordPredictions

    func testNextWordPredictionsDoesNotCrashOnEmptyContext() {
        XCTAssertNoThrow(
            _ = strategy.nextWordPredictions(context: "", limit: 5),
        )
    }

    func testNextWordPredictionsRespectsLimit() {
        let results = strategy.nextWordPredictions(context: "I went to the ", limit: 3)
        XCTAssertLessThanOrEqual(results.count, 3)
    }

    func testNextWordPredictionsWithLimitZeroReturnsEmpty() {
        let results = strategy.nextWordPredictions(context: "Hello ", limit: 0)
        XCTAssertEqual(results.count, 0)
    }

    // MARK: - refreshLanguage

    func testRefreshLanguageDoesNotCrash() {
        XCTAssertNoThrow(strategy.refreshLanguage())
    }

    func testRefreshLanguageCanBeCalledMultipleTimes() {
        strategy.refreshLanguage()
        strategy.refreshLanguage()
        strategy.refreshLanguage()
        // Should not crash or accumulate state issues.
    }

    // MARK: - Protocol conformance

    func testConformsToInputStrategy() {
        XCTAssertTrue(strategy is InputStrategy)
    }
}
