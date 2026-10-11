#!/usr/bin/env bash
#
# Installs the latest MacExplorer release into /Applications.
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/StanDarius24/MacExplorer/main/scripts/install.sh | bash
#
# This downloads the newest GitHub Release asset for StanDarius24/MacExplorer,
# verifies its SHA-256 checksum, unpacks it, moves MacExplorer.app into
# /Applications, clears the macOS Gatekeeper quarantine flag (the release
# build is ad-hoc signed only — there is no Apple Developer ID / notarization
# configured for this project), and launches the app.
set -euo pipefail

REPO="StanDarius24/MacExplorer"
APP_NAME="MacExplorer.app"
INSTALL_DIR="/Applications"

log() { printf '==> %s\n' "$1"; }
die() { printf 'error: %s\n' "$1" >&2; exit 1; }

command -v curl >/dev/null 2>&1 || die "curl is required but not installed."
command -v ditto >/dev/null 2>&1 || die "ditto is required but not installed (macOS only)."

if [[ "$(uname -s)" != "Darwin" ]]; then
  die "MacExplorer is a macOS app; this script must be run on macOS."
fi

WORK_DIR="$(mktemp -d)"
trap 'rm -rf "${WORK_DIR}"' EXIT

log "Looking up latest release for ${REPO}..."
RELEASE_JSON="${WORK_DIR}/release.json"

# Prefer the dedicated "latest release" endpoint (only returns non-draft,
# non-prerelease releases). If that 404s — e.g. because every release so
# far was created by a manual workflow run and happened to be flagged as a
# prerelease — fall back to the full releases list. The list is sorted
# newest-first, and since the asset-URL extraction below just takes the
# first match in the raw JSON text, feeding it the full array still
# correctly resolves to the newest release's assets without needing to
# parse out a single object.
LATEST_URL="https://api.github.com/repos/${REPO}/releases/latest"
HTTP_STATUS=$(curl -sSL -o "${RELEASE_JSON}" -w '%{http_code}' "${LATEST_URL}")

if [[ "${HTTP_STATUS}" != "200" ]]; then
  log "No non-prerelease release found (HTTP ${HTTP_STATUS}); checking full release list..."
  ALL_RELEASES_URL="https://api.github.com/repos/${REPO}/releases"
  HTTP_STATUS=$(curl -sSL -o "${RELEASE_JSON}" -w '%{http_code}' "${ALL_RELEASES_URL}")
  if [[ "${HTTP_STATUS}" != "200" ]]; then
    die "Failed to query GitHub releases API for ${REPO} (HTTP ${HTTP_STATUS}). Check your network connection and that a release exists."
  fi
fi

ZIP_URL=$(grep -o '"browser_download_url": *"[^"]*\.zip"' "${RELEASE_JSON}" | sed -E 's/.*"(https[^"]+)"/\1/' | head -n 1)
SHA_URL=$(grep -o '"browser_download_url": *"[^"]*\.zip\.sha256"' "${RELEASE_JSON}" | sed -E 's/.*"(https[^"]+)"/\1/' | head -n 1)

[[ -n "${ZIP_URL}" ]] || die "Could not find a .zip asset on the latest release."

TAG=$(grep -o '"tag_name": *"[^"]*"' "${RELEASE_JSON}" | sed -E 's/.*"tag_name": *"([^"]*)"/\1/' | head -n 1)
log "Latest release: ${TAG:-unknown}"

ZIP_PATH="${WORK_DIR}/MacExplorer.zip"
log "Downloading ${ZIP_URL}..."
curl -fsSL "${ZIP_URL}" -o "${ZIP_PATH}" || die "Failed to download release archive."

if [[ -n "${SHA_URL}" ]]; then
  log "Verifying checksum..."
  EXPECTED_SHA=$(curl -fsSL "${SHA_URL}" | awk '{print $1}')
  ACTUAL_SHA=$(shasum -a 256 "${ZIP_PATH}" | awk '{print $1}')
  if [[ "${EXPECTED_SHA}" != "${ACTUAL_SHA}" ]]; then
    die "Checksum mismatch! expected=${EXPECTED_SHA} actual=${ACTUAL_SHA}. Aborting install."
  fi
  log "Checksum verified."
else
  log "No checksum asset found; skipping verification."
fi

log "Unpacking archive..."
EXTRACT_DIR="${WORK_DIR}/extracted"
mkdir -p "${EXTRACT_DIR}"
ditto -x -k "${ZIP_PATH}" "${EXTRACT_DIR}"

SOURCE_APP=$(find "${EXTRACT_DIR}" -maxdepth 2 -name "${APP_NAME}" -type d | head -n 1)
[[ -n "${SOURCE_APP}" ]] || die "Could not find ${APP_NAME} inside the downloaded archive."

DEST_APP="${INSTALL_DIR}/${APP_NAME}"

if [[ -w "${INSTALL_DIR}" ]]; then
  SUDO=""
else
  log "No write access to ${INSTALL_DIR}; will use sudo (you may be prompted for your password)."
  SUDO="sudo"
fi

if [[ -d "${DEST_APP}" ]]; then
  log "Removing previous installation at ${DEST_APP}..."
  ${SUDO} rm -rf "${DEST_APP}"
fi

log "Installing ${APP_NAME} to ${INSTALL_DIR}..."
${SUDO} cp -R "${SOURCE_APP}" "${INSTALL_DIR}/"

log "Clearing Gatekeeper quarantine flag..."
${SUDO} xattr -cr "${DEST_APP}" || true

log "Re-applying ad-hoc signature (defensive, in case of resigning issues)..."
${SUDO} codesign --force --deep --sign - "${DEST_APP}" || true

log "Launching ${APP_NAME}..."
open "${DEST_APP}"

log "Done. MacExplorer is installed at ${DEST_APP}."
