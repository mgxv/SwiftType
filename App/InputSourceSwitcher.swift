import AppKit
import Carbon.HIToolbox
import os

struct InputSourceInfo: Sendable {
    let id: String
    let localizedName: String
}

/// Manages per-app keyboard input source auto-switching using TIS APIs.
///
/// ## Activation paths
///
/// App-focus events arrive via three redundant observers, all funnelling into
/// `handleAppActivation(bundleId:)`. The overlap is intentional — each path
/// catches a different class of app activation that the others miss:
///
/// 1. **`NSWorkspace.didActivateApplicationNotification`** — fires for the vast majority
///    of normal app switches (clicking the Dock, Cmd-Tab, etc.).
/// 2. **KVO on `NSWorkspace.frontmostApplication`** — catches activations that bypass the
///    workspace notification, such as Spotlight (Cmd-Space) and some Electron apps.
/// 3. **`InputController.activateServer`** — IMK callback when a text field gains focus
///    inside the frontmost app. Catches overlays and assistive contexts that never update
///    `frontmostApplication` at all.
///
/// `switchToAssignedSource` guards against double-switching by checking whether the
/// target source is already current before calling `TISSelectInputSource`.
///
/// ## State machine
///
/// | State | Meaning |
/// |---|---|
/// | `previousSource = nil, didAutoSwitchAway = false` | Idle — no auto-switch performed yet |
/// | `previousSource = X, didAutoSwitchAway = true` | Switched to a mapped app's assigned source; X is the source to restore when leaving |
/// | `previousSource = X, didAutoSwitchAway = false` | Restored (or never switched); previousSource retained for diagnostic logging |
///
/// When the user manually switches the keyboard while `didAutoSwitchAway` is `true`,
/// `selectedInputSourceDidChange` updates `previousSource` to reflect their intent,
/// preventing an unwanted restore to the original source.
@MainActor final class InputSourceSwitcher {
    static var shared: InputSourceSwitcher?

    private var previousSource: TISInputSource?
    private var didAutoSwitchAway = false
    private var cachedSources: [TISInputSource] = []
    private var frontmostAppObservation: NSKeyValueObservation?

    init() {
        cachedSources = Self.fetchEnabledKeyboardSources()
        installAppSwitchObservers()
        installInputSourceChangeObserver()
        Self.shared = self
        Log.inputSwitcher.info("InputSourceSwitcher initialized")
    }

    deinit {
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        DistributedNotificationCenter.default().removeObserver(self)
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Public API

    func availableInputSources() -> [InputSourceInfo] {
        cachedSources.compactMap { source in
            guard let id = source.identifier else { return nil }
            return InputSourceInfo(id: id, localizedName: source.localizedName ?? id)
        }
    }

    /// Called from three sites, each covering a different activation path:
    /// 1. didActivateApplicationNotification — normal app switches
    /// 2. frontmostApplication KVO — apps that bypass the notification (e.g. Spotlight via Cmd+Space)
    /// 3. InputController.activateServer — IMK callback when a text field gains focus,
    ///    catches Spotlight and other overlays that never update frontmostApplication
    /// switchToAssignedSource guards against double-switching when multiple paths fire.
    func handleAppActivation(bundleId: String) {
        if SettingsManager.shared.hasMapping(for: bundleId) {
            switchToAssignedSource(for: bundleId)
        } else if didAutoSwitchAway {
            restorePreviousSource()
        }
    }

    // MARK: - Per-App Auto-Switching

    private func installAppSwitchObservers() {
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(appDidActivate(_:)),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil,
        )
        frontmostAppObservation = NSWorkspace.shared.observe(\.frontmostApplication, options: []) { [weak self] _, _ in
            MainActor.assumeIsolated {
                guard let bundleId = NSWorkspace.shared.frontmostApplication?.bundleIdentifier else { return }
                self?.handleAppActivation(bundleId: bundleId)
            }
        }
    }

    @objc private func appDidActivate(_ notification: Notification) {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
              let bundleId = app.bundleIdentifier else { return }
        handleAppActivation(bundleId: bundleId)
    }

    private func switchToAssignedSource(for bundleId: String) {
        guard let target = resolveTargetSource(for: bundleId),
              currentKeyboardInputSourceID() != target.identifier else { return }

        // Save the current source before switching so we can restore it later
        if let current = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue() {
            previousSource = current
            Log.inputSwitcher.info("Saved previousSource before per-app switch: \(current.identifier ?? "unknown", privacy: .public)")
        }

        if TISSelectInputSource(target) == noErr {
            didAutoSwitchAway = true
            Log.inputSwitcher.info("Auto-switched to \(target.identifier ?? "unknown", privacy: .public) for app: \(bundleId, privacy: .public)")
        }
    }

    private func resolveTargetSource(for bundleId: String) -> TISInputSource? {
        guard let assignedID = SettingsManager.shared.inputSourceID(for: bundleId) else { return nil }
        if let source = findInputSource(withID: assignedID) {
            return source
        }
        // Assigned source is no longer available; skip the switch rather than falling back to a
        // random source. The caller will fall through to restorePreviousSource if applicable.
        Log.inputSwitcher.error("Assigned input source '\(assignedID, privacy: .public)' not found for app '\(bundleId, privacy: .public)'; skipping switch")
        return nil
    }

    private func restorePreviousSource() {
        guard let previous = previousSource,
              currentKeyboardInputSourceID() != previous.identifier
        else {
            didAutoSwitchAway = false
            return
        }

        if TISSelectInputSource(previous) == noErr {
            Log.inputSwitcher.info("Restored previous source: \(previous.identifier ?? "unknown", privacy: .public)")
        }
        didAutoSwitchAway = false
    }

    // MARK: - Input Source Helpers

    private func installInputSourceChangeObserver() {
        // Fires when the set of enabled input sources changes (installs/removals).
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(inputSourcesDidChange),
            name: NSNotification.Name(kTISNotifyEnabledKeyboardInputSourcesChanged as String),
            object: nil,
        )
        // Fires whenever the *selected* input source changes — including manual user switches.
        // Used to keep previousSource up-to-date while on a mapped app.
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(selectedInputSourceDidChange),
            name: NSNotification.Name(kTISNotifySelectedKeyboardInputSourceChanged as String),
            object: nil,
        )
    }

    @objc private func inputSourcesDidChange() {
        cachedSources = Self.fetchEnabledKeyboardSources()
    }

    /// Called whenever the active input source changes.
    ///
    /// If SwiftType previously performed an auto-switch (didAutoSwitchAway == true) and the user
    /// has now manually selected a different source while still on the mapped app, we update
    /// previousSource to reflect their new intent. This prevents the restore from snapping back
    /// to a source the user explicitly moved away from.
    @objc private func selectedInputSourceDidChange() {
        guard didAutoSwitchAway,
              let current = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue(),
              current.identifier != previousSource?.identifier
        else { return }
        previousSource = current
        Log.inputSwitcher.info("User changed source on mapped app; updated previousSource to \(current.identifier ?? "unknown", privacy: .public)")
    }

    private static func fetchEnabledKeyboardSources() -> [TISInputSource] {
        let properties = [
            kTISPropertyInputSourceCategory as String: kTISCategoryKeyboardInputSource as Any,
            kTISPropertyInputSourceIsEnabled as String: true as Any,
        ] as [String: Any] as CFDictionary

        guard let list = TISCreateInputSourceList(properties, false)?.takeRetainedValue() as? [TISInputSource] else {
            return []
        }
        return list
    }

    private func findInputSource(withID id: String) -> TISInputSource? {
        cachedSources.first { $0.identifier == id }
    }
}
