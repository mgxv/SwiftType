#!/usr/bin/env bash
# scripts/kenlm/build_kenlm_tools.sh — Build KenLM CLI tools (lmplz,
# build_binary) from source and install them to tools/kenlm/.
#
# These tools are needed for training new language models.  They are .gitignored
# and cached locally — subsequent runs skip the build if the tools already exist.
# Pass --force to rebuild.
#
# Prerequisites: git, cmake, boost (brew install cmake boost)
#
# Usage:
#   ./scripts/kenlm/build_kenlm_tools.sh           # build if missing
#   ./scripts/kenlm/build_kenlm_tools.sh --force   # rebuild unconditionally

set -euo pipefail

KENLM_REPO="https://github.com/kpu/kenlm.git"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
TOOLS_DIR="${PROJECT_DIR}/tools/kenlm"

info() { echo "  ▸ $*"; }
step() { echo; echo "▶ $*"; }
die()  { echo "✗ ERROR: $*" >&2; exit 1; }

# ── Check if already built ────────────────────────────────────────────────────
FORCE=false
[[ "${1:-}" == "--force" ]] && FORCE=true

if [[ "$FORCE" == "false" && -x "${TOOLS_DIR}/lmplz" && -x "${TOOLS_DIR}/build_binary" ]]; then
    info "CLI tools already exist at tools/kenlm/ (use --force to rebuild)"
    exit 0
fi

# ── Sanity checks ─────────────────────────────────────────────────────────────
step "Checking prerequisites"
command -v git   >/dev/null 2>&1 || die "git not found"
command -v cmake >/dev/null 2>&1 || die "cmake not found — install via 'brew install cmake'"
brew --prefix boost >/dev/null 2>&1 || die "Boost not found — install via 'brew install boost'"
info "OK"

# ── Clone ─────────────────────────────────────────────────────────────────────
TMP_DIR="$(mktemp -d)"
cleanup() { rm -rf "$TMP_DIR"; }
trap cleanup EXIT

step "Cloning KenLM"
KENLM_SRC="${TMP_DIR}/kenlm"
git clone --depth 1 "${KENLM_REPO}" "${KENLM_SRC}" 2>&1
info "Cloned to: ${KENLM_SRC}"

# ── Patch CMakeLists ──────────────────────────────────────────────────────────
# Boost 1.69+ made boost_system header-only; KenLM's CMakeLists still asks for
# it as a compiled component.  Remove it, keep thread and program_options.
step "Patching CMakeLists.txt for modern Boost"
sed -i '' '/find_package(Boost.*REQUIRED COMPONENTS/,/)/c\
find_package(Boost 1.69.0 REQUIRED COMPONENTS\
  program_options\
  thread\
)' "${KENLM_SRC}/CMakeLists.txt"
info "OK"

# ── Build ─────────────────────────────────────────────────────────────────────
step "Building lmplz and build_binary"
BUILD_DIR="${TMP_DIR}/build"

cmake -S "${KENLM_SRC}" -B "${BUILD_DIR}" \
    -DCMAKE_BUILD_TYPE=Release \
    -DKENLM_MAX_ORDER=6 \
    -DCMAKE_CXX_FLAGS="-D_LIBCPP_ENABLE_CXX17_REMOVED_UNARY_BINARY_FUNCTION" \
    -DBoost_NO_BOOST_CMAKE=ON \
    -DBOOST_ROOT="$(brew --prefix boost)" \
    2>&1 | tail -3

cmake --build "${BUILD_DIR}" --config Release \
    -j "$(sysctl -n hw.ncpu)" -- lmplz build_binary 2>&1 | tail -5

# ── Install ───────────────────────────────────────────────────────────────────
step "Installing to tools/kenlm/"
mkdir -p "${TOOLS_DIR}"
cp "${BUILD_DIR}/bin/lmplz"        "${TOOLS_DIR}/lmplz"
cp "${BUILD_DIR}/bin/build_binary" "${TOOLS_DIR}/build_binary"
info "lmplz → ${TOOLS_DIR}/lmplz"
info "build_binary → ${TOOLS_DIR}/build_binary"

echo
echo "✓ CLI tools ready at tools/kenlm/"
