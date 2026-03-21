#!/usr/bin/env python3
"""Clean a Leipzig corpus for KenLM model training.

Reads sentences from stdin (one per line), cleans and filters them, and writes
one cleaned sentence per line to stdout.  Stats are printed to stderr.

Pipeline:
  1. Unicode repair (ftfy)
  2. Pre-lowercase checks (ALL-CAPS, proper noun ratio)
  3. Strip URLs, emails, hashtags, mentions, ordinals, numbers
  4. Lowercase and script-filter to target language alphabet
  5. Clean up apostrophe artifacts and collapse whitespace
  6. Filter junk words (single-letter, 2-letter allowlists)
  7. Validate (length, mean/max word length, alpha ratio, gibberish,
     duplicate words, deduplication)

Dependencies: ftfy (pip install ftfy)

Usage:
  cut -f2 sentences.txt | python3 clean_corpus.py --lang en > cleaned.txt
  cut -f2 sentences.txt | python3 clean_corpus.py --lang de
"""

from __future__ import annotations

import argparse
import re
import sys
from typing import Pattern

import ftfy

# ═══════════════════════════════════════════════════════════════════════════════
# Regex patterns
# ═══════════════════════════════════════════════════════════════════════════════

# Matches: "https://example.com", "http://foo.bar/path?q=1", "www.test.org", "ftp://files.host"
RE_URL: Pattern[str] = re.compile(
    r"https?://\S+|www\.\S+|ftp://\S+",
    re.IGNORECASE,
)

# Matches: "user@example.com", "first.last+tag@sub.domain.org"
RE_EMAIL: Pattern[str] = re.compile(
    r"[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}",
)

# Matches: "#breaking", "#COVID19", "@reuters", "@user_name"
RE_HASHTAG_MENTION: Pattern[str] = re.compile(r"[#@]\w+")

# Matches: "1st", "2nd", "3rd", "4th", "21st", "100th"
RE_ORDINAL: Pattern[str] = re.compile(r"\b\d+(st|nd|rd|th)\b", re.IGNORECASE)

# Matches: "42", "3.14", "1,000", "2,500.99"
RE_NUMBER: Pattern[str] = re.compile(r"\b\d[\d,.]*\b")

# Matches: "  " (multiple spaces), "\t\n" (mixed whitespace)
RE_WHITESPACE: Pattern[str] = re.compile(r"\s+")

# Matches words with 3+ identical consecutive chars: "aaaa", "oooo", "!!!"
RE_CHAR_REPEAT: Pattern[str] = re.compile(r"(.)\1{2,}")

# Matches whole words that are a repeated 1-3 char pattern: "hahaha", "lolol", "nanana"
RE_PATTERN_REPEAT: Pattern[str] = re.compile(r"^(.{1,3})\1{2,}$")

# Matches orphaned apostrophe fragments after contraction splitting:
# " 's ", " 't ", " 're ", standalone " ' "
RE_ORPHAN_APOS: Pattern[str] = re.compile(r"(?:^|\s)'[a-z]{0,2}(?:\s|$)")

# ═══════════════════════════════════════════════════════════════════════════════
# Language data
# ═══════════════════════════════════════════════════════════════════════════════

EXTRA_CHARS: dict[str, str] = {
    "de": "äöüß",
    "fr": "àâæçéèêëïîôœùûüÿ",
    "es": "áéíóúüñ",
    "pt": "àáâãçéêíóôõú",
    "it": "àèéìíîòóùú",
}

VALID_1: dict[str, set[str]] = {
    "en": {"a", "i"},
    "de": set(),
    "fr": {"a", "à", "y"},
    "es": {"a", "e", "o", "u", "y"},
    "pt": {"a", "e", "o"},
    "it": {"a", "e", "i", "o"},
}

