#!/usr/bin/env bash
# scripts/release/release.sh — Build SwiftType and package it into a
# distributable PKG installer.
#
# Usage:
#   ./scripts/release/release.sh [version]
#
# Produces:  dist/SwiftType-<version>.pkg
# Installs:  ~/Library/Input Methods/SwiftType.app  (no admin required)
#
# Requirements: Xcode command-line tools (xcodebuild, codesign, pkgbuild)
# No Apple Developer account needed — uses ad-hoc signing.

set -euo pipefail

# ── Configuration ─────────────────────────────────────────────────────────────
APP_NAME="SwiftType"
SCHEME="SwiftType"
VERSION="${1:-$(TZ=UTC0 date +"%Y.%m.%d.%H%M%S")}"  # Auto-generates UTC timestamp if no arg given
BUNDLE_ID="com.matthew.inputmethod.SwiftType"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
BUILD_DIR="${PROJECT_DIR}/build/Release"
DIST_DIR="${PROJECT_DIR}/dist"
PKG_ROOT="${PROJECT_DIR}/build/pkg_root"
PKG_SCRIPTS="${PROJECT_DIR}/build/pkg_scripts"
COMPONENT_PLIST="${PROJECT_DIR}/build/pkg_components.plist"
# Staging path on the install target — must match --install-location below.
# installd does not expose $INSTALL_DEST to scripts, so we hardcode this in both places.
STAGING_DIR="/private/tmp/swifttype_pkg_payload"
PKG_NAME="${APP_NAME}-${VERSION}.pkg"
PKG_OUT="${DIST_DIR}/${PKG_NAME}"
# ── Helpers ───────────────────────────────────────────────────────────────────
info()  { echo "  ▸ $*"; }
step()  { echo; echo "▶ $*"; }
die()   { echo "✗ ERROR: $*" >&2; exit 1; }

# ── Step 1: Sanity checks ─────────────────────────────────────────────────────
step "Checking tools"
for cmd in xcodebuild codesign pkgbuild; do
    command -v "$cmd" >/dev/null 2>&1 || die "'$cmd' not found. Install Xcode command-line tools."
done
info "All required tools found."

step "Checking kenlm.xcframework"
KENLM_XCFW="${PROJECT_DIR}/Frameworks/kenlm.xcframework"
[[ -d "$KENLM_XCFW" ]] || die "Frameworks/kenlm.xcframework not found. Run scripts/kenlm/fetch_kenlm.sh to build it."
info "Found: ${KENLM_XCFW}"

# ── Step 2: Clean old artifacts ───────────────────────────────────────────────
step "Cleaning previous build artifacts"
# A previous failed install may leave root-owned files; fix permissions first.
chmod -R u+w "${PROJECT_DIR}/build" 2>/dev/null || true
rm -rf "${PROJECT_DIR}/build" "${PKG_OUT}"
mkdir -p "${BUILD_DIR}" "${DIST_DIR}" "${PKG_ROOT}" "${PKG_SCRIPTS}"
info "Cleaned."

# ── Step 3: Build Release ─────────────────────────────────────────────────────
step "Building ${APP_NAME} (Release)"
# Use ad-hoc identity (-) so Xcode signs the app binary in one pass.
xcodebuild \
    -project "${PROJECT_DIR}/SwiftType.xcodeproj" \
    -scheme "${SCHEME}" \
    -configuration Release \
    -derivedDataPath "${PROJECT_DIR}/build/DerivedData" \
    CODE_SIGN_STYLE=Manual \
    CODE_SIGN_IDENTITY="-" \
    CONFIGURATION_BUILD_DIR="${BUILD_DIR}" \
    ONLY_ACTIVE_ARCH=NO \
    build \
    2>&1 | grep -E "(error:|warning:|BUILD)" | head -60 || true

# Confirm the .app was produced
APP_PATH="${BUILD_DIR}/${APP_NAME}.app"
[[ -d "${APP_PATH}" ]] || die ".app not found at ${APP_PATH}. Check xcodebuild output above."
info "Built: ${APP_PATH}"

# ── Step 4: Verify signing ────────────────────────────────────────────────────
step "Verifying signature"
codesign --verify --deep --strict "${APP_PATH}" && info "Signature verified." \
    || die "Signature verification failed."

# ── Step 5: Stage PKG payload ─────────────────────────────────────────────────
step "Staging PKG payload"
cp -R "${APP_PATH}" "${PKG_ROOT}/${APP_NAME}.app"
info "Staged."

