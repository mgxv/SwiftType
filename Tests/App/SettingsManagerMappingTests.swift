@testable import SwiftType
import XCTest

/// Additional tests for `SettingsManager` covering mapping queries, edge cases,
/// and the `updateMapping` partial-update behaviour.
@MainActor final class SettingsManagerMappingTests: XCTestCase {
    private var defaults: UserDefaults!
    private var manager: SettingsManager!
    private var suiteName: String!

    override func setUp() async throws {
        suiteName = "com.matthew.inputmethod.SwiftType.settingsmapping.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
        manager = SettingsManager(defaults: defaults)
    }

    override func tearDown() async throws {
        defaults.removePersistentDomain(forName: suiteName)
    }

    // MARK: - inputSourceID queries

    func testInputSourceIDReturnsNilForUnknownBundle() {
        XCTAssertNil(manager.inputSourceID(for: "com.unknown.app"))
    }

    func testInputSourceIDReturnsNilWhenDisabled() {
        manager.addMapping(AppInputSourceMapping(
            bundleId: "com.test.app",
            inputSourceId: "com.apple.keylayout.US",
            isEnabled: false,
        ))
        XCTAssertNil(manager.inputSourceID(for: "com.test.app"))
    }

    func testInputSourceIDReturnsNilWhenEmpty() {
        manager.addMapping(AppInputSourceMapping(
            bundleId: "com.test.app",
            inputSourceId: "",
        ))
        XCTAssertNil(manager.inputSourceID(for: "com.test.app"))
    }

    func testInputSourceIDReturnsIDWhenValid() {
        manager.addMapping(AppInputSourceMapping(
            bundleId: "com.test.app",
            inputSourceId: "com.apple.keylayout.US",
        ))
        XCTAssertEqual(manager.inputSourceID(for: "com.test.app"), "com.apple.keylayout.US")
    }

    // MARK: - hasMapping

    func testHasMappingReturnsTrueRegardlessOfEnabled() {
        manager.addMapping(AppInputSourceMapping(
            bundleId: "com.test.app",
            inputSourceId: "x",
            isEnabled: false,
        ))
        XCTAssertTrue(manager.hasMapping(for: "com.test.app"))
    }

    func testHasMappingReturnsFalseForUnknown() {
        XCTAssertFalse(manager.hasMapping(for: "com.nope"))
    }

    // MARK: - updateMapping partial updates

    func testUpdateMappingChangesOnlyBundleId() {
        manager.addMapping(AppInputSourceMapping(
            bundleId: "old.id", inputSourceId: "source1",
        ))
        manager.updateMapping(at: 0, bundleId: "new.id")
        XCTAssertEqual(manager.mappings[0].bundleId, "new.id")
        XCTAssertEqual(manager.mappings[0].inputSourceId, "source1")
        XCTAssertTrue(manager.mappings[0].isEnabled)
    }

    func testUpdateMappingChangesOnlyInputSourceId() {
        manager.addMapping(AppInputSourceMapping(
            bundleId: "com.app", inputSourceId: "old",
        ))
        manager.updateMapping(at: 0, inputSourceId: "new")
        XCTAssertEqual(manager.mappings[0].inputSourceId, "new")
        XCTAssertEqual(manager.mappings[0].bundleId, "com.app")
    }

    func testUpdateMappingChangesOnlyIsEnabled() {
        manager.addMapping(AppInputSourceMapping(
            bundleId: "com.app", inputSourceId: "src",
        ))
        manager.updateMapping(at: 0, isEnabled: false)
        XCTAssertFalse(manager.mappings[0].isEnabled)
        XCTAssertEqual(manager.mappings[0].bundleId, "com.app")
        XCTAssertEqual(manager.mappings[0].inputSourceId, "src")
    }

    func testUpdateMappingOutOfBoundsIsSilent() {
        manager.updateMapping(at: 5, bundleId: "x")
        XCTAssertTrue(manager.mappings.isEmpty)
    }

    // MARK: - removeMapping

    func testRemoveMappingOutOfBoundsIsSilent() {
        manager.addMapping(AppInputSourceMapping(bundleId: "com.a", inputSourceId: "x"))
        manager.removeMapping(at: 5)
        XCTAssertEqual(manager.mappings.count, 1)
    }

    // MARK: - moveMapping

    func testMoveMappingSameIndexIsNoOp() {
        manager.addMapping(AppInputSourceMapping(bundleId: "a", inputSourceId: "1"))
        manager.addMapping(AppInputSourceMapping(bundleId: "b", inputSourceId: "2"))
        manager.moveMapping(from: 0, to: 0)
        XCTAssertEqual(manager.mappings.map(\.bundleId), ["a", "b"])
    }

    func testMoveMappingOutOfBoundsIsSilent() {
        manager.addMapping(AppInputSourceMapping(bundleId: "a", inputSourceId: "1"))
        manager.moveMapping(from: 0, to: 5)
        XCTAssertEqual(manager.mappings.count, 1)
    }

    func testMoveMappingReorders() {
        manager.addMapping(AppInputSourceMapping(bundleId: "a", inputSourceId: "1"))
        manager.addMapping(AppInputSourceMapping(bundleId: "b", inputSourceId: "2"))
        manager.moveMapping(from: 0, to: 1)
        XCTAssertEqual(manager.mappings.map(\.bundleId), ["b", "a"])
    }

    // MARK: - Persistence round-trip

    func testMappingsPersistAcrossInstances() {
        manager.addMapping(AppInputSourceMapping(
            bundleId: "com.test", inputSourceId: "layout",
        ))
        let m2 = SettingsManager(defaults: defaults)
        XCTAssertEqual(m2.mappings.count, 1)
        XCTAssertEqual(m2.mappings[0].bundleId, "com.test")
    }
}
