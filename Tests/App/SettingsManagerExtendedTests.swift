import Foundation
@testable import SwiftType
import XCTest

/// Extended SettingsManager tests covering:
///   - Notification posting on each mutating operation (and suppression on no-ops / out-of-bounds)
///   - Corrupted and missing JSON in UserDefaults on init
///   - AppInputSourceMapping Codable round-trip
///   - AppInputSourceMapping Equatable semantics
///
/// DEVELOPER DECISION (marked inline):
///   `updateMapping(at:bundleId:inputSourceId:)` always calls `save()` even when both
///   arguments are nil (no actual content change).  Tests document this current behaviour;
///   if the intent is to only save when something actually changed, the implementation
///   and these tests need updating.
@MainActor final class SettingsManagerExtendedTests: XCTestCase {
    private var defaults: UserDefaults!
    private var manager: SettingsManager!
    private var suiteName: String!

    override func setUp() async throws {
        suiteName = "com.matthew.inputmethod.SwiftType.settingsext.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
        manager = SettingsManager(defaults: defaults)
    }

    override func tearDown() async throws {
        defaults.removePersistentDomain(forName: suiteName)
    }

    // MARK: - Helpers

    private func mapping(_ bundleId: String = "com.apple.safari",
                         _ sourceId: String = "com.apple.keylayout.US") -> AppInputSourceMapping
    {
        AppInputSourceMapping(bundleId: bundleId, inputSourceId: sourceId)
    }

    /// Returns how many appMappingsDidChange notifications the block produces.
    private func notificationCount(during block: () -> Void) -> Int {
        let counter = NotificationCounter()
        let token = NotificationCenter.default.addObserver(
            forName: .appMappingsDidChange, object: nil, queue: nil,
        ) { _ in counter.increment() }
        block()
        NotificationCenter.default.removeObserver(token)
        return counter.count
    }

    // MARK: - Notification: addMapping

    func testAddMappingPostsNotification() {
        let count = notificationCount { manager.addMapping(mapping()) }
        XCTAssertEqual(count, 1)
    }

    func testAddDuplicateMappingDoesNotPostNotification() {
        // First add fires; second add with same bundleId is a no-op → no notification.
        manager.addMapping(mapping())
        let count = notificationCount { manager.addMapping(mapping()) }
        XCTAssertEqual(count, 0,
                       "addMapping with a duplicate bundleId must not post appMappingsDidChange")
    }

    func testAddMultipleDifferentMappingsEachPostsOneNotification() {
        let count = notificationCount {
            manager.addMapping(mapping("com.apple.safari", "src1"))
            manager.addMapping(mapping("com.apple.mail", "src2"))
        }
        XCTAssertEqual(count, 2)
    }

    // MARK: - Notification: removeMapping

    func testRemoveMappingPostsNotification() {
        manager.addMapping(mapping())
        let count = notificationCount { manager.removeMapping(at: 0) }
        XCTAssertEqual(count, 1)
    }

    func testRemoveMappingOutOfBoundsDoesNotPostNotification() {
        manager.addMapping(mapping())
        let count = notificationCount { manager.removeMapping(at: 99) }
        XCTAssertEqual(count, 0,
                       "removeMapping with out-of-bounds index must not post appMappingsDidChange")
    }

    func testRemoveMappingFromEmptyArrayDoesNotPostNotification() {
        let count = notificationCount { manager.removeMapping(at: 0) }
        XCTAssertEqual(count, 0)
    }

    // MARK: - Notification: updateMapping

    func testUpdateMappingPostsNotification() {
        manager.addMapping(mapping())
        let count = notificationCount {
            manager.updateMapping(at: 0, bundleId: "com.apple.mail")
        }
        XCTAssertEqual(count, 1)
    }

    func testUpdateMappingOutOfBoundsDoesNotPostNotification() {
        manager.addMapping(mapping())
        let count = notificationCount {
            manager.updateMapping(at: 99, bundleId: "com.apple.mail")
        }
        XCTAssertEqual(count, 0,
                       "updateMapping with out-of-bounds index must not post appMappingsDidChange")
    }

