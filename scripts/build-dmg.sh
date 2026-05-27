#!/usr/bin/env bash
#
# build-dmg.sh — Release-build Shh and wrap it in a drag-to-Applications DMG.
#
# Without a paid Apple Developer ID the resulting .app is only ad-hoc signed:
# Gatekeeper will warn on first launch. The user can right-click → Open to
# bypass once, after which it's trusted on that machine. For a real
# distribution you'd plug in `codesign --sign "Developer ID Application: …"`
# and `xcrun notarytool submit …` in the marked steps below.
#

set -euo pipefail

APP_NAME="Shh"
DISPLAY_NAME="Shh"     # plain ASCII for filenames; CFBundleDisplayName ("Shh…") still applies inside the app

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DERIVED_DATA="${PROJECT_DIR}/build/DerivedData"
STAGING_DIR="${PROJECT_DIR}/build/dmg-staging"
DMG_PATH="${PROJECT_DIR}/build/${DISPLAY_NAME}.dmg"

cd "${PROJECT_DIR}"

# ---------- 1. Regenerate the Xcode project from project.yml ----------
echo "==> [1/4] xcodegen generate"
xcodegen generate

# ---------- 2. Release build ----------
echo "==> [2/4] xcodebuild Release"
xcodebuild \
  -project "${APP_NAME}.xcodeproj" \
  -scheme "${APP_NAME}" \
  -configuration Release \
  -derivedDataPath "${DERIVED_DATA}" \
  build \
  | tail -8

APP_BUILT="${DERIVED_DATA}/Build/Products/Release/${APP_NAME}.app"
if [[ ! -d "${APP_BUILT}" ]]; then
  echo "Build did not produce ${APP_BUILT}" >&2
  exit 1
fi

# ---------- (optional) 2.5 — Developer ID signing ----------
# Uncomment and fill in once you have an Apple Developer account:
# codesign --force --deep --options runtime \
#   --sign "Developer ID Application: Your Name (TEAMID)" \
#   "${APP_BUILT}"
# (Then run `xcrun notarytool submit` and `stapler staple` against the DMG.)

# ---------- 3. Stage the DMG contents ----------
echo "==> [3/4] Staging DMG layout"
rm -rf "${STAGING_DIR}" "${DMG_PATH}"
mkdir -p "${STAGING_DIR}"
cp -R "${APP_BUILT}" "${STAGING_DIR}/${APP_NAME}.app"
ln -s /Applications "${STAGING_DIR}/Applications"

# ---------- 4. Build the DMG ----------
echo "==> [4/4] hdiutil create"
mkdir -p "$(dirname "${DMG_PATH}")"
hdiutil create \
  -volname "${APP_NAME}" \
  -srcfolder "${STAGING_DIR}" \
  -ov \
  -format UDZO \
  "${DMG_PATH}" \
  | tail -3

# Clean up the staging directory; keep the DMG.
rm -rf "${STAGING_DIR}"

echo ""
echo "Done. DMG written to: ${DMG_PATH}"
echo "Open it with:  open \"${DMG_PATH}\""