# Comprehensive 2-letter word lists from Scrabble dictionaries (CSW24/SOWPODS,
# ODS9, Duden, RAE, Porto Editora, Zingarelli) plus accented/umlauted forms.
VALID_2: dict[str, set[str]] = {
    "en": {
        "aa", "ab", "ad", "ae", "ag", "ah", "ai", "al", "am", "an", "ar",
        "as", "at", "aw", "ax", "ay", "ba", "be", "bi", "bo", "by", "ch",
        "da", "de", "di", "do", "ea", "ed", "ee", "ef", "eh", "el", "em",
        "en", "er", "es", "et", "ew", "ex", "fa", "fe", "fy", "gi", "go",
        "gu", "ha", "he", "hi", "hm", "ho", "id", "if", "in", "io", "is",
        "it", "ja", "jo", "ka", "ki", "ko", "ky", "la", "li", "lo", "ma",
        "me", "mi", "mm", "mo", "mu", "my", "na", "ne", "no", "nu", "ny",
        "ob", "od", "oe", "of", "oh", "oi", "ok", "om", "on", "oo", "op",
        "or", "os", "ou", "ow", "ox", "oy", "pa", "pe", "pi", "po", "qi",
        "re", "sh", "si", "so", "st", "ta", "te", "ti", "to", "ug", "uh",
        "um", "un", "up", "ur", "us", "ut", "we", "wo", "xi", "xu", "ya",
        "ye", "yo", "yu", "za", "ze", "zo",
    },
    "de": {
        "aa", "ab", "ad", "ag", "ah", "am", "an", "ar", "as", "at", "au",
        "aw", "ax", "ay", "ba", "be", "bi", "bo", "by", "da", "de", "do",
        "du", "ed", "ef", "eh", "ei", "el", "em", "en", "er", "es", "et",
        "ex", "ey", "fa", "fe", "go", "ha", "he", "hi", "hm", "ho", "hu",
        "id", "if", "im", "in", "is", "it", "ix", "ja", "je", "jo", "ka",
        "ki", "la", "li", "lo", "ma", "me", "mi", "mm", "mo", "mu", "my",
        "na", "ne", "no", "nu", "ny", "ob", "od", "oe", "of", "oh", "oi",
        "om", "on", "op", "or", "os", "ow", "ox", "oy", "pa", "pe", "pi",
        "po", "qi", "re", "sh", "si", "so", "st", "ta", "ti", "to", "tu",
        "ud", "uh", "ui", "ul", "um", "un", "up", "ur", "us", "ut", "uz",
        "we", "wo", "xi", "xu", "ya", "ye", "yo", "za", "zu",
        # Umlauted forms
        "äh", "äs", "bö", "hä", "hü", "nö", "öd", "öl", "sä", "tö", "üb",
    },
    "fr": {
        "aa", "ah", "ai", "an", "as", "au", "ay", "ba", "be", "bi", "bu",
        "ca", "ce", "ci", "da", "de", "do", "du", "eh", "en", "es", "et",
        "eu", "ex", "fa", "fi", "go", "ha", "he", "hi", "ho", "if", "il",
        "in", "je", "ka", "la", "le", "li", "lu", "ma", "me", "mi", "mu",
        "na", "ne", "ni", "no", "nu", "oc", "oh", "om", "on", "or", "os",
        "ou", "pi", "pu", "qi", "ra", "re", "ri", "ru", "sa", "se", "si",
        "su", "ta", "te", "to", "tu", "ud", "un", "us", "ut", "va", "ve",
        "vs", "vu", "wu", "xi",
    },
    "es": {
        "ah", "al", "as", "ay", "be", "ca", "ce", "ch", "co", "cu", "da",
        "de", "di", "do", "ea", "eh", "el", "en", "es", "ex", "fe", "fi",
        "ge", "ha", "he", "id", "ir", "ja", "ji", "jo", "ka", "la", "le",
        "li", "lo", "me", "mi", "mu", "na", "ni", "no", "nu", "oh", "os",
        "pa", "pe", "pi", "po", "re", "ro", "se", "si", "so", "su", "ta",
        "te", "ti", "to", "tu", "uh", "un", "uy", "va", "ve", "vi", "xi",
        "ya", "ye", "yo", "za",
    },
    "pt": {
        "aa", "ah", "ai", "al", "ao", "ar", "as", "az", "ca", "co", "cu",
        "da", "de", "do", "eh", "el", "em", "eu", "fa", "fe", "fi", "fu",
        "ha", "id", "ih", "in", "io", "ir", "ja", "la", "li", "ma", "me",
        "mi", "na", "ni", "no", "nu", "oc", "oh", "oi", "ok", "os", "ou",
        "pa", "pe", "pi", "po", "pu", "ra", "re", "ri", "se", "si", "so",
        "ta", "te", "ti", "to", "tu", "uf", "uh", "ui", "um", "ut", "va",
        "ve", "vi", "xa", "xi",
        # Accented forms
        "bê", "cê", "dó", "fá", "fé", "fó", "gê", "já", "jê", "lã", "lê",
        "ló", "má", "mó", "nê", "nó", "pá", "pé", "pó", "rã", "ré", "ró",
        "sã", "só", "tá", "tê", "tó", "vê", "vó", "xá", "xô", "zê",
    },
    "it": {
        "ad", "ah", "ai", "al", "ba", "be", "bi", "ca", "ce", "ci", "co",
        "da", "de", "di", "do", "ed", "eh", "fa", "fe", "fi", "fu", "gi",
        "go", "ha", "he", "hi", "ho", "id", "il", "in", "io", "la", "le",
        "li", "lo", "ma", "me", "mi", "mo", "mu", "na", "ne", "ni", "no",
        "nu", "oh", "oi", "or", "pa", "pe", "pi", "po", "re", "ri", "sa",
        "se", "si", "so", "su", "ta", "te", "ti", "to", "tu", "uh", "un",
        "va", "ve", "vi", "vo", "za",
    },
}

