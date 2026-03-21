@testable import SwiftType
import XCTest

@MainActor final class SettingsManagerTests: XCTestCase {
    private var defaults: UserDefaults!
    private var manager: SettingsManager!
    private var suiteName: String!

    override func setUp() async throws {
        suiteName = "com.matthew.inputmethod.SwiftType.tests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
        manager = SettingsManager(defaults: defaults)
    }

    override func tearDown() async throws {
        defaults.removePersistentDomain(forName: suiteName)
    }

    // MARK: - Initial state

    func testInitialMappingsEmpty() {
        XCTAssertTrue(manager.mappings.isEmpty)
    }

    // MARK: - addMapping

    func testAddMappingAppends() {
        let mapping = AppInputSourceMapping(bundleId: "com.apple.safari", inputSourceId: "com.apple.keylayout.US")
        manager.addMapping(mapping)
        XCTAssertEqual(manager.mappings.count, 1)
        XCTAssertEqual(manager.mappings[0].bundleId, "com.apple.safari")
    }

    func testAddMappingDeduplicatesByBundleId() {
        let m1 = AppInputSourceMapping(bundleId: "com.apple.safari", inputSourceId: "com.apple.keylayout.US")
        let m2 = AppInputSourceMapping(bundleId: "com.apple.safari", inputSourceId: "com.apple.keylayout.British")
        manager.addMapping(m1)
        manager.addMapping(m2)
        XCTAssertEqual(manager.mappings.count, 1)
        XCTAssertEqual(manager.mappings[0].inputSourceId, "com.apple.keylayout.US")
    }

    func testAddTwoEmptyBundleIdMappingsDeduplicates() {
        manager.addMapping(AppInputSourceMapping(bundleId: "", inputSourceId: "src1"))
        manager.addMapping(AppInputSourceMapping(bundleId: "", inputSourceId: "src2"))
        XCTAssertEqual(manager.mappings.count, 1)
        XCTAssertEqual(manager.mappings[0].inputSourceId, "src1")
    }

    func testAddMultipleDifferentBundleIds() {
        manager.addMapping(AppInputSourceMapping(bundleId: "com.apple.safari", inputSourceId: "src1"))
        manager.addMapping(AppInputSourceMapping(bundleId: "com.apple.mail", inputSourceId: "src2"))
        XCTAssertEqual(manager.mappings.count, 2)
    }

    // MARK: - hasMapping

    func testHasMappingReturnsTrueWhenPresent() {
        manager.addMapping(AppInputSourceMapping(bundleId: "com.apple.safari", inputSourceId: "src"))
        XCTAssertTrue(manager.hasMapping(for: "com.apple.safari"))
    }

    func testHasMappingReturnsFalseWhenAbsent() {
        XCTAssertFalse(manager.hasMapping(for: "com.apple.safari"))
    }

    // MARK: - inputSourceID(for:)

    func testInputSourceIDReturnsCorrectValue() {
        manager.addMapping(AppInputSourceMapping(bundleId: "com.apple.safari", inputSourceId: "com.apple.keylayout.US"))
        XCTAssertEqual(manager.inputSourceID(for: "com.apple.safari"), "com.apple.keylayout.US")
    }

    func testInputSourceIDReturnsNilForEmptySourceId() {
        manager.addMapping(AppInputSourceMapping(bundleId: "com.apple.safari", inputSourceId: ""))
        XCTAssertNil(manager.inputSourceID(for: "com.apple.safari"))
    }

    func testInputSourceIDReturnsNilForUnknownBundleId() {
        XCTAssertNil(manager.inputSourceID(for: "com.unknown.app"))
    }

    // MARK: - updateMapping

    func testUpdateMappingBundleId() {
        manager.addMapping(AppInputSourceMapping(bundleId: "com.apple.safari", inputSourceId: "src"))
        manager.updateMapping(at: 0, bundleId: "com.apple.mail")
        XCTAssertEqual(manager.mappings[0].bundleId, "com.apple.mail")
        XCTAssertEqual(manager.mappings[0].inputSourceId, "src")
    }

    func testUpdateMappingInputSourceId() {
        manager.addMapping(AppInputSourceMapping(bundleId: "com.apple.safari", inputSourceId: "src1"))
        manager.updateMapping(at: 0, inputSourceId: "src2")
        XCTAssertEqual(manager.mappings[0].inputSourceId, "src2")
    }

