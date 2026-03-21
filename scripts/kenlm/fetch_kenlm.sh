#!/usr/bin/env bash
# scripts/kenlm/fetch_kenlm.sh — Build KenLM core query libraries from source
# and package them as a static XCFramework at Frameworks/kenlm.xcframework.
#
# Only builds the core n-gram query libraries (lm/ and util/) needed by the app
# at runtime.  For the CLI training tools (lmplz, build_binary), see
# build_kenlm_tools.sh.
#
# Run once after cloning the repo, and again when upgrading KenLM.
# The resulting XCFramework is committed to the repo so no internet access
# is needed on the build machine.
#
# Prerequisites: git, cmake, xcodebuild
#
# Usage:
#   ./scripts/kenlm/fetch_kenlm.sh

set -euo pipefail

KENLM_REPO="https://github.com/kpu/kenlm.git"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
FRAMEWORKS_DIR="${PROJECT_DIR}/Frameworks"
OUTPUT_XCFW="${FRAMEWORKS_DIR}/kenlm.xcframework"
TMP_DIR="$(mktemp -d)"

info() { echo "  ▸ $*"; }
step() { echo; echo "▶ $*"; }
die()  { echo "✗ ERROR: $*" >&2; exit 1; }

cleanup() { rm -rf "$TMP_DIR"; }
trap cleanup EXIT

# ── Sanity checks ─────────────────────────────────────────────────────────────
step "Checking tools"
command -v git        >/dev/null 2>&1 || die "git not found"
command -v cmake      >/dev/null 2>&1 || die "cmake not found — install via 'brew install cmake'"
command -v xcodebuild >/dev/null 2>&1 || die "xcodebuild not found"
info "OK"

# ── Clone ─────────────────────────────────────────────────────────────────────
step "Cloning KenLM"
KENLM_SRC="${TMP_DIR}/kenlm"
git clone --depth 1 "${KENLM_REPO}" "${KENLM_SRC}" 2>&1
info "Cloned to: ${KENLM_SRC}"