# Pre-compile the script-filter regex per language (called once per lang).
_script_filter_cache: dict[str, Pattern[str]] = {}


def _script_filter(lang: str) -> Pattern[str]:
    """Return a compiled regex that strips characters outside the target alphabet."""
    if lang not in _script_filter_cache:
        extra = re.escape(EXTRA_CHARS.get(lang, ""))
        _script_filter_cache[lang] = re.compile(rf"[^a-z{extra}' ]")
    return _script_filter_cache[lang]


# ═══════════════════════════════════════════════════════════════════════════════
# Pre-lowercase checks (run on original text before any transformation)
# ═══════════════════════════════════════════════════════════════════════════════

def is_mostly_caps(text: str, threshold: float = 0.4) -> bool:
    """True if too many words are ALL-CAPS (headline detection)."""
    words = text.split()
    if len(words) < 3:
        return False
    caps = sum(1 for w in words if w.isupper() and len(w) > 1)
    return caps / len(words) > threshold


def has_high_proper_noun_ratio(text: str, threshold: float = 0.5) -> bool:
    """True if too many words look like proper nouns (name-heavy sentences)."""
    words = text.split()
    if len(words) < 4:
        return False
    # Skip first word — always capitalised at sentence start.
    rest = words[1:]
    titled = sum(1 for w in rest if len(w) > 1 and w[0].isupper())
    return titled / len(rest) > threshold


# ═══════════════════════════════════════════════════════════════════════════════
# Cleaning
# ═══════════════════════════════════════════════════════════════════════════════

def _strip_noise(text: str) -> str:
    """Fix encoding and remove structured noise (URLs, emails, etc.)."""
    text = ftfy.fix_text(text)
    text = RE_URL.sub(" ", text)
    text = RE_EMAIL.sub(" ", text)
    text = RE_HASHTAG_MENTION.sub(" ", text)
    text = RE_ORDINAL.sub(" ", text)
    text = RE_NUMBER.sub(" ", text)
    return text