    func testUpdateMappingOutOfBoundsIsSilent() {
        manager.addMapping(AppInputSourceMapping(bundleId: "com.apple.safari", inputSourceId: "src"))
        manager.updateMapping(at: 5, bundleId: "com.apple.mail")
        XCTAssertEqual(manager.mappings.count, 1)
        XCTAssertEqual(manager.mappings[0].bundleId, "com.apple.safari")
    }

    // MARK: - removeMapping

    func testRemoveMappingByIndex() {
        manager.addMapping(AppInputSourceMapping(bundleId: "com.apple.safari", inputSourceId: "src1"))
        manager.addMapping(AppInputSourceMapping(bundleId: "com.apple.mail", inputSourceId: "src2"))
        manager.removeMapping(at: 0)
        XCTAssertEqual(manager.mappings.count, 1)
        XCTAssertEqual(manager.mappings[0].bundleId, "com.apple.mail")
    }

    func testRemoveMappingOutOfBoundsIsSilent() {
        manager.addMapping(AppInputSourceMapping(bundleId: "com.apple.safari", inputSourceId: "src"))
        manager.removeMapping(at: 5)
        XCTAssertEqual(manager.mappings.count, 1)
    }

    // MARK: - moveMapping

    func testMoveMappingReordersArray() {
        manager.addMapping(AppInputSourceMapping(bundleId: "com.apple.safari", inputSourceId: "src1"))
        manager.addMapping(AppInputSourceMapping(bundleId: "com.apple.mail", inputSourceId: "src2"))
        manager.addMapping(AppInputSourceMapping(bundleId: "com.apple.notes", inputSourceId: "src3"))
        manager.moveMapping(from: 0, to: 2)
        XCTAssertEqual(manager.mappings[0].bundleId, "com.apple.mail")
        XCTAssertEqual(manager.mappings[1].bundleId, "com.apple.notes")
        XCTAssertEqual(manager.mappings[2].bundleId, "com.apple.safari")
    }

    func testMoveMappingSameIndexIsNoOp() {
        manager.addMapping(AppInputSourceMapping(bundleId: "com.apple.safari", inputSourceId: "src1"))
        manager.addMapping(AppInputSourceMapping(bundleId: "com.apple.mail", inputSourceId: "src2"))
        manager.moveMapping(from: 0, to: 0)
        XCTAssertEqual(manager.mappings[0].bundleId, "com.apple.safari")
        XCTAssertEqual(manager.mappings[1].bundleId, "com.apple.mail")
    }

    func testMoveMappingOutOfBoundsFromIsSilent() {
        manager.addMapping(AppInputSourceMapping(bundleId: "com.apple.safari", inputSourceId: "src1"))
        manager.addMapping(AppInputSourceMapping(bundleId: "com.apple.mail", inputSourceId: "src2"))
        manager.moveMapping(from: 5, to: 0)
        XCTAssertEqual(manager.mappings.count, 2)
        XCTAssertEqual(manager.mappings[0].bundleId, "com.apple.safari")
    }

    func testMoveMappingOutOfBoundsToIsSilent() {
        manager.addMapping(AppInputSourceMapping(bundleId: "com.apple.safari", inputSourceId: "src1"))
        manager.addMapping(AppInputSourceMapping(bundleId: "com.apple.mail", inputSourceId: "src2"))
        manager.moveMapping(from: 0, to: 5)
        XCTAssertEqual(manager.mappings.count, 2)
        XCTAssertEqual(manager.mappings[0].bundleId, "com.apple.safari")
    }

    func testMoveMappingPersists() {
        manager.addMapping(AppInputSourceMapping(bundleId: "com.apple.safari", inputSourceId: "src1"))
        manager.addMapping(AppInputSourceMapping(bundleId: "com.apple.mail", inputSourceId: "src2"))
        manager.moveMapping(from: 0, to: 1)
        let manager2 = SettingsManager(defaults: defaults)
        XCTAssertEqual(manager2.mappings[0].bundleId, "com.apple.mail")
        XCTAssertEqual(manager2.mappings[1].bundleId, "com.apple.safari")
    }

