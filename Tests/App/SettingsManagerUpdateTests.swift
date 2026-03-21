@testable import SwiftType
import XCTest

/// Tests for `SettingsManager.updateMapping(at:...)` partial-field updates and the
/// interaction between `isEnabled`, `inputSourceID(for:)`, and `hasMapping(for:)`.
///
/// These complement the existing SettingsManagerTests by focusing on the partial-update
/// semantics: any combination of `bundleId`, `inputSourceId`, and `isEnabled` can be
/// passed, and only the provided fields are modified.
@MainActor final class SettingsManagerUpdateTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!
    private var manager: SettingsManager!

    override func setUp() async throws {
        suiteName = "com.matthew.inputmethod.SwiftType.settingsupdatetests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
        manager = SettingsManager(defaults: defaults)
    }

    override func tearDown() async throws {
        defaults.removePersistentDomain(forName: suiteName)
    }

    // MARK: - Partial field updates

    func testUpdateOnlyBundleId() {
        manager.addMapping(AppInputSourceMapping(bundleId: "com.app.old", inputSourceId: "src1"))
        manager.updateMapping(at: 0, bundleId: "com.app.new")

        XCTAssertEqual(manager.mappings[0].bundleId, "com.app.new")
        XCTAssertEqual(manager.mappings[0].inputSourceId, "src1")
        XCTAssertTrue(manager.mappings[0].isEnabled)
    }

    func testUpdateOnlyInputSourceId() {
        manager.addMapping(AppInputSourceMapping(bundleId: "com.app", inputSourceId: "old"))
        manager.updateMapping(at: 0, inputSourceId: "new")

        XCTAssertEqual(manager.mappings[0].bundleId, "com.app")
        XCTAssertEqual(manager.mappings[0].inputSourceId, "new")
    }

    func testUpdateOnlyIsEnabled() {
        manager.addMapping(AppInputSourceMapping(bundleId: "com.app", inputSourceId: "src1"))
        manager.updateMapping(at: 0, isEnabled: false)

        XCTAssertFalse(manager.mappings[0].isEnabled)
        XCTAssertEqual(manager.mappings[0].bundleId, "com.app")
    }

    func testUpdateMultipleFields() {
        manager.addMapping(AppInputSourceMapping(bundleId: "com.app", inputSourceId: "src1"))
        manager.updateMapping(at: 0, inputSourceId: "src2", isEnabled: false)

        XCTAssertEqual(manager.mappings[0].inputSourceId, "src2")
        XCTAssertFalse(manager.mappings[0].isEnabled)
    }

    func testUpdateNoFieldsIsNoop() {
        manager.addMapping(AppInputSourceMapping(bundleId: "com.app", inputSourceId: "src1"))

        let counter = NotificationCounter()
        let token = NotificationCenter.default.addObserver(
            forName: .appMappingsDidChange, object: nil, queue: nil,
        ) { _ in counter.increment() }
        defer { NotificationCenter.default.removeObserver(token) }

        manager.updateMapping(at: 0)
        // Still saves (and notifies) even with no fields — this is the current behavior
        XCTAssertEqual(counter.count, 1)
    }

    // MARK: - Out-of-bounds guard

    func testUpdateAtInvalidIndexIsNoop() {
        manager.addMapping(AppInputSourceMapping(bundleId: "com.app", inputSourceId: "src1"))
        manager.updateMapping(at: 5, bundleId: "crash?")
        XCTAssertEqual(manager.mappings.count, 1)
        XCTAssertEqual(manager.mappings[0].bundleId, "com.app")
    }

    func testUpdateAtNegativeIndexIsNoop() {
        manager.addMapping(AppInputSourceMapping(bundleId: "com.app", inputSourceId: "src1"))
        manager.updateMapping(at: -1, bundleId: "crash?")
        XCTAssertEqual(manager.mappings[0].bundleId, "com.app")
    }

    // MARK: - isEnabled interaction with inputSourceID(for:)

    func testDisabledMappingReturnsNilFromInputSourceID() {
        manager.addMapping(AppInputSourceMapping(bundleId: "com.app", inputSourceId: "src1", isEnabled: false))
        XCTAssertNil(manager.inputSourceID(for: "com.app"))
    }

    func testReEnablingMappingRestoresInputSourceID() {
        manager.addMapping(AppInputSourceMapping(bundleId: "com.app", inputSourceId: "src1", isEnabled: false))
        manager.updateMapping(at: 0, isEnabled: true)
        XCTAssertEqual(manager.inputSourceID(for: "com.app"), "src1")
    }

    func testEmptyInputSourceIdReturnsNilEvenIfEnabled() {
        manager.addMapping(AppInputSourceMapping(bundleId: "com.app", inputSourceId: ""))
        XCTAssertNil(manager.inputSourceID(for: "com.app"))
    }

    // MARK: - hasMapping vs inputSourceID

    func testHasMappingTrueRegardlessOfIsEnabled() {
        manager.addMapping(AppInputSourceMapping(bundleId: "com.app", inputSourceId: "src1", isEnabled: false))
        XCTAssertTrue(manager.hasMapping(for: "com.app"))
        XCTAssertNil(manager.inputSourceID(for: "com.app"))
    }

    // MARK: - Persistence after update

    func testUpdatePersists() {
        manager.addMapping(AppInputSourceMapping(bundleId: "com.app", inputSourceId: "src1"))
        manager.updateMapping(at: 0, inputSourceId: "src2")

        let manager2 = SettingsManager(defaults: defaults)
        XCTAssertEqual(manager2.mappings[0].inputSourceId, "src2")
    }

    // MARK: - Duplicate bundleId prevention

    func testAddDuplicateBundleIdIsNoop() {
        manager.addMapping(AppInputSourceMapping(bundleId: "com.app", inputSourceId: "src1"))
        manager.addMapping(AppInputSourceMapping(bundleId: "com.app", inputSourceId: "src2"))
        XCTAssertEqual(manager.mappings.count, 1)
        XCTAssertEqual(manager.mappings[0].inputSourceId, "src1")
    }
}