# ── Step 6: Disable bundle relocation ────────────────────────────────────────
step "Configuring bundle options"
# pkgbuild records the original build path and will "relocate" the bundle to
# any matching path on the install target. Disabling relocation ensures the
# payload always lands at STAGING_DIR, where the postinstall expects it.
pkgbuild --analyze --root "${PKG_ROOT}" "${COMPONENT_PLIST}"
/usr/libexec/PlistBuddy -c "Set :0:BundleIsRelocatable false" "${COMPONENT_PLIST}"
info "Relocation disabled."

# ── Step 7: Write installer scripts ───────────────────────────────────────────
step "Writing installer scripts"

# preinstall — remove any stale user-level installation before the payload lands.
cat > "${PKG_SCRIPTS}/preinstall" <<'PREINSTALL'
#!/usr/bin/env bash
pkill -x SwiftType 2>/dev/null || true
# Remove system-level installation and caches (preinstall runs as root)
rm -rf "/Library/Input Methods/SwiftType.app"
rm -rf "/Library/Caches/com.matthew.inputmethod.SwiftType"
# Remove user-level installation and caches
LOGGED_IN_USER=$(stat -f %Su /dev/console 2>/dev/null || true)
if [[ -n "$LOGGED_IN_USER" && "$LOGGED_IN_USER" != "root" ]]; then
    USER_HOME=$(dscl . -read "/Users/${LOGGED_IN_USER}" NFSHomeDirectory 2>/dev/null \
                | awk 'NR==1{ print $NF }')
    if [[ -n "$USER_HOME" ]]; then
        rm -rf "${USER_HOME}/Library/Input Methods/SwiftType.app"
        rm -rf "${USER_HOME}/Library/Caches/com.matthew.inputmethod.SwiftType"
        rm -rf "${USER_HOME}/Library/Saved Application State/com.matthew.inputmethod.SwiftType.savedState"
    fi
fi
exit 0
PREINSTALL
chmod +x "${PKG_SCRIPTS}/preinstall"

# postinstall — copy from the staging area into the logged-in user's
# ~/Library/Input Methods/ and fix ownership.
# Note: installd does not set $INSTALL_DEST for component packages, so
# STAGING_DIR is hardcoded here to match --install-location in pkgbuild below.
cat > "${PKG_SCRIPTS}/postinstall" <<'POSTINSTALL'
#!/usr/bin/env bash
STAGING_DIR="/private/tmp/swifttype_pkg_payload"

LOGGED_IN_USER=$(stat -f %Su /dev/console 2>/dev/null || true)
if [[ -z "$LOGGED_IN_USER" || "$LOGGED_IN_USER" == "root" ]]; then
    echo "WARNING: No GUI user detected. SwiftType was not installed to ~/Library/Input Methods/." >&2
    exit 0
fi

USER_HOME=$(dscl . -read "/Users/${LOGGED_IN_USER}" NFSHomeDirectory 2>/dev/null \
            | awk 'NR==1{ print $NF }')
if [[ -z "$USER_HOME" || ! -d "$USER_HOME" ]]; then
    echo "ERROR: Cannot determine home directory for ${LOGGED_IN_USER}." >&2
    exit 1
fi

INPUT_METHODS_DIR="${USER_HOME}/Library/Input Methods"
DEST="${INPUT_METHODS_DIR}/SwiftType.app"

mkdir -p "${INPUT_METHODS_DIR}"
rm -rf "${DEST}"
cp -R "${STAGING_DIR}/SwiftType.app" "${DEST}"
chown -R "${LOGGED_IN_USER}:staff" "${DEST}"
rm -rf "${STAGING_DIR}"

echo "SwiftType installed to: ${DEST}"
POSTINSTALL
chmod +x "${PKG_SCRIPTS}/postinstall"

info "Scripts written."

# ── Step 8: Build PKG ─────────────────────────────────────────────────────────
step "Building PKG → ${PKG_NAME}"
pkgbuild \
    --root "${PKG_ROOT}" \
    --component-plist "${COMPONENT_PLIST}" \
    --scripts "${PKG_SCRIPTS}" \
    --identifier "${BUNDLE_ID}" \
    --version "${VERSION}" \
    --ownership recommended \
    --install-location "${STAGING_DIR}" \
    "${PKG_OUT}"

# ── Done ──────────────────────────────────────────────────────────────────────
echo
echo "✓ PKG ready: ${PKG_OUT}"
echo "  Size: $(du -sh "${PKG_OUT}" | cut -f1)"
echo
echo "Distribute ${PKG_NAME} to other Macs."