# ── Write a minimal CMakeLists that builds only the core libraries ────────────
# The upstream CMakeLists.txt requires Boost for the CLI tools.  We only need
# the lm/ and util/ static libraries for n-gram queries, so we write our own
# minimal build that compiles exactly those sources with no external dependencies.
step "Writing library-only CMakeLists.txt"
cat > "${TMP_DIR}/CMakeLists.txt" <<'CMAKE'
cmake_minimum_required(VERSION 3.21)
project(kenlm_core CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

set(KENLM_MAX_ORDER 6 CACHE STRING "Maximum n-gram order")

set(KENLM_SRC "${CMAKE_CURRENT_SOURCE_DIR}/kenlm")

# ── kenlm_util ───────────────────────────────────────────────────────────────
file(GLOB UTIL_SRCS
    "${KENLM_SRC}/util/*.cc"
    "${KENLM_SRC}/util/double-conversion/*.cc"
)
# Exclude test and main files
list(FILTER UTIL_SRCS EXCLUDE REGEX "_(test|main)\\.cc$")
list(FILTER UTIL_SRCS EXCLUDE REGEX "test_utils\\.cc$")

add_library(kenlm_util STATIC ${UTIL_SRCS})
target_include_directories(kenlm_util PUBLIC "${KENLM_SRC}")
target_compile_definitions(kenlm_util PUBLIC
    KENLM_MAX_ORDER=${KENLM_MAX_ORDER}
    HAVE_ZLIB
    # Restore std::binary_function removed in C++17 (used by KenLM's sorted iterators)
    _LIBCPP_ENABLE_CXX17_REMOVED_UNARY_BINARY_FUNCTION
)
target_link_libraries(kenlm_util PUBLIC z)

# ── kenlm (core n-gram library) ─────────────────────────────────────────────
file(GLOB LM_SRCS "${KENLM_SRC}/lm/*.cc")
list(FILTER LM_SRCS EXCLUDE REGEX "_(test|main)\\.cc$")
list(FILTER LM_SRCS EXCLUDE REGEX "test_utils\\.cc$")
# Exclude the builder directory — that requires Boost
list(FILTER LM_SRCS EXCLUDE REGEX "/lm/builder")
# Filter out any files that depend on builder/
file(GLOB BUILDER_SRCS "${KENLM_SRC}/lm/builder/*.cc")
list(FILTER BUILDER_SRCS EXCLUDE REGEX "_(test|main)\\.cc$")

add_library(kenlm STATIC ${LM_SRCS})
target_include_directories(kenlm PUBLIC "${KENLM_SRC}")
target_compile_definitions(kenlm PUBLIC KENLM_MAX_ORDER=${KENLM_MAX_ORDER})
target_link_libraries(kenlm PUBLIC kenlm_util)

# ── Install ──────────────────────────────────────────────────────────────────
install(TARGETS kenlm kenlm_util
    ARCHIVE DESTINATION lib
)

# Install headers preserving directory structure
install(DIRECTORY "${KENLM_SRC}/lm/"
    DESTINATION include/lm
    FILES_MATCHING PATTERN "*.hh" PATTERN "*.h"
    PATTERN "builder" EXCLUDE
)
install(DIRECTORY "${KENLM_SRC}/util/"
    DESTINATION include/util
    FILES_MATCHING PATTERN "*.hh" PATTERN "*.h"
)
CMAKE
info "Written minimal CMakeLists.txt"

# ── Build function ────────────────────────────────────────────────────────────
build_arch() {
    local ARCH="$1"
    local BUILD_DIR="${TMP_DIR}/build-${ARCH}"
    local INSTALL_DIR="${TMP_DIR}/install-${ARCH}"

    step "Building KenLM for ${ARCH}"
    mkdir -p "${BUILD_DIR}"

    local SDK_PATH
    SDK_PATH="$(xcrun --sdk macosx --show-sdk-path)"

    cmake -S "${TMP_DIR}" -B "${BUILD_DIR}" \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_OSX_ARCHITECTURES="${ARCH}" \
        -DCMAKE_OSX_DEPLOYMENT_TARGET=13.0 \
        -DCMAKE_OSX_SYSROOT="${SDK_PATH}" \
        -DCMAKE_INSTALL_PREFIX="${INSTALL_DIR}" \
        -DKENLM_MAX_ORDER=6 \
        2>&1 | tail -5

    cmake --build "${BUILD_DIR}" --config Release -j "$(sysctl -n hw.ncpu)" 2>&1 | tail -5
    cmake --install "${BUILD_DIR}" 2>&1 | tail -3

    info "Installed ${ARCH} to: ${INSTALL_DIR}"
}

# ── Build both architectures ──────────────────────────────────────────────────
build_arch "arm64"
build_arch "x86_64"

# ── Create universal static libraries ────────────────────────────────────────
step "Creating universal static libraries"
UNIVERSAL_DIR="${TMP_DIR}/universal"
UNIVERSAL_LIB_DIR="${UNIVERSAL_DIR}/lib"
mkdir -p "${UNIVERSAL_LIB_DIR}"

ARM64_LIB="${TMP_DIR}/install-arm64/lib"
X86_LIB="${TMP_DIR}/install-x86_64/lib"

for LIB_NAME in libkenlm.a libkenlm_util.a; do
    if [[ -f "${ARM64_LIB}/${LIB_NAME}" && -f "${X86_LIB}/${LIB_NAME}" ]]; then
        lipo -create \
            "${ARM64_LIB}/${LIB_NAME}" \
            "${X86_LIB}/${LIB_NAME}" \
            -output "${UNIVERSAL_LIB_DIR}/${LIB_NAME}"
        info "Created universal ${LIB_NAME}"
    else
        die "${LIB_NAME} not found in both architectures"
    fi
done

# Copy headers from either architecture (they're identical)
HEADERS_DIR="${TMP_DIR}/install-arm64/include"
[[ -d "${HEADERS_DIR}" ]] || die "Headers directory not found: ${HEADERS_DIR}"
cp -R "${HEADERS_DIR}" "${UNIVERSAL_DIR}/include"

# ── Verify architectures ─────────────────────────────────────────────────────
step "Verifying architectures"
ARCHS=$(lipo -archs "${UNIVERSAL_LIB_DIR}/libkenlm.a")
echo "$ARCHS" | grep -q "arm64"  || die "arm64 slice missing from libkenlm.a"
echo "$ARCHS" | grep -q "x86_64" || die "x86_64 slice missing from libkenlm.a"
info "Architectures: ${ARCHS}"

# ── Build XCFramework ─────────────────────────────────────────────────────────
step "Building XCFramework"
mkdir -p "${FRAMEWORKS_DIR}"
rm -rf "${OUTPUT_XCFW}"

xcodebuild -create-xcframework \
    -library "${UNIVERSAL_LIB_DIR}/libkenlm.a" \
    -headers "${UNIVERSAL_DIR}/include" \
    -output  "${OUTPUT_XCFW}"

# Copy libkenlm_util.a into the xcframework alongside libkenlm.a
XCFW_LIB_DIR=$(find "${OUTPUT_XCFW}" -name "libkenlm.a" -exec dirname {} \;)
[[ -n "$XCFW_LIB_DIR" ]] || die "Could not find libkenlm.a inside xcframework"
cp "${UNIVERSAL_LIB_DIR}/libkenlm_util.a" "${XCFW_LIB_DIR}/"
info "Copied libkenlm_util.a into xcframework"

info "Written to: ${OUTPUT_XCFW}"

echo
echo "✓ Frameworks/kenlm.xcframework is ready (${ARCHS})"
echo "  Commit Frameworks/ to the repo so no download is needed at build time."