def extract_cased_words(text: str, lang: str) -> list[str]:
    """Extract words with original casing after stripping noise.

    Called before lowercasing so we can build a truecase table.  Applies the
    same script filter as ``clean_line`` but without lowercasing first, so
    that the casing is preserved.
    """
    text = _strip_noise(text)
    extra = EXTRA_CHARS.get(lang, "")
    # Keep upper + lower target-language letters, apostrophe, and space.
    text = re.sub(rf"[^a-zA-Z{re.escape(extra)}{re.escape(extra.upper())}' ]", " ", text)
    return RE_WHITESPACE.sub(" ", text).strip().split()


def clean_line(text: str, lang: str) -> str:
    """Transform a raw sentence into a normalised, lowercase, script-filtered string."""
    text = _strip_noise(text)

    # Lowercase.
    text = text.lower()

    # Keep only target-language letters, apostrophe, and space.
    text = _script_filter(lang).sub(" ", text)

    # Remove orphaned apostrophe fragments ('s, 't, 're, bare ').
    text = RE_ORPHAN_APOS.sub(" ", text)
    text = text.replace("'", " ") if text.strip() == "'" else text

    # Collapse whitespace.
    text = RE_WHITESPACE.sub(" ", text).strip()

    return text


# ═══════════════════════════════════════════════════════════════════════════════
# Word filtering
# ═══════════════════════════════════════════════════════════════════════════════

def filter_words(words: list[str], lang: str) -> list[str]:
    """Drop single-letter and 2-letter words not in the language's allowlist."""
    v1 = VALID_1.get(lang, VALID_1["en"])
    v2 = VALID_2.get(lang, VALID_2["en"])
    return [
        w for w in words
        if len(w) > 2
        or (len(w) == 2 and w in v2)
        or (len(w) == 1 and w in v1)
    ]


# ═══════════════════════════════════════════════════════════════════════════════
# Validation
# ═══════════════════════════════════════════════════════════════════════════════

def is_valid(
    words: list[str],
    *,
    min_words: int,
    max_words: int,
    min_alpha_ratio: float,
) -> bool:
    """Return True if the cleaned sentence is worth keeping."""
    n = len(words)

    # ── Sentence length ───────────────────────────────────────────────────
    if n < min_words or n > max_words:
        return False

    # ── Word-level checks ─────────────────────────────────────────────────
    total_chars = 0
    alpha_count = 0
    for w in words:
        wlen = len(w)
        total_chars += wlen

        # Max word length (URL residue, concatenated junk).
        if wlen > 25:
            return False

        # Gibberish (per-word repeated chars or patterns).
        if RE_CHAR_REPEAT.search(w) or RE_PATTERN_REPEAT.match(w):
            return False

        if w.isalpha():
            alpha_count += 1

    # ── Mean word length ────────────────────────────────────────────────
    # Lower bound of 2 allows short-word-heavy but valid sentences
    # ("he said oh my go do it up"). Upper bound of 10 catches technical junk.
    mean_len = total_chars / n
    if mean_len < 2 or mean_len > 10:
        return False

    # ── Alpha ratio ───────────────────────────────────────────────────────
    if alpha_count / n < min_alpha_ratio:
        return False

    # ── Duplicate-word ratio (lists, repetitive content) ──────────────────
    if n >= 5 and len(set(words)) / n < 0.5:
        return False

    return True


# ═══════════════════════════════════════════════════════════════════════════════
# Main
# ═══════════════════════════════════════════════════════════════════════════════

