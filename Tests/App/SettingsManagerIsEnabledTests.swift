@testable import SwiftType
import XCTest

/// Tests for the isEnabled field interaction in SettingsManager.
///
/// The isEnabled field controls whether a mapping is active for auto-switching.
/// inputSourceID(for:) only returns a result when isEnabled is true.
/// hasMapping(for:) returns true regardless of isEnabled.
@MainActor final class SettingsManagerIsEnabledTests: XCTestCase {
    private var defaults: UserDefaults!
    private var manager: SettingsManager!
    private var suiteName: String!

    override func setUp() async throws {
        suiteName = "com.matthew.inputmethod.SwiftType.isenabled.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
        manager = SettingsManager(defaults: defaults)
    }

    override func tearDown() async throws {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        manager = nil
    }

    // MARK: - Default isEnabled

    func testNewMappingDefaultsToEnabled() {
        let mapping = AppInputSourceMapping(bundleId: "com.test.app", inputSourceId: "com.apple.keylayout.US")
        manager.addMapping(mapping)
        XCTAssertNotNil(manager.inputSourceID(for: "com.test.app"))
    }

    func testExplicitlyEnabledMapping() {
        let mapping = AppInputSourceMapping(bundleId: "com.test.app", inputSourceId: "com.apple.keylayout.US", isEnabled: true)
        manager.addMapping(mapping)
        XCTAssertEqual(manager.inputSourceID(for: "com.test.app"), "com.apple.keylayout.US")
    }

    func testExplicitlyDisabledMapping() {
        let mapping = AppInputSourceMapping(bundleId: "com.test.app", inputSourceId: "com.apple.keylayout.US", isEnabled: false)
        manager.addMapping(mapping)
        XCTAssertNil(manager.inputSourceID(for: "com.test.app"),
                     "Disabled mapping should not return an input source ID")
    }

    // MARK: - hasMapping ignores isEnabled

    func testHasMappingTrueForDisabledMapping() {
        let mapping = AppInputSourceMapping(bundleId: "com.test.app", inputSourceId: "com.apple.keylayout.US", isEnabled: false)
        manager.addMapping(mapping)
        XCTAssertTrue(manager.hasMapping(for: "com.test.app"),
                      "hasMapping must return true regardless of isEnabled")
    }

    // MARK: - Toggle isEnabled via updateMapping

    func testDisablingMappingMakesInputSourceIDNil() {
        let mapping = AppInputSourceMapping(bundleId: "com.test.app", inputSourceId: "com.apple.keylayout.US")
        manager.addMapping(mapping)
        XCTAssertNotNil(manager.inputSourceID(for: "com.test.app"))

        manager.updateMapping(at: 0, isEnabled: false)
        XCTAssertNil(manager.inputSourceID(for: "com.test.app"))
    }

    func testReEnablingMappingRestoresInputSourceID() {
        let mapping = AppInputSourceMapping(bundleId: "com.test.app", inputSourceId: "com.apple.keylayout.US", isEnabled: false)
        manager.addMapping(mapping)
        XCTAssertNil(manager.inputSourceID(for: "com.test.app"))

        manager.updateMapping(at: 0, isEnabled: true)
        XCTAssertEqual(manager.inputSourceID(for: "com.test.app"), "com.apple.keylayout.US")
    }

    // MARK: - inputSourceID with empty inputSourceId

    func testEnabledMappingWithEmptyInputSourceIdReturnsNil() {
        let mapping = AppInputSourceMapping(bundleId: "com.test.app", inputSourceId: "", isEnabled: true)
        manager.addMapping(mapping)
        XCTAssertNil(manager.inputSourceID(for: "com.test.app"),
                     "Empty inputSourceId should return nil even when enabled")
    }

    // MARK: - Partial update preserves isEnabled

    func testUpdateBundleIdPreservesIsEnabled() {
        let mapping = AppInputSourceMapping(bundleId: "com.test.app", inputSourceId: "com.apple.keylayout.US", isEnabled: false)
        manager.addMapping(mapping)

        manager.updateMapping(at: 0, bundleId: "com.test.newapp")
        XCTAssertEqual(manager.mappings[0].isEnabled, false,
                       "Updating bundleId should not change isEnabled")
    }

    func testUpdateInputSourceIdPreservesIsEnabled() {
        let mapping = AppInputSourceMapping(bundleId: "com.test.app", inputSourceId: "com.apple.keylayout.US", isEnabled: false)
        manager.addMapping(mapping)

        manager.updateMapping(at: 0, inputSourceId: "com.apple.keylayout.German")
        XCTAssertEqual(manager.mappings[0].isEnabled, false,
                       "Updating inputSourceId should not change isEnabled")
        XCTAssertEqual(manager.mappings[0].inputSourceId, "com.apple.keylayout.German")
    }

    // MARK: - Backward compatibility (JSON without isEnabled)

    func testDecodingJSONWithoutIsEnabledDefaultsToTrue() throws {
        let json = """
        [{"bundleId":"com.test.app","inputSourceId":"com.apple.keylayout.US"}]
        """
        let data = try XCTUnwrap(json.data(using: .utf8))
        let mappings = try JSONDecoder().decode([AppInputSourceMapping].self, from: data)
        XCTAssertEqual(mappings.count, 1)
        XCTAssertTrue(mappings[0].isEnabled,
                      "Missing isEnabled in JSON must default to true for backward compat")
    }

    func testDecodingJSONWithIsEnabledFalse() throws {
        let json = """
        [{"bundleId":"com.test.app","inputSourceId":"com.apple.keylayout.US","isEnabled":false}]
        """
        let data = try XCTUnwrap(json.data(using: .utf8))
        let mappings = try JSONDecoder().decode([AppInputSourceMapping].self, from: data)
        XCTAssertFalse(mappings[0].isEnabled)
    }
}