    func testMoveMappingDoesNotPostNotification() {
        manager.addMapping(AppInputSourceMapping(bundleId: "com.apple.safari", inputSourceId: "src1"))
        manager.addMapping(AppInputSourceMapping(bundleId: "com.apple.mail", inputSourceId: "src2"))
        let counter = NotificationCounter()
        let token = NotificationCenter.default.addObserver(
            forName: .appMappingsDidChange, object: nil, queue: nil,
        ) { _ in counter.increment() }
        manager.moveMapping(from: 0, to: 1)
        NotificationCenter.default.removeObserver(token)
        XCTAssertEqual(counter.count, 0, "moveMapping must not post appMappingsDidChange")
    }

    // MARK: - isEnabled

    func testIsEnabledDefaultsToTrue() {
        let m = AppInputSourceMapping(bundleId: "com.apple.safari", inputSourceId: "src")
        XCTAssertTrue(m.isEnabled)
    }

    func testIsEnabledFalseCanBeSet() {
        let m = AppInputSourceMapping(bundleId: "com.apple.safari", inputSourceId: "src", isEnabled: false)
        XCTAssertFalse(m.isEnabled)
    }

    func testInputSourceIDReturnsNilForDisabledMapping() {
        manager.addMapping(AppInputSourceMapping(bundleId: "com.apple.safari",
                                                 inputSourceId: "com.apple.keylayout.US",
                                                 isEnabled: false))
        XCTAssertNil(manager.inputSourceID(for: "com.apple.safari"),
                     "Disabled mapping must not return an input source ID")
    }

    func testInputSourceIDReturnsValueForEnabledMapping() {
        manager.addMapping(AppInputSourceMapping(bundleId: "com.apple.safari",
                                                 inputSourceId: "com.apple.keylayout.US",
                                                 isEnabled: true))
        XCTAssertEqual(manager.inputSourceID(for: "com.apple.safari"), "com.apple.keylayout.US")
    }

    func testHasMappingReturnsTrueForDisabledMapping() {
        manager.addMapping(AppInputSourceMapping(bundleId: "com.apple.safari",
                                                 inputSourceId: "src",
                                                 isEnabled: false))
        XCTAssertTrue(manager.hasMapping(for: "com.apple.safari"),
                      "hasMapping is structural — disabled mappings are still present")
    }

    func testUpdateMappingTogglesEnabled() {
        manager.addMapping(AppInputSourceMapping(bundleId: "com.apple.safari", inputSourceId: "src"))
        XCTAssertTrue(manager.mappings[0].isEnabled)
        manager.updateMapping(at: 0, isEnabled: false)
        XCTAssertFalse(manager.mappings[0].isEnabled)
        manager.updateMapping(at: 0, isEnabled: true)
        XCTAssertTrue(manager.mappings[0].isEnabled)
    }

    func testUpdateMappingEnabledPersists() {
        manager.addMapping(AppInputSourceMapping(bundleId: "com.apple.safari", inputSourceId: "src"))
        manager.updateMapping(at: 0, isEnabled: false)
        let manager2 = SettingsManager(defaults: defaults)
        XCTAssertFalse(manager2.mappings[0].isEnabled,
                       "isEnabled = false must survive a UserDefaults round-trip")
    }

    func testDisabledMappingDoesNotAffectCount() {
        manager.addMapping(AppInputSourceMapping(bundleId: "com.apple.safari", inputSourceId: "src"))
        manager.updateMapping(at: 0, isEnabled: false)
        XCTAssertEqual(manager.mappings.count, 1,
                       "Disabling a mapping must not remove it from the array")
    }

    // MARK: - Persistence

    func testPersistenceRoundTrip() {
        manager.addMapping(AppInputSourceMapping(bundleId: "com.apple.safari", inputSourceId: "com.apple.keylayout.US"))
        let manager2 = SettingsManager(defaults: defaults)
        XCTAssertEqual(manager2.mappings.count, 1)
        XCTAssertEqual(manager2.mappings[0].bundleId, "com.apple.safari")
        XCTAssertEqual(manager2.mappings[0].inputSourceId, "com.apple.keylayout.US")
    }

    func testNoContaminationWithStandardDefaults() {
        manager.addMapping(AppInputSourceMapping(bundleId: "com.apple.safari", inputSourceId: "src"))
        XCTAssertEqual(SettingsManager.shared.mappings.count(where: { $0.bundleId == "com.apple.safari" }), 0,
                       "Test writes must not leak into UserDefaults.standard")
    }
}
