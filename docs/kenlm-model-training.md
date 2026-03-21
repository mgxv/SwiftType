# KenLM Model Training Guide

How to train and update the n-gram language models used for next-word prediction in SwiftType.

---

## Quick start

```bash
# Download a corpus from Leipzig, then:
./scripts/kenlm/build_kenlm_model.sh en eng_news_2025_1M.tar.gz
./scripts/kenlm/build_kenlm_model.sh de deu_news_2025_1M.tar.gz
```

That's it. The script handles everything: builds CLI tools if missing, sets up a Python venv with `ftfy`, extracts the archive, cleans the corpus, trains the model, generates a truecase map, and outputs `Resources/KenLM/{code}.binary` + `{code}.truecase`.

---

## Corpus Source

All training corpora are downloaded from the **Leipzig Corpora Collection**:

- **Website:** https://wortschatz.uni-leipzig.de/en/download/
- **Direct downloads:** https://downloads.wortschatz-leipzig.de/corpora/

Leipzig provides consistently formatted, plain-text sentence corpora for 290+ languages. Each corpus contains randomly selected sentences from news, Wikipedia, or web sources, available in standard sizes (10K, 30K, 100K, 300K, 1M sentences).

### Download URL pattern

```
https://downloads.wortschatz-leipzig.de/corpora/{lang}_{source}_{year}_{size}.tar.gz
```

### Current models

| Language | Corpus file | Sentences | Model size | Truecase entries |
|---|---|---|---|---|
| English (`en`) | `eng_news_2025_1M` | 1,000,000 | ~82 MB | 132K (~2 MB) |
| German (`de`) | `deu_news_2025_1M` | 1,000,000 | ~71 MB | 368K (~9 MB) |

---

## Prerequisites

The build script automatically installs KenLM CLI tools and Python dependencies on first run. You only need:

```bash
brew install cmake boost
```

The tools (`lmplz`, `build_binary`) are built to `tools/kenlm/` (gitignored) and cached for subsequent runs. A Python venv with `ftfy` is created at `.venv/` (gitignored). To force a rebuild:

```bash
./scripts/kenlm/build_kenlm_tools.sh --force
```

---

## Scripts

All KenLM scripts live in `scripts/kenlm/`:

| Script | Purpose |
|---|---|
| `fetch_kenlm.sh` | Builds KenLM query libraries → `Frameworks/kenlm.xcframework` (committed to repo) |
| `build_kenlm_tools.sh` | Builds CLI tools (`lmplz`, `build_binary`) → `tools/kenlm/` (gitignored) |
| `build_kenlm_model.sh` | End-to-end model training from a `.tar.gz` archive or plain text corpus |
| `clean_corpus.py` | Corpus cleaning and truecase extraction (called by `build_kenlm_model.sh`) |

---

## Training a model

### From a Leipzig archive (recommended)

```bash
./scripts/kenlm/build_kenlm_model.sh en eng_news_2025_1M.tar.gz
```

The script:
1. Extracts the `.tar.gz` and finds the `*-sentences.txt` file
2. Cleans the corpus via `clean_corpus.py` (see Corpus Cleaning below)
3. Trains a 5-gram ARPA model via `lmplz -o 5 --prune 0 1 1 2 3`
4. Binarizes to probing format via `build_binary probing`
5. Outputs `Resources/KenLM/{code}.binary` and `{code}.truecase`

### From a pre-normalized text file

```bash
./scripts/kenlm/build_kenlm_model.sh en corpus/english.txt
```

The file should contain one lowercased sentence per line with only letters, apostrophes, and spaces. No truecase map is generated in this mode.

### Verify

```bash
xcodebuild -scheme SwiftType -configuration Debug build
```

The `Resources/KenLM/` folder is a folder reference in Xcode — new `.binary` and `.truecase` files are automatically included in the app bundle.

---

## Corpus cleaning

`clean_corpus.py` is a Python pipeline using `ftfy` for Unicode repair. It processes Leipzig archives before training:

1. **Unicode repair** — fixes mojibake, bad encoding, control chars, HTML entities (via `ftfy`)
2. **Pre-lowercase checks** — rejects ALL-CAPS headlines (>40% caps words) and proper-noun-heavy sentences (>50% titled words)
3. **Noise stripping** — removes URLs, emails, hashtags, @-mentions, ordinal numbers (`1st`, `2nd`), standalone numbers
4. **Lowercase and script filter** — keeps only target-language letters and apostrophes
5. **Apostrophe cleanup** — removes orphaned fragments (`'s`, `'t`, `'re`)
6. **Word filtering** — removes junk 1-letter and 2-letter words via comprehensive language-specific allowlists (sourced from Scrabble dictionaries: CSW24, ODS9, Duden, RAE, Porto Editora, Zingarelli)
7. **Validation** — sentence length (3–50 words), mean word length (2–10), max word length (25), alpha ratio (≥60%), gibberish detection (repeated chars/patterns), duplicate word ratio (<50% unique), deduplication
8. **Truecase extraction** — from accepted sentences only, collects cased word frequencies (skipping sentence-initial words), writes `{code}.truecase` with the most common cased form for each word

