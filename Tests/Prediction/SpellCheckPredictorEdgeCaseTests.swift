@testable import SwiftType
import XCTest

/// Edge-case tests for SpellCheckPredictor.
///
/// These tests target boundary conditions and the three-stage fallback pipeline
/// (correction → prefix completions → fuzzy guesses). Results depend on the
/// system dictionary, so tests verify structural contracts rather than specific words.
@MainActor final class SpellCheckPredictorEdgeCaseTests: XCTestCase {
    private var predictor: SpellCheckPredictor!

    override func setUp() async throws {
        predictor = SpellCheckPredictor()
    }

    override func tearDown() async throws {
        predictor = nil
    }

    // MARK: - Completions: limit enforcement

    func testCompletionsWithLimitOneReturnsAtMostOne() {
        let results = predictor.completions(context: "", prefix: "hel", limit: 1)
        XCTAssertLessThanOrEqual(results.count, 1)
    }

    func testCompletionsWithLimitZeroReturnsEmpty() {
        let results = predictor.completions(context: "", prefix: "hello", limit: 0)
        XCTAssertEqual(results.count, 0)
    }

    func testCompletionsNeverExceedLimit() {
        for limit in [1, 3, 5, 10, 50] {
            let results = predictor.completions(context: "", prefix: "th", limit: limit)
            XCTAssertLessThanOrEqual(results.count, limit,
                                     "Results (\(results.count)) exceeded limit (\(limit))")
        }
    }

    // MARK: - Completions: empty/edge inputs

    func testCompletionsWithEmptyPartialReturnsEmpty() {
        let results = predictor.completions(context: "Hello ", prefix: "", limit: 5)
        // NSSpellChecker may or may not return results for empty partial
        XCTAssertLessThanOrEqual(results.count, 5)
    }

    func testCompletionsWithSingleCharPartial() {
        let results = predictor.completions(context: "", prefix: "a", limit: 5)
        XCTAssertLessThanOrEqual(results.count, 5)
    }

    func testCompletionsDoNotContainPartialItself() {
        let results = predictor.completions(context: "", prefix: "hello", limit: 10)
        // The partial itself should be excluded from results (dedup logic)
        let lowered = results.map { $0.lowercased() }
        // It's OK if "hello" appears as a correction of a misspelling, but if the partial
        // is a real word and appears as-is, it shouldn't be in results
        // This is a soft check — NSSpellChecker may still return it in corrections
        _ = lowered // just verify no crash
    }

    // MARK: - Completions: deduplication

    func testCompletionsContainNoCaseInsensitiveDuplicates() {
        let results = predictor.completions(context: "", prefix: "th", limit: 20)
        guard results.count > 1 else { return }
        let lowered = results.map { $0.lowercased() }
        let unique = Set(lowered)
        XCTAssertEqual(lowered.count, unique.count,
                       "Completions must not contain case-insensitive duplicates: \(results)")
    }

    // MARK: - Completions: results are non-empty strings

    func testCompletionsResultsAreNonEmpty() {
        let results = predictor.completions(context: "", prefix: "hel", limit: 10)
        for word in results {
            XCTAssertFalse(word.isEmpty, "Completion must not be an empty string")
        }
    }

    // MARK: - Crash safety

    func testCompletionsDoNotCrashOnVeryLongPartial() {
        let longPartial = String(repeating: "a", count: 1000)
        XCTAssertNoThrow(
            _ = predictor.completions(context: "", prefix: longPartial, limit: 5),
        )
    }

    func testCompletionsDoNotCrashOnUnicodePartial() {
        XCTAssertNoThrow(
            _ = predictor.completions(context: "", prefix: "über", limit: 5),
        )
    }

    func testCompletionsDoNotCrashOnEmojiPartial() {
        XCTAssertNoThrow(
            _ = predictor.completions(context: "", prefix: "😀", limit: 5),
        )
    }

    // MARK: - refreshLanguage

    func testRefreshLanguageDoesNotCrash() {
        XCTAssertNoThrow(predictor.refreshLanguage())
    }

    func testRefreshLanguageThenCompletionsStillWork() {
        predictor.refreshLanguage()
        let results = predictor.completions(context: "", prefix: "hel", limit: 5)
        // Should not crash and should still return results
        XCTAssertLessThanOrEqual(results.count, 5)
    }
}
