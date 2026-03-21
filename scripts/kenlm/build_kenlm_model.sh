#!/usr/bin/env bash
# scripts/kenlm/build_kenlm_model.sh — Build a KenLM binary model from a
# Leipzig Corpora Collection archive or a pre-normalized text file.
#
# Accepts either:
#   - A .tar.gz archive from Leipzig (auto-extracts, cleans, and normalizes)
#   - A plain text corpus file (one sentence per line, already normalized)
#
# Automatically builds KenLM CLI tools and installs Python dependencies on
# first run if not already present.
#
# Corpus source:
#   Leipzig Corpora Collection: https://wortschatz.uni-leipzig.de/en/download/
#   Direct download URL pattern:
#     https://downloads.wortschatz-leipzig.de/corpora/{lang}_{source}_{year}_{size}.tar.gz
#
# Usage:
#   ./scripts/kenlm/build_kenlm_model.sh <language-code> <corpus-file-or-archive>
#   ./scripts/kenlm/build_kenlm_model.sh en eng_news_2025_300K.tar.gz
#   ./scripts/kenlm/build_kenlm_model.sh de ~/Downloads/deu_news_2025_300K.tar.gz
#
# Environment variables:
#   NGRAM_ORDER  n-gram order (default: 5)
#   PRUNE        pruning thresholds per order (default: '0 1 1 2 3')
#
# Produces: Resources/KenLM/<language-code>.binary

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
TOOLS_DIR="${PROJECT_DIR}/tools/kenlm"
OUTPUT_DIR="${PROJECT_DIR}/Resources/KenLM"
VENV_DIR="${PROJECT_DIR}/.venv"

NGRAM_ORDER="${NGRAM_ORDER:-5}"
PRUNE="${PRUNE:-0 1 1 2 3}"

info() { echo "  ▸ $*"; }
step() { echo; echo "▶ $*"; }
die()  { echo "✗ ERROR: $*" >&2; exit 1; }

# ── Argument parsing ──────────────────────────────────────────────────────────
if [[ $# -lt 2 ]]; then
    echo "Usage: $0 <language-code> <corpus-file-or-archive>"
    echo
    echo "Examples:"
    echo "  $0 en eng_news_2025_300K.tar.gz"
    echo "  $0 de ~/Downloads/deu_news_2025_300K.tar.gz"
    echo "  $0 en corpus/english.txt          # pre-normalized plain text"
    echo
    echo "Environment variables:"
    echo "  NGRAM_ORDER  n-gram order (default: 5)"
    echo "  PRUNE        pruning thresholds (default: '0 1 1 2 3')"
    exit 1
fi

LANG_CODE="$1"
SOURCE_FILE="$2"

[[ -f "$SOURCE_FILE" ]] || die "File not found: ${SOURCE_FILE}"

# ── Ensure KenLM CLI tools are available ──────────────────────────────────────
step "Checking tools"
if [[ -x "${TOOLS_DIR}/lmplz" && -x "${TOOLS_DIR}/build_binary" ]]; then
    export PATH="${TOOLS_DIR}:${PATH}"
    info "Using tools from tools/kenlm/"
elif command -v lmplz >/dev/null 2>&1 && command -v build_binary >/dev/null 2>&1; then
    info "Using lmplz and build_binary from PATH"
else
    info "CLI tools not found — building via build_kenlm_tools.sh..."
    "${SCRIPT_DIR}/build_kenlm_tools.sh"
    export PATH="${TOOLS_DIR}:${PATH}"
fi

# ── Ensure Python venv with clean-text is available ───────────────────────────
step "Checking Python environment"
if [[ -f "${VENV_DIR}/bin/python3" ]] && "${VENV_DIR}/bin/python3" -c "import ftfy" 2>/dev/null; then
    info "Using existing venv with ftfy"
else
    info "Setting up Python venv and installing ftfy..."
    python3 -m venv "${VENV_DIR}"
    "${VENV_DIR}/bin/pip" install --quiet ftfy
    info "Installed ftfy into .venv/"
fi
PYTHON="${VENV_DIR}/bin/python3"

# ── Prepare temp directory ────────────────────────────────────────────────────
TMP_DIR="$(mktemp -d)"
cleanup() { rm -rf "$TMP_DIR"; }
trap cleanup EXIT

# ── Extract and clean if tar.gz, otherwise use as-is ─────────────────────────
if [[ "$SOURCE_FILE" == *.tar.gz || "$SOURCE_FILE" == *.tgz ]]; then
    step "Extracting archive"
    tar xzf "$SOURCE_FILE" -C "$TMP_DIR"
    info "Extracted to: ${TMP_DIR}"

    # Find the sentences file
    SENTENCES_FILE=$(find "$TMP_DIR" -name '*-sentences.txt' -type f | head -1)
    [[ -n "$SENTENCES_FILE" ]] || die "No *-sentences.txt found in archive"
    info "Found: $(basename "$SENTENCES_FILE")"

    LINES=$(wc -l < "$SENTENCES_FILE" | tr -d ' ')
    info "Sentences: ${LINES}"

    step "Cleaning corpus for '${LANG_CODE}'"
    CORPUS_FILE="${TMP_DIR}/corpus.txt"
    TRUECASE_FILE="${OUTPUT_DIR}/${LANG_CODE}.truecase"

    cut -f2 "$SENTENCES_FILE" \
        | "$PYTHON" "${SCRIPT_DIR}/clean_corpus.py" --lang "$LANG_CODE" \
              --truecase-output "$TRUECASE_FILE" \
        > "$CORPUS_FILE"

    info "Output: $(wc -l < "$CORPUS_FILE" | tr -d ' ') sentences"
else
    CORPUS_FILE="$SOURCE_FILE"
    info "Using plain text corpus: ${CORPUS_FILE}"
fi

# ── Prepare output directory ──────────────────────────────────────────────────
mkdir -p "${OUTPUT_DIR}"

ARPA_FILE="${TMP_DIR}/${LANG_CODE}.arpa"
BINARY_FILE="${OUTPUT_DIR}/${LANG_CODE}.binary"

# ── Train ARPA model ─────────────────────────────────────────────────────────
step "Training ${NGRAM_ORDER}-gram ARPA model for '${LANG_CODE}'"
info "Corpus: ${CORPUS_FILE}"
info "Pruning: ${PRUNE}"

# shellcheck disable=SC2086
lmplz -o "${NGRAM_ORDER}" --prune ${PRUNE} < "${CORPUS_FILE}" > "${ARPA_FILE}"

ARPA_SIZE=$(du -sh "${ARPA_FILE}" | cut -f1)
info "ARPA model: ${ARPA_SIZE}"

# ── Binarize ──────────────────────────────────────────────────────────────────
step "Binarizing to probing format"
build_binary probing "${ARPA_FILE}" "${BINARY_FILE}"

BINARY_SIZE=$(du -sh "${BINARY_FILE}" | cut -f1)
info "Binary model: ${BINARY_SIZE}"

# ── Done ──────────────────────────────────────────────────────────────────────
echo
echo "✓ Model ready: ${BINARY_FILE} (${BINARY_SIZE})"