def main() -> None:
    parser = argparse.ArgumentParser(
        description="Clean a corpus for KenLM model training.",
    )
    parser.add_argument(
        "--lang", required=True,
        help="BCP-47 language code (en, de, fr, es, pt, it)",
    )
    parser.add_argument(
        "--min-words", type=int, default=3,
        help="Minimum words per sentence (default: 3)",
    )
    parser.add_argument(
        "--max-words", type=int, default=50,
        help="Maximum words per sentence (default: 50)",
    )
    parser.add_argument(
        "--min-alpha-ratio", type=float, default=0.6,
        help="Minimum ratio of alphabetic tokens (default: 0.6)",
    )
    parser.add_argument(
        "--truecase-output", type=str, default=None,
        help="Path to write truecase mapping file (TSV: lowercase → truecased)",
    )
    args = parser.parse_args()

    seen: set[str] = set()
    n_input: int = 0
    n_output: int = 0
    n_filtered: int = 0
    n_dedup: int = 0

    build_truecase: bool = args.truecase_output is not None

    # Truecase frequency table: lowercase_word → {CasedForm: count, ...}
    # Only populated from sentences that pass all filters.
    truecase_counts: dict[str, dict[str, int]] = {}
    # Track which lowercase words appear in the final output corpus.
    output_vocab: set[str] = set()

    for raw in sys.stdin:
        n_input += 1
        raw = raw.strip()
        if not raw:
            continue

        # Pre-lowercase checks on original text.
        if is_mostly_caps(raw) or has_high_proper_noun_ratio(raw):
            n_filtered += 1
            continue

        # Extract cased words before lowercasing (needed for truecase).
        # Done before clean_line so we have the original casing.
        cased_words: list[str] | None = None
        if build_truecase:
            cased_words = extract_cased_words(raw, args.lang)

        # Clean.
        text: str = clean_line(raw, args.lang)
        if not text:
            n_filtered += 1
            continue

        # Filter junk short words.
        words: list[str] = filter_words(text.split(), args.lang)
        text = " ".join(words)
        if not text:
            n_filtered += 1
            continue

        # Validate.
        if not is_valid(
            words,
            min_words=args.min_words,
            max_words=args.max_words,
            min_alpha_ratio=args.min_alpha_ratio,
        ):
            n_filtered += 1
            continue

        # Deduplicate.
        if text in seen:
            n_dedup += 1
            continue
        seen.add(text)

        # Collect truecase data AFTER validation — only from accepted sentences.
        # Skip the first word (always capitalised at sentence start).
        if build_truecase and cased_words is not None:
            for i, cw in enumerate(cased_words):
                if i == 0:
                    continue
                # Only collect pure alphabetic words (no apostrophes, quotes, etc.)
                if not cw.isalpha():
                    continue
                lw: str = cw.lower()
                if lw not in truecase_counts:
                    truecase_counts[lw] = {}
                truecase_counts[lw][cw] = truecase_counts[lw].get(cw, 0) + 1

            # Track output vocabulary.
            output_vocab.update(words)

        sys.stdout.write(text)
        sys.stdout.write("\n")
        n_output += 1

    # Write truecase mapping file.
    if build_truecase:
        n_truecased: int = 0
        with open(args.truecase_output, "w", encoding="utf-8") as f:  # type: ignore[arg-type]
            for lw in sorted(truecase_counts):
                # Only include words that appear in the output corpus.
                if lw not in output_vocab:
                    continue
                # Only include pure alphabetic keys.
                if not lw.isalpha():
                    continue
                forms: dict[str, int] = truecase_counts[lw]
                best: str = max(forms, key=forms.get)  # type: ignore[arg-type]
                # Only write if the best form differs from lowercase.
                if best != lw:
                    f.write(f"{lw}\t{best}\n")
                    n_truecased += 1
        print(
            f"  ▸ Truecase: {n_truecased} entries written",
            file=sys.stderr,
        )

    print(
        f"  ▸ Cleaning: {n_input} input → {n_output} output "
        f"({n_filtered} filtered, {n_dedup} duplicates)",
        file=sys.stderr,
    )


if __name__ == "__main__":
    main()
