# SwiftType

A macOS input method (IME) that shows a floating candidate window below the cursor as you type, offering word completions, spell corrections, and next-word predictions. Word completions use `NSSpellChecker`; next-word predictions are powered by KenLM n-gram models with truecased output.

- Runs as a background-only app (no Dock icon)
- Menu-bar icon (monospaced language code) for quick language switching and Settings
- Expandable candidate grid — columns of predictions, navigate rows with ↓/↑
- Multiple prediction languages (English, German; extensible)
- Per-app automatic input source switching
- Themeable candidate window (colors, border style, opacity, grid dimensions)

**Requirements:** macOS 13.0+ · Xcode (for building from source)

---

## Install

### From PKG (recommended)

Download the latest `SwiftType-*.pkg` from [Releases](../../releases) and double-click to install. Because the app is ad-hoc signed and not notarised, you must **right-click → Open** the installer on first launch to bypass Gatekeeper.

After installation, enable the input source:

1. Open **System Settings → Keyboard → Input Sources → +**
2. Select **SwiftType** (listed under Other)
3. Click **Add**
4. Switch to SwiftType from the input source menu in the menu bar

### Build from source

```bash
# Debug build — also auto-installs to ~/Library/Input Methods/
xcodebuild -scheme SwiftType -configuration Debug build
```

A successful Debug build automatically kills any running SwiftType process, copies the new binary to `~/Library/Input Methods/SwiftType.app`, and re-signs it. You may need to switch away from and back to SwiftType (or log out/in) for macOS to pick up the new binary.

---

## Usage

Switch to SwiftType, open any text field, and start typing. The candidate window appears below the cursor showing a row of predictions.

### Candidate selection

| Action | Result |
|---|---|
| Type letters | Candidate window shows completions |
| `1`–`7` | Commit the prediction in that column |
| `Space` | Commit the selected prediction (or literal buffer) + trailing space, then show next-word predictions |
| `Return` | Commit current selection (literal or highlighted prediction) |
| `Escape` | Commit buffer and dismiss candidate window |

### Grid navigation

The candidate window starts collapsed (one row). Press ↓ to expand it into a multi-row grid.

| Key | Action |
|---|---|
| `↓` | First press: expand to multi-row grid. Subsequent presses: move active row down |
| `↑` | Move active row up; press again at row 0 to collapse back to single row |
| `Tab` / `→` | Cycle active column right within the current row |
| `←` | Cycle active column left within the current row |

Number keys `1`–`7` always commit the prediction in the corresponding column of the **active row**.

### Next-word predictions

After committing a word with Space, the candidate window shows next-word suggestions automatically. Use the same number keys or Space to accept one and continue the chain.

---

## Architecture

SwiftType is structured around InputMethodKit's `IMKInputController`, with language-specific behaviour abstracted behind three protocols:

```
macOS ──→ IMKServer ──→ InputController
                            ├── KeyHandler (LatinKeyHandler)     — key dispatch
                            ├── InputStrategy (LatinInputStrategy) — predictions
                            │   ├── SpellCheckPredictor            — completions
                            │   └── KenLMPredictor                 — next-word (KenLM C++)
                            ├── TypingRules (English/German)       — character sets
                            └── CandidateWindow                    — floating grid UI
```

All mutable state lives in `InputState` (extracted for testability). The entire app runs on the main thread under `@MainActor` isolation (Swift 6, strict concurrency). No async/await, no background threads.

Adding a new language requires a `TypingRules` conformer, a `KeyHandler` (or reuse `LatinKeyHandler`), and an entry in `LanguageDescriptor.all`.

---

## Build a distributable PKG

```bash
# Auto-versioned (UTC timestamp)
./scripts/release/release.sh

# Explicit version
./scripts/release/release.sh 1.2.0
```

Output: `dist/SwiftType-<version>.pkg`

---

## Versioning

The app version is set automatically at build time using the UTC date and time:

```
YYYY.MM.DD.HHMMSS
```

For example: `2026.02.18.093015`. The version is written to `CFBundleShortVersionString` and `CFBundleVersion` in the built app's `Info.plist` by the **Set Build Version** build phase. The source `Info.plist` is unchanged.

---

## Tests

```bash
xcodebuild -scheme SwiftTypeTests -configuration Debug test
```

999 tests covering key routing logic, grid navigation, theme system, spell-check predictor, KenLM predictor, candidate window selection, settings persistence, typing rules, language management, and more.

---

## Settings

Open Settings from the menu-bar language icon.

**Keyboards** — configure per-app input source switching. Add a row, choose an app, and assign an input source. SwiftType will automatically switch to that source when the app is focused, and restore the previous source when you leave.

**Languages** — manage the list of prediction languages. Add or remove languages; drag to reorder. The active language can be pinned here or set to Auto (follows the system keyboard).

**Customization** — adjust the candidate window appearance: background, border, separator, text, and highlight colors via the system color picker; highlight opacity; candidate columns (4–6); and candidate rows shown when expanded (3–5).

**About** — shows the installed version.

To reset all settings to defaults:

```bash
defaults delete com.matthew.inputmethod.SwiftType
```

---

## Key design decisions

- **Main-thread only:** InputMethodKit delivers all callbacks on the main thread. Rather than fighting this, the entire codebase is `@MainActor`-isolated under Swift 6 strict concurrency, eliminating data races by construction.
- **KenLM for next-word predictions:** `NSSpellChecker` provides completions but poor next-word suggestions. KenLM n-gram models give fast, high-quality predictions with no network dependency.
- **Truecasing as a separate layer:** Models are trained on lowercase text for optimal n-gram statistics. A separate truecase map restores proper capitalisation at prediction time, which is especially important for German nouns.
- **Protocol-based language extensibility:** `TypingRules`, `KeyHandler`, and `InputStrategy` protocols allow adding languages without modifying the core input controller.
- **Pre-allocated grid:** The candidate view allocates all 5×7 cells once and shows/hides them, avoiding per-keystroke allocation.
- **Lazy loading:** Only the first page of predictions is fetched initially; additional rows are loaded on demand during grid navigation.

---

## Known limitations

- No sentence-start auto-capitalisation for next-word predictions (truecasing handles proper nouns but not "the" → "The" after a period)
- Return key does not trigger next-word predictions (asymmetric with Space)
- Context is cleared on field/app focus change (no cross-field context persistence)
- No integration tests for the full IMK key handling pipeline (requires a live Mach port)
- Adding a language requires up to three code changes with no compile-time enforcement

---

## Troubleshooting

**SwiftType does not appear in Input Sources**

The app must be installed at `~/Library/Input Methods/SwiftType.app`. Rebuild to trigger the auto-install:

```bash
xcodebuild -scheme SwiftType -configuration Debug build
```

**macOS keeps using the old binary after rebuild**

```bash
killall SwiftType 2>/dev/null; touch ~/Library/Input\ Methods/
```

Then re-activate SwiftType from the input source menu. A full log out/in is the most reliable refresh.

**Duplicate "SwiftType" entries in Keyboard Settings**

A system-level installation exists alongside the user-level one. Remove it:

```bash
sudo rm -rf /Library/Input\ Methods/SwiftType.app
```

Then log out and back in.

**"app is damaged" or Gatekeeper error**

```bash
xattr -dr com.apple.quarantine ~/Library/Input\ Methods/SwiftType.app
```
