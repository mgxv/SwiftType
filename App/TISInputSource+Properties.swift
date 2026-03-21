import Carbon.HIToolbox

@MainActor func currentKeyboardInputSourceID() -> String? {
    TISCopyCurrentKeyboardInputSource()?.takeRetainedValue().identifier
}

extension TISInputSource {
    var identifier: String? {
        stringProperty(kTISPropertyInputSourceID)
    }

    var localizedName: String? {
        stringProperty(kTISPropertyLocalizedName)
    }

    private func stringProperty(_ key: CFString) -> String? {
        guard let raw = TISGetInputSourceProperty(self, key) else { return nil }
        return Unmanaged<CFString>.fromOpaque(raw).takeUnretainedValue() as String
    }
}
