#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/build_common.sh"

init_build "$@"
log_info "Building macOS release package for version ${VERSION}"

if [[ "$(host_os)" != "macos" ]]; then
  log_error "macOS packages can only be built on macOS"
  exit 1
fi

require_flutter
require_command zip
ensure_release_dir

MACOS_APP_NAME="OronBox"

DART_DEFINES=()
while IFS= read -r define; do
  DART_DEFINES+=("${define}")
done < <(flutter_release_defines)

run_cmd flutter build macos \
  --release \
  --obfuscate \
  --split-debug-info=symbols/macos \
  "${DART_DEFINES[@]}"

APP_BUNDLE="${PROJECT_ROOT}/build/macos/Build/Products/Release/${MACOS_APP_NAME}.app"
if [[ ! -d "${APP_BUNDLE}" ]]; then
  log_error "macOS app bundle not found: ${APP_BUNDLE}"
  exit 1
fi

archive_zip "${APP_BUNDLE}" "${RELEASE_DIR}/${APP_NAME}-${VERSION}-macos-universal.zip"
archive_symbols_if_present \
  "${PROJECT_ROOT}/symbols/macos" \
  "${RELEASE_DIR}/${APP_NAME}-${VERSION}-macos-universal.symbols.tar.gz"

if command -v hdiutil >/dev/null 2>&1; then
  DMG_DST="${RELEASE_DIR}/${APP_NAME}-${VERSION}-macos-universal.dmg"
  DMG_WORK_DIR="$(mktemp -d "${PROJECT_ROOT}/build/macos/dmg.XXXXXX")"
  DMG_STAGE="${DMG_WORK_DIR}/stage"
  DMG_BUILD="${DMG_WORK_DIR}/$(basename "${DMG_DST}")"
  close_dmg_finder_windows() {
    command -v osascript >/dev/null 2>&1 || return 0
    osascript >/dev/null 2>&1 <<'APPLESCRIPT' || true
tell application "Finder"
  repeat with finderWindow in every Finder window
    try
      set targetName to name of (target of finderWindow)
      if targetName starts with "dmg." then close finderWindow
    end try
  end repeat
end tell
APPLESCRIPT
  }
  cleanup_dmg() {
    close_dmg_finder_windows
    rm -rf "${DMG_WORK_DIR}"
  }
  trap cleanup_dmg EXIT
  mkdir -p "${DMG_STAGE}"
  ditto "${APP_BUNDLE}" "${DMG_STAGE}/${MACOS_APP_NAME}.app"
  rm -f "${DMG_DST}"

  if command -v create-dmg >/dev/null 2>&1; then
    # Do not set a background picture or color. Finder then uses its native
    # appearance-aware background while retaining the native app/folder icons.
    # Keep both icons on the same horizontal row with a smaller top margin.
    DMG_ICON_Y=160
    run_cmd create-dmg \
      --volname "OronBox" \
      --volicon "${APP_BUNDLE}/Contents/Resources/AppIcon.icns" \
      --window-pos 180 100 \
      --window-size 720 400 \
      --icon-size 128 \
      --icon "${MACOS_APP_NAME}.app" 160 "${DMG_ICON_Y}" \
      --hide-extension "${MACOS_APP_NAME}.app" \
      --app-drop-link 560 "${DMG_ICON_Y}" \
      --text-size 14 \
      --no-internet-enable \
      --overwrite \
      "${DMG_BUILD}" \
      "${DMG_STAGE}"
  else
    log_warn "create-dmg not found; using the basic DMG layout"
    ln -s /Applications "${DMG_STAGE}/Applications"
    run_cmd hdiutil create \
      -volname "OronBox" \
      -srcfolder "${DMG_STAGE}" \
      -ov \
      -format UDZO \
      "${DMG_BUILD}"
  fi

  mv -f "${DMG_BUILD}" "${DMG_DST}"
  cleanup_dmg
  trap - EXIT
  log_info "Produced ${DMG_DST}"
else
  log_warn "hdiutil not found; skipped DMG package"
fi

log_info "macOS build complete"
