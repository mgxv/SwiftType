# SwiftType

<div align="center">
  <video src="https://github.com/user-attachments/assets/10520e05-88eb-41de-b4cb-d3d6b2302cea" autoplay loop muted playsinline style="max-width: 70%;"></video>
</div>

A native macOS input method that predicts what you're typing — and what you'll type next. It shows a floating candidate bar below your cursor with word completions, spelling corrections, and next-word suggestions, all running locally with no network calls.

Built with Swift 6 and [InputMethodKit](https://developer.apple.com/documentation/inputmethodkit). Next-word predictions are powered by [KenLM](https://kheafield.com/code/kenlm/) n-gram language models, integrated through an Objective-C++ bridge.

---

## ✨ Features

- **Word completions & spell correction** as you type, powered by macOS's built-in spell checker
- **Next-word predictions** after committing a word — chain predictions by pressing Space repeatedly
- **Fully offline** — all predictions run locally using bundled language models, no data leaves your machine
- **Expandable candidate grid** — starts as a single row, expands into a navigable multi-row grid with lazy loading
- **Per-app input source switching** — automatically switch keyboard layouts when you focus different apps
- **Themeable candidate window** — customize colors, opacity, grid size, and border through the Settings UI
- **Menu bar integration** — shows the active language code; click to switch languages or open Settings
- **Multiple languages** — English and German included, with a protocol-based architecture for adding more

---

## 🖥️ Requirements

macOS 13.0 or later. Xcode required only if building from source.

---

## 📦 Install

### From PKG (recommended)

Download the latest `.pkg` from [Releases](../../releases) and double-click to install. The app is ad-hoc signed and not notarized, so you'll need to **right-click → Open** the installer on first launch to bypass Gatekeeper.

### Build from source

```bash
xcodebuild -scheme SwiftType -configuration Debug build
```

A Debug build automatically installs to `~/Library/Input Methods/`.

### Enable the input source

1. Open **System Settings → Keyboard → Input Sources → Edit → +**
2. Select **SwiftType**
3. Click **Add**
4. Switch to SwiftType from the input source menu in the menu bar

---

## 🚀 Usage

Switch to SwiftType, open any text field, and start typing. The candidate bar appears below your cursor.

### Candidate selection

| Key | Action |
|---|---|
| `1`–`6` | Commit the prediction in that column |
| `Space` | Commit selected prediction + show next-word suggestions |
| `Return` | Commit current selection |
| `Escape` | Commit raw text and dismiss |

### Grid navigation

The candidate bar starts collapsed (one row). Press `↓` to expand into a multi-row grid.

| Key | Action |
|---|---|
| `↓` | Expand grid / move down |
| `↑` | Move up / collapse at top |
| `Tab` / `→` | Cycle column right |
| `←` | Cycle column left |

Number keys always target the **active row**.

---

## ⚙️ Settings

Open Settings from the menu bar icon.

| Pane | What it does |
|---|---|
| **General** | Toggle next-word suggestions on/off |
| **Keyboards** | Set up per-app input source switching — assign a keyboard layout to an app, and SwiftType switches automatically on focus |
| **Languages** | Add, remove, or reorder prediction languages. Pin a language or set to Auto (follows the system keyboard) |
| **Customization** | Adjust candidate bar appearance — 7 color options, opacity, column count (4–6), row count (3–5) |
| **About** | Shows the installed version |

Reset all settings: `defaults delete com.matthew.inputmethod.SwiftType`

---

## 🏗️ How It Works

### Prediction pipeline

```
Keystroke
 → SpellCheckPredictor (macOS spell checker → corrections + completions)
 → CandidateWindow (floating grid below cursor)

Word committed via Space
 → KenLMPredictor (n-gram model → top-N next words)
 → CandidateWindow (next-word mode, no literal slot)
```

**SpellCheckPredictor** wraps `NSSpellChecker` to produce spelling corrections, prefix completions, and fuzzy guesses — all synchronous, no network calls.

**KenLMPredictor** scores every word in its vocabulary against the recent typing context using a 5-gram language model, then applies truecasing to restore proper capitalization. The models are trained on 1 million news sentences from the [Leipzig Corpora Collection](https://wortschatz.uni-leipzig.de/en/download/).

### Truecasing

Language models work best on lowercase text, but predictions need proper capitalization — especially for German, where all nouns are capitalized. SwiftType solves this by training on lowercased text for optimal statistics, then applying a separate truecase map at prediction time (`"haus"` → `"Haus"`, `"germany"` → `"Germany"`).

### Architecture

```
macOS → IMKServer → InputController
                        ├── KeyHandler        — language-specific key dispatch
                        ├── InputStrategy     — prediction provider
                        │   ├── SpellCheckPredictor  (completions)
                        │   └── KenLMPredictor       (next-word, via C++ bridge)
                        ├── TypingRules       — language-specific character sets
                        └── CandidateWindow   — floating grid UI
```

All three extension points — `KeyHandler`, `InputStrategy`, and `TypingRules` — are protocols. Adding a new language means writing conformers and registering them in `LanguageDescriptor`, with no changes to the core input controller.

### Concurrency

The entire app is `@MainActor`-isolated under **Swift 6 strict concurrency** with zero warnings and zero `unsafe` annotations. InputMethodKit delivers all callbacks on the main thread, so rather than fighting that constraint, the codebase leans into it — proving thread safety to the compiler with no async/await and no background threads.

---

## 🧪 Tests

```bash
xcodebuild -scheme SwiftTypeTests -configuration Debug test
```

**1,005 tests** covering input state, grid navigation, key routing, spell-check predictions, KenLM predictions, theme system, settings persistence, typing rules, language management, and candidate window behavior.

---

## 📁 Project Structure

```
SwiftType/
├── App/            App delegate, managers, menu bar, input source switching
├── Input/          Input controller, key handling, state, strategies
├── Prediction/     SpellCheckPredictor, KenLMPredictor, Obj-C++ bridge
├── Rules/          TypingRules protocol, language descriptors, English/German
├── UI/             Candidate window, settings panes, theme system
├── Tests/          1,005 tests across all subsystems
├── Resources/      KenLM binary models + truecase maps (~164 MB)
├── Frameworks/     kenlm.xcframework (static C++ libs)
└── scripts/        KenLM model training, release packaging
```

---

## 📋 Building a Release

```bash
./scripts/release/release.sh          # auto-versioned (UTC timestamp)
./scripts/release/release.sh 1.2.0    # explicit version
```

Produces `dist/SwiftType-<version>.pkg` — a flat installer that copies the app to `~/Library/Input Methods/` and creates a `/Applications/SwiftType.app` symlink.

---

## 🔧 Troubleshooting

| Problem | Fix |
|---|---|
| SwiftType not in Input Sources | Rebuild to trigger auto-install, then check **System Settings → Keyboard** |
| Old binary after rebuild | `killall SwiftType; touch ~/Library/Input\ Methods/` — or log out and back in |
| Duplicate entries | `sudo rm -rf /Library/Input\ Methods/SwiftType.app` then re-login |
| Gatekeeper error | Right-click → Open, or run `xattr -dr com.apple.quarantine ~/Library/Input\ Methods/SwiftType.app` |