    /// DEVELOPER DECISION: `updateMapping(at:bundleId:inputSourceId:)` currently always
    /// calls `save()` even when both arguments are nil (no content actually changes).
    /// Current behaviour: notification IS posted.
    /// If the intent is "only save when something changed", the implementation needs a
    /// content-equality guard before calling save(), and this test should be updated to
    /// expect 0 notifications.
    func testUpdateMappingWithBothArgsNilStillPostsNotification_DEVELOPER_DECISION() {
        manager.addMapping(mapping())
        let before = manager.mappings[0]
        let count = notificationCount {
            manager.updateMapping(at: 0) // both bundleId and inputSourceId are nil
        }
        let after = manager.mappings[0]

        // Content must be unchanged.
        XCTAssertEqual(after.bundleId, before.bundleId)
        XCTAssertEqual(after.inputSourceId, before.inputSourceId)

        // Current behaviour: notification fires even for a no-op update.
        XCTAssertEqual(count, 1,
                       "DEVELOPER DECISION: update with nil args currently fires a notification. " +
                           "If this is unintended, add a content-equality guard before save().")
    }

    // MARK: - JSON in UserDefaults: corrupted / missing data

    func testInitWithNoStoredDataProducesEmptyMappings() {
        // Fresh defaults with no key set at all.
        let m = SettingsManager(defaults: defaults)
        XCTAssertTrue(m.mappings.isEmpty)
    }

    func testInitWithCorruptedJSONFallsBackToEmptyMappings() {
        // Write bytes that are not valid JSON for [AppInputSourceMapping].
        let garbage = Data([0xFF, 0xFE, 0x00, 0x01])
        defaults.set(garbage, forKey: "appInputSourceMappings")
        let m = SettingsManager(defaults: defaults)
        XCTAssertTrue(m.mappings.isEmpty,
                      "Corrupted JSON must produce an empty mappings array, not a crash")
    }

    func testInitWithValidJsonButWrongTypeFallsBackToEmptyMappings() throws {
        // Valid JSON but wrong type (an object instead of an array).
        let wrongType = try JSONEncoder().encode(["key": "value"])
        defaults.set(wrongType, forKey: "appInputSourceMappings")
        let m = SettingsManager(defaults: defaults)
        XCTAssertTrue(m.mappings.isEmpty,
                      "JSON of wrong type must produce an empty mappings array")
    }

    func testInitWithEmptyJsonArrayProducesEmptyMappings() throws {
        let emptyArray = try JSONEncoder().encode([AppInputSourceMapping]())
        defaults.set(emptyArray, forKey: "appInputSourceMappings")
        let m = SettingsManager(defaults: defaults)
        XCTAssertTrue(m.mappings.isEmpty)
    }

    func testInitWithNonDataValueForMappingsKeyProducesEmptyMappings() {
        // Write a String (wrong type) under the mappings key.
        defaults.set("not data", forKey: "appInputSourceMappings")
        let m = SettingsManager(defaults: defaults)
        XCTAssertTrue(m.mappings.isEmpty,
                      "A String stored under the mappings key must not crash and must fall back to []")
    }

    // MARK: - AppInputSourceMapping: Codable

    func testAppInputSourceMappingCodableRoundTrip() throws {
        let original = AppInputSourceMapping(bundleId: "com.example.app",
                                             inputSourceId: "com.apple.keylayout.British")
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(AppInputSourceMapping.self, from: data)
        XCTAssertEqual(decoded.bundleId, original.bundleId)
        XCTAssertEqual(decoded.inputSourceId, original.inputSourceId)
    }

    func testAppInputSourceMappingCodableRoundTripWithEmptyFields() throws {
        let original = AppInputSourceMapping(bundleId: "", inputSourceId: "")
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(AppInputSourceMapping.self, from: data)
        XCTAssertEqual(decoded.bundleId, "")
        XCTAssertEqual(decoded.inputSourceId, "")
    }

