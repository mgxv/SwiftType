import AppKit
import InputMethodKit
import os

/// IMKInputController activation, deactivation, and document-seeding helper.
extension InputController {
    // MARK: - IMKInputController Overrides

    override func activateServer(_ sender: Any!) {
        let client = sender as? (any IMKTextInput)
        MainActor.assumeIsolated {
            Log.inputController.info("activateServer — sender: \(client?.bundleIdentifier() ?? "nil", privacy: .public)")
            if let bundleId = client?.bundleIdentifier() {
                InputSourceSwitcher.shared?.handleAppActivation(bundleId: bundleId)
            }
            resetState()
            refreshRules()
            if let client { seedContextFromDocument(client: client) }
        }
    }

    override func deactivateServer(_ sender: Any!) {
        let client = sender as? (any IMKTextInput)
        MainActor.assumeIsolated {
            Log.inputController.info("deactivateServer — sender: \(client?.bundleIdentifier() ?? "nil", privacy: .public)")
            if let client {
                commitCompositionBuffer(client: client)
            }
            CandidateWindow.shared.hide()
        }
    }

    override func composedString(_: Any!) -> Any! {
        state.compositionBuffer
    }

    override func originalString(_: Any!) -> NSAttributedString! {
        NSAttributedString(string: state.compositionBuffer)
    }

    override func commitComposition(_ sender: Any!) {
        let client = sender as? (any IMKTextInput)
        MainActor.assumeIsolated {
            Log.inputController.info("commitComposition called by system")
            if let client {
                commitCompositionBuffer(client: client)
            }
        }
    }

    // MARK: - Document Seeding

    /// Seeds `typingContext` from the document text preceding the cursor to provide
    /// context for spell-checking and predictions when switching to SwiftType mid-document.
    /// Falls back gracefully when the app does not support text queries.
    private func seedContextFromDocument(client: any IMKTextInput) {
        let cursorPos = client.selectedRange().location
        guard cursorPos != NSNotFound, cursorPos > 0 else { return }
        let fetchLength = min(cursorPos, InputState.maxContextLength)
        let range = NSRange(location: cursorPos - fetchLength, length: fetchLength)
        guard let text = client.attributedSubstring(from: range)?.string, !text.isEmpty else { return }
        state.typingContext = text
        Log.inputController.info("seedContextFromDocument — seeded \(text.count, privacy: .public) chars")
    }
}