### Cleaning stats (1M sentence corpora)

| Language | Input | Filtered | Duplicates | Output |
|---|---|---|---|---|
| English | 1,000,000 | 14,179 (1.4%) | 5,639 | 980,182 |
| German | 1,000,000 | 39,445 (3.9%) | 1,084 | 959,471 |

---

## Truecasing

The model is trained on **lowercase** text for optimal n-gram statistics — this concentrates counts instead of splitting them across cased variants (e.g., "visited germany" gets all 100 occurrences instead of splitting between "visited Germany" and "visited germany").

A separate **truecase map** (`{code}.truecase`) restores correct capitalisation at prediction time:

- `germany` → `Germany`, `monday` → `Monday`, `christmas` → `Christmas`
- `haus` → `Haus`, `arbeit` → `Arbeit`, `zeit` → `Zeit` (German nouns)
- `the`, `and`, `is` → stay lowercase (not in the map)

This is the industry-standard approach used by Google Gboard and Moses SMT.

### How it works

1. During corpus cleaning, before lowercasing, word casing frequencies are collected from non-initial positions (sentence-initial words are always capitalised regardless of word type)
2. For each lowercase word, the most frequent cased form is selected
3. Only words where the best form differs from lowercase are written to the map
4. Only words that appear in the final cleaned corpus are included
5. `KenLMBridge.mm` loads the truecase map alongside the model and applies it to every prediction

### German noun capitalisation

German capitalises ALL nouns, not just proper nouns. A lowercase model would return `"haus"` instead of `"Haus"`. The truecase map handles this automatically — because nouns appear capitalised in the vast majority of non-sentence-initial positions in properly-written German text, the frequency-based truecase correctly restores noun capitalisation. This is why the German truecase map (368K entries) is much larger than English (132K entries).

---

## Adding a new language

1. **Download** a corpus from Leipzig (recommended: `{lang}_news_{year}_1M`)

2. **Add character set** to `EXTRA_CHARS` in `clean_corpus.py` if the language uses non-ASCII letters. Currently supported:

   | Language | Extra characters |
   |---|---|
   | German (`de`) | `äöüß` |
   | French (`fr`) | `àâæçéèêëïîôœùûüÿ` |
   | Spanish (`es`) | `áéíóúüñ` |
   | Portuguese (`pt`) | `àáâãçéêíóôõú` |
   | Italian (`it`) | `àèéìíîòóùú` |

3. **Add word allowlists** to `VALID_1` and `VALID_2` in `clean_corpus.py` for the language's valid 1-letter and 2-letter words.

4. **Train:** `./scripts/kenlm/build_kenlm_model.sh {code} {corpus}.tar.gz`

5. **Add the language** to SwiftType: create a `*TypingRules` conformer, add a `LanguageDescriptor.all` entry, and optionally a `*KeyHandler`.

---

## Training parameters

| Parameter | Default | Rationale |
|---|---|---|
| N-gram order | 5 | Good prediction quality; higher orders add little value at corpus sizes ≤1M |
| Pruning | `0 1 1 2 3` | Keep all unigrams; prune rare higher-order n-grams |
| Binary format | `probing` | Required by `lm::ngram::Model` (typedef for `ProbingModel`) in KenLMBridge.mm |
| Corpus size | 1M sentences | ~71–82 MB models; good balance of prediction quality and model size |

Override defaults via environment variables:

```bash
NGRAM_ORDER=3 PRUNE="0 1 2" ./scripts/kenlm/build_kenlm_model.sh en eng_news_2025_1M.tar.gz
```

---

## Model format

**Important:** The binary format must be `probing` (the default for `build_binary`). Do **not** use `trie` — `KenLMBridge.mm` loads models via `lm::ngram::Model` which is a typedef for `ProbingModel`. Loading a trie-format binary into `ProbingModel` will throw an exception and silently fail (the model won't load, predictions return empty).

---

## Vocabulary filtering

`KenLMBridge.mm` filters vocabulary at model load time via `VocabCollector::Add`:

- KenLM special tokens (`<s>`, `</s>`, `<unk>`) — excluded
- Empty words — excluded
- Words not starting with a letter — excluded (filters punctuation, numbers, contraction fragments like `'s`, `'t`, `'re`)
- UTF-8 multi-byte leading bytes (>= 0xC0) are treated as letters (preserves words starting with ä, ö, ü, etc.)