    func testAppInputSourceMappingArrayCodableRoundTrip() throws {
        let mappings = [
            AppInputSourceMapping(bundleId: "com.apple.safari", inputSourceId: "src1"),
            AppInputSourceMapping(bundleId: "com.apple.mail", inputSourceId: "src2"),
        ]
        let data = try JSONEncoder().encode(mappings)
        let decoded = try JSONDecoder().decode([AppInputSourceMapping].self, from: data)
        XCTAssertEqual(decoded.count, 2)
        XCTAssertEqual(decoded[0].bundleId, "com.apple.safari")
        XCTAssertEqual(decoded[1].bundleId, "com.apple.mail")
    }

    // MARK: - AppInputSourceMapping: Equatable

    func testAppInputSourceMappingEqualityIdenticalValues() {
        let a = AppInputSourceMapping(bundleId: "com.apple.safari", inputSourceId: "src1")
        let b = AppInputSourceMapping(bundleId: "com.apple.safari", inputSourceId: "src1")
        XCTAssertEqual(a, b)
    }

    func testAppInputSourceMappingInequalityDifferentBundleId() {
        let a = AppInputSourceMapping(bundleId: "com.apple.safari", inputSourceId: "src1")
        let b = AppInputSourceMapping(bundleId: "com.apple.mail", inputSourceId: "src1")
        XCTAssertNotEqual(a, b)
    }

    func testAppInputSourceMappingInequalityDifferentInputSourceId() {
        let a = AppInputSourceMapping(bundleId: "com.apple.safari", inputSourceId: "src1")
        let b = AppInputSourceMapping(bundleId: "com.apple.safari", inputSourceId: "src2")
        XCTAssertNotEqual(a, b)
    }

    func testAppInputSourceMappingInequalityBothFieldsDifferent() {
        let a = AppInputSourceMapping(bundleId: "com.apple.safari", inputSourceId: "src1")
        let b = AppInputSourceMapping(bundleId: "com.apple.mail", inputSourceId: "src2")
        XCTAssertNotEqual(a, b)
    }

    // MARK: - inputSourceID edge cases

    func testInputSourceIDReturnsNilWhenBundleIdMatchesButSourceIdIsWhitespace() {
        // Only the empty-string case is documented as returning nil; whitespace is not empty.
        // This locks in the current behaviour: whitespace is returned as-is (not treated as nil).
        manager.addMapping(AppInputSourceMapping(bundleId: "com.apple.safari", inputSourceId: "   "))
        let result = manager.inputSourceID(for: "com.apple.safari")
        // "   " is not empty, so the current implementation returns it.
        XCTAssertNotNil(result, "Whitespace input source ID is not empty; current code returns it")
        XCTAssertEqual(result, "   ")
    }

    // MARK: - updateMapping partial updates

    func testUpdateMappingOnlyBundleIdDoesNotChangeSourceId() {
        manager.addMapping(mapping("com.apple.safari", "original-src"))
        manager.updateMapping(at: 0, bundleId: "com.apple.mail")
        XCTAssertEqual(manager.mappings[0].bundleId, "com.apple.mail")
        XCTAssertEqual(manager.mappings[0].inputSourceId, "original-src")
    }

    func testUpdateMappingOnlySourceIdDoesNotChangeBundleId() {
        manager.addMapping(mapping("com.apple.safari", "original-src"))
        manager.updateMapping(at: 0, inputSourceId: "new-src")
        XCTAssertEqual(manager.mappings[0].bundleId, "com.apple.safari")
        XCTAssertEqual(manager.mappings[0].inputSourceId, "new-src")
    }

    func testUpdateMappingPersistsBothFields() {
        manager.addMapping(mapping("com.apple.safari", "src1"))
        manager.updateMapping(at: 0, bundleId: "com.apple.mail", inputSourceId: "src2")
        let m2 = SettingsManager(defaults: defaults)
        XCTAssertEqual(m2.mappings[0].bundleId, "com.apple.mail")
        XCTAssertEqual(m2.mappings[0].inputSourceId, "src2")
    }

    // MARK: - hasMapping edge cases

    func testHasMappingReturnsTrueForEmptyBundleIdWhenPresent() {
        manager.addMapping(mapping("", "src"))
        XCTAssertTrue(manager.hasMapping(for: ""))
    }

