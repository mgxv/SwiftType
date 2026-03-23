import AppKit
import InputMethodKit
import os

/// Key routing and shared key handlers. Language-specific behaviour is delegated
/// to the active `keyHandler` (see `LatinKeyHandler`).
extension InputController {
    // MARK: - Key Routing

    override func handle(_ event: NSEvent!, client sender: Any!) -> Bool {
        guard let event, event.type == .keyDown else { return false }
        guard let client = sender as? (any IMKTextInput) else {
            Log.inputController.error("handle() — sender failed IMKTextInput cast, type: \(String(describing: type(of: sender)), privacy: .public)")
            return false
        }

        return MainActor.assumeIsolated {
            handleKey(event, client: client)
        }
    }

    private func handleKey(_ event: NSEvent, client: any IMKTextInput) -> Bool {
        // Pass all events through when typing in SwiftType's own windows (e.g. Settings)
        if client.bundleIdentifier() == Self.ownBundleIdentifier { return false }

        let key = KeyCode(rawValue: event.keyCode)
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

        // Pass through modifier key combinations (Cmd, Ctrl, Option)
        if !modifiers.isDisjoint(with: Self.modifierMask) {
            commitCompositionBuffer(client: client)
            return false
        }

        cancelNextWordIfNeeded(key: key, event: event)

        switch key {
        case .key1, .key2, .key3, .key4, .key5, .key6, .key7:
            if let key, handleCandidateKey(key, modifiers: modifiers, client: client) { return true }

        case .backspace:
            return handleBackspace(client: client)

        case .space:
            return keyHandler.handleSpace(controller: self, client: client)

        case .returnKey:
            return keyHandler.handleReturn(controller: self, client: client)

        case .escape:
            let hadContent = !state.compositionBuffer.isEmpty
                || CandidateWindow.shared.isVisible
            commitCompositionBuffer(client: client)
            return hadContent

        case .downArrow:
            return handleNavigation(client: client) {
                if CandidateWindow.shared.needsMorePredictionsForDownArrow() {
                    fetchMorePredictions()
                }
                CandidateWindow.shared.moveActiveRowDown()
            }

        case .upArrow:
            return handleNavigation(client: client) {
                CandidateWindow.shared.moveActiveRowUp()
            }

        case .tab, .rightArrow:
            return handleNavigation(client: client) {
                CandidateWindow.shared.moveActiveColumnRight()
            }

        case .leftArrow:
            return handleNavigation(client: client) {
                CandidateWindow.shared.moveActiveColumnLeft()
            }

        default:
            break
        }

        return handleCharacterInput(event, client: client)
    }

    // MARK: - Key Handlers

    /// Executes `action` when the candidate window is visible; otherwise commits the buffer
    /// and passes through. Shared by all arrow/tab navigation keys.
    private func handleNavigation(client: any IMKTextInput, action: () -> Void) -> Bool {
        if CandidateWindow.shared.isVisible {
            action()
            return true
        }
        commitCompositionBuffer(client: client)
        return false
    }

    private func handleCandidateKey(
        _ key: KeyCode,
        modifiers: NSEvent.ModifierFlags,
        client: any IMKTextInput,
    ) -> Bool {
        guard CandidateWindow.shared.isVisible, !modifiers.contains(.shift) else { return false }
        guard let slotIndex = KeyCode.candidateKeys.firstIndex(of: key) else { return false }

        // `slotIndex` is the 0-based column of the active grid row.
        if CandidateWindow.shared.isLiteralAt(gridColumn: slotIndex) {
            commitWord(state.compositionBuffer, client: client)
        } else if let predIdx = CandidateWindow.shared.predictionIndexAt(gridColumn: slotIndex) {
            keyHandler.handleCandidateSelection(
                predictionIndex: predIdx,
                controller: self,
                client: client,
            )
        }
        // Empty cell → do nothing (not enough predictions to fill that slot).
        return true
    }

    private func handleCharacterInput(_ event: NSEvent, client: any IMKTextInput) -> Bool {
        guard let characters = event.characters, let char = characters.first else { return false }

        if char.isLetter {
            if state.isNextWordMode { cancelPredictions() }
            state.didAutoInsertTrailingSpace = false
            state.compositionBuffer.append(char)
            Log.inputController.info("handle() keyCode=\(event.keyCode, privacy: .public) char='\(String(char), privacy: .public)' buffer='\(self.state.compositionBuffer, privacy: .public)'")
            updateMarkedText(client: client)
            updatePredictions(client: client)
            return true
        }

        // Continue composing when an apostrophe follows word characters — this keeps
        // contractions like "don't" and "I'm" in a single composition buffer rather than
        // splitting at the apostrophe.
        if state.typingRules.compositionContinuationMarks.contains(char), !state.compositionBuffer.isEmpty {
            state.compositionBuffer.append(char)
            updateMarkedText(client: client)
            updatePredictions(client: client)
            return true
        }

        if !state.compositionBuffer.isEmpty {
            commitCompositionBuffer(client: client)
        }

        // Cancel next-word mode for any non-letter, non-continuation character.
        // `cancelNextWordIfNeeded` exempts candidate key codes (1–7) so they can select
        // predictions, but Shift+number (!, @, #, …) bypasses that guard. Those chars
        // fall through here and must not leave the candidate window open.
        cancelPredictions()

        if state.typingRules.autoRemoveSpaceChars.contains(char) {
            return handleAutoSpacePunctuation(char, client: client)
        }

        return false
    }

    private func handleAutoSpacePunctuation(_ char: Character, client: any IMKTextInput) -> Bool {
        let charStr = String(char)

        if state.didAutoInsertTrailingSpace, state.typingContext.hasSuffix(" ") {
            if let replacementRange = autoInsertedSpaceRange(client: client) {
                Log.inputController.info("Auto-removing space before '\(charStr, privacy: .public)'")
                state.typingContext = String(state.typingContext.dropLast())
                client.insertText(charStr, replacementRange: replacementRange)
                state.appendToContext(charStr)
                state.didAutoInsertTrailingSpace = false
                return true
            }
        }

        client.insertText(charStr, replacementRange: Constants.replacementNotFound)
        state.appendToContext(charStr)
        state.didAutoInsertTrailingSpace = false
        return true
    }

    /// Returns the range of the auto-inserted trailing space preceding the cursor, or `nil` if not found.
    private func autoInsertedSpaceRange(client: any IMKTextInput) -> NSRange? {
        let cursorPos = client.selectedRange().location
        guard cursorPos != NSNotFound, cursorPos > 0 else { return nil }

        let range = NSRange(location: cursorPos - 1, length: 1)
        let precedingChar = client.attributedSubstring(from: range)?.string ?? ""
        guard precedingChar == " " else { return nil }

        return range
    }

    private func handleBackspace(client: any IMKTextInput) -> Bool {
        if state.isNextWordMode {
            cancelPredictions()
            return false
        }

        guard !state.compositionBuffer.isEmpty else { return false }

        state.compositionBuffer.removeLast()

        if state.compositionBuffer.isEmpty {
            // Buffer empty — clear marked text and cancel predictions.
            commitCompositionBuffer(client: client)
        } else {
            updateMarkedText(client: client)
            updatePredictions(client: client)
        }

        return true
    }
}
