#!/usr/bin/env bash
#
# dev-run.sh — fast local dev loop.
#
# Builds Shh (Debug), installs to /Applications, and RE-SIGNS with the stable
# self-signed "Shh Dev" certificate. The re-sign is the important bit: a plain
# ad-hoc signature changes on every build, so macOS treats each build as a new
# binary and forgets the Accessibility / Input Monitoring grants. Signing with
# a stable certificate keeps the code's "designated requirement" constant, so
# TCC permissions survive rebuilds — grant once, never again.
#
# One-time setup (already done once on this machine):
#   - A self-signed code-signing cert named "Shh Dev" exists in the login
#     keychain (created via openssl + `security import`).
#
# If the cert is missing, see scripts/make-dev-cert.sh.

set -euo pipefail

SIGN_IDENTITY="Shh Dev"
APP_NAME="Shh"
DERIVED_DATA="/tmp/Shh-build"
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

cd "${PROJECT_DIR}"

echo "==> xcodegen generate"
xcodegen generate >/dev/null

echo "==> stop running instance"
pkill -f "${APP_NAME}.app" 2>/dev/null || true
sleep 0.3

echo "==> xcodebuild Debug"
xcodebuild \
  -project "${APP_NAME}.xcodeproj" \
  -scheme "${APP_NAME}" \
  -configuration Debug \
  -derivedDataPath "${DERIVED_DATA}" \
  build 2>&1 | grep -E "(error:|BUILD)" || true

BUILT="${DERIVED_DATA}/Build/Products/Debug/${APP_NAME}.app"
if [[ ! -d "${BUILT}" ]]; then
  echo "Build failed — no app at ${BUILT}" >&2
  exit 1
fi

echo "==> install to /Applications"
rm -rf "/Applications/${APP_NAME}.app"
cp -R "${BUILT}" "/Applications/${APP_NAME}.app"

echo "==> re-sign with stable '${SIGN_IDENTITY}' cert (keeps TCC grants)"
codesign --force --deep --sign "${SIGN_IDENTITY}" "/Applications/${APP_NAME}.app"

echo "==> launch"
open "/Applications/${APP_NAME}.app"
echo "Done."
