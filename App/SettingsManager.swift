import Foundation

struct AppInputSourceMapping: Codable, Equatable, Sendable {
    var bundleId: String
    var inputSourceId: String
    var isEnabled: Bool

    init(bundleId: String, inputSourceId: String, isEnabled: Bool = true) {
        self.bundleId = bundleId
        self.inputSourceId = inputSourceId
        self.isEnabled = isEnabled
    }

    /// Custom decode so that JSON produced by older versions of SwiftType (which did not store
    /// isEnabled) is read back with the correct default of true rather than failing to decode.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        bundleId = try c.decode(String.self, forKey: .bundleId)
        inputSourceId = try c.decode(String.self, forKey: .inputSourceId)
        isEnabled = try c.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? true
    }
}

@MainActor final class SettingsManager {
    static let shared = SettingsManager()

    private static let mappingsKey = "appInputSourceMappings"

    private(set) var mappings: [AppInputSourceMapping]
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        guard let data = defaults.data(forKey: Self.mappingsKey) else {
            mappings = []
            return
        }
        guard let decoded = try? JSONDecoder().decode([AppInputSourceMapping].self, from: data) else {
            Log.settingsManager.error("SettingsManager — failed to decode mappings; resetting to empty")
            mappings = []
            return
        }
        mappings = decoded
    }

    // MARK: - Queries

    func inputSourceID(for bundleId: String) -> String? {
        guard let mapping = mappings.first(where: { $0.bundleId == bundleId }),
              mapping.isEnabled,
              !mapping.inputSourceId.isEmpty else { return nil }
        return mapping.inputSourceId
    }

    func hasMapping(for bundleId: String) -> Bool {
        mappings.contains { $0.bundleId == bundleId }
    }

    // MARK: - Mutations

    func addMapping(_ mapping: AppInputSourceMapping) {
        guard !hasMapping(for: mapping.bundleId) else { return }
        mappings.append(mapping)
        save()
    }

    func removeMapping(at index: Int) {
        guard mappings.indices.contains(index) else { return }
        mappings.remove(at: index)
        save()
    }

    func moveMapping(from fromIndex: Int, to toIndex: Int) {
        guard fromIndex != toIndex,
              mappings.indices.contains(fromIndex),
              mappings.indices.contains(toIndex) else { return }
        let mapping = mappings.remove(at: fromIndex)
        mappings.insert(mapping, at: toIndex)
        // No notification — the table view animates the row move itself via moveRow(at:to:)
        persistMappings()
    }

    func updateMapping(at index: Int, bundleId: String? = nil,
                       inputSourceId: String? = nil, isEnabled: Bool? = nil)
    {
        guard mappings.indices.contains(index) else { return }
        if let bundleId { mappings[index].bundleId = bundleId }
        if let inputSourceId { mappings[index].inputSourceId = inputSourceId }
        if let isEnabled { mappings[index].isEnabled = isEnabled }
        save()
    }

    // MARK: - Next Word Predictions

    private static let nextWordPredictionsKey = "general.nextWordPredictionsEnabled"

    var isNextWordPredictionsEnabled: Bool {
        defaults.object(forKey: Self.nextWordPredictionsKey) == nil
            ? false
            : defaults.bool(forKey: Self.nextWordPredictionsKey)
    }

    func setNextWordPredictionsEnabled(_ enabled: Bool) {
        guard enabled != isNextWordPredictionsEnabled else { return }
        defaults.set(enabled, forKey: Self.nextWordPredictionsKey)
        NotificationCenter.default.post(name: .nextWordPredictionsSettingDidChange, object: nil)
    }

    // MARK: - Private

    /// Persists the current mappings array to UserDefaults without posting a notification.
    /// Used directly by moveMapping (which suppresses the notification so the table view
    /// can animate the row move itself) and indirectly by save().
    private func persistMappings() {
        if let data = try? JSONEncoder().encode(mappings) {
            defaults.set(data, forKey: Self.mappingsKey)
        } else {
            Log.settingsManager.error("SettingsManager — failed to encode mappings")
        }
    }

    private func save() {
        persistMappings()
        NotificationCenter.default.post(name: .appMappingsDidChange, object: nil)
    }
}