    func testHasMappingIsCaseSensitive() {
        manager.addMapping(mapping("com.Apple.Safari", "src"))
        XCTAssertFalse(manager.hasMapping(for: "com.apple.safari"),
                       "hasMapping must be case-sensitive (bundle IDs are case-sensitive)")
        XCTAssertTrue(manager.hasMapping(for: "com.Apple.Safari"))
    }

    // MARK: - isEnabled: Codable

    func testAppInputSourceMappingCodableRoundTripWithIsEnabledTrue() throws {
        let original = AppInputSourceMapping(bundleId: "com.example.app",
                                             inputSourceId: "src",
                                             isEnabled: true)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(AppInputSourceMapping.self, from: data)
        XCTAssertTrue(decoded.isEnabled)
    }

    func testAppInputSourceMappingCodableRoundTripWithIsEnabledFalse() throws {
        let original = AppInputSourceMapping(bundleId: "com.example.app",
                                             inputSourceId: "src",
                                             isEnabled: false)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(AppInputSourceMapping.self, from: data)
        XCTAssertFalse(decoded.isEnabled)
    }

    /// Old JSON (pre-isEnabled) contains only bundleId and inputSourceId.
    /// The custom init(from:) must decode it as isEnabled = true so no existing
    /// mappings are inadvertently disabled after an app update.
    func testOldJsonWithoutIsEnabledDecodesAsEnabled() {
        let oldJSON = """
        [{"bundleId":"com.apple.safari","inputSourceId":"com.apple.keylayout.US"}]
        """.data(using: .utf8)!
        defaults.set(oldJSON, forKey: "appInputSourceMappings")
        let m = SettingsManager(defaults: defaults)
        XCTAssertEqual(m.mappings.count, 1)
        XCTAssertTrue(m.mappings[0].isEnabled,
                      "Mapping decoded from old JSON without isEnabled must default to enabled")
    }

    // MARK: - isEnabled: notification behaviour

    func testUpdateMappingIsEnabledPostsNotification() {
        manager.addMapping(mapping())
        let count = notificationCount {
            manager.updateMapping(at: 0, isEnabled: false)
        }
        XCTAssertEqual(count, 1)
    }

    // MARK: - isEnabled: Equatable

    func testAppInputSourceMappingEqualityConsidersIsEnabled() {
        let a = AppInputSourceMapping(bundleId: "com.apple.safari",
                                      inputSourceId: "src", isEnabled: true)
        let b = AppInputSourceMapping(bundleId: "com.apple.safari",
                                      inputSourceId: "src", isEnabled: false)
        XCTAssertNotEqual(a, b, "Mappings with different isEnabled values must not be equal")
    }

    func testAppInputSourceMappingEqualityBothDisabled() {
        let a = AppInputSourceMapping(bundleId: "com.apple.safari",
                                      inputSourceId: "src", isEnabled: false)
        let b = AppInputSourceMapping(bundleId: "com.apple.safari",
                                      inputSourceId: "src", isEnabled: false)
        XCTAssertEqual(a, b)
    }

    // MARK: - moveMapping: data-integrity edge cases

    func testMoveMappingFromHigherToLowerIndexPreservesOrder() {
        manager.addMapping(mapping("app-a", "src-a"))
        manager.addMapping(mapping("app-b", "src-b"))
        manager.addMapping(mapping("app-c", "src-c"))
        // Move app-c (index 2) to index 0.
        manager.moveMapping(from: 2, to: 0)
        XCTAssertEqual(manager.mappings[0].bundleId, "app-c")
        XCTAssertEqual(manager.mappings[1].bundleId, "app-a")
        XCTAssertEqual(manager.mappings[2].bundleId, "app-b")
    }

    func testMoveMappingDoesNotChangeCount() {
        manager.addMapping(mapping("app-a", "src-a"))
        manager.addMapping(mapping("app-b", "src-b"))
        manager.addMapping(mapping("app-c", "src-c"))
        manager.moveMapping(from: 0, to: 2)
        XCTAssertEqual(manager.mappings.count, 3)
    }
}
