#!/usr/bin/env bash
#
# Captures the six localized onboarding screenshots for every supported locale
# and installs them into assets/onboarding/<locale>/.
#
# This exists because the capture used to be a manual, undocumented process:
# screenshots were taken by hand, resized by hand, and copied by hand into the
# asset folders. That last step is how 03-listen-ayah.png and
# 04-bookmark-ayah.png ended up byte-identical in all eight locales and shipped
# that way. Everything here is therefore scripted end to end.
#
# Two details that are easy to get wrong and are the reason this file exists:
#
#   * The bundled assets are 414x900. No simulator has a 414pt-wide screen, and
#     the harness does not force a size. The number comes from capturing on an
#     iPhone 17 (1206x2622 native) and downscaling to width 414, which lands
#     the height on 900.06 -> 900. That resize is applied below.
#
#   * The integration test emits final asset filenames directly
#     (onboarding-NN-*.png), so installing is a rename-free copy. Do not
#     reintroduce a manual mapping step here.
#
# Usage:
#   tool/capture_onboarding_assets.sh                 # all locales
#   tool/capture_onboarding_assets.sh en ar           # a subset
#
# Environment:
#   SIMULATOR_UDID   Simulator to drive. Defaults to a booted iPhone 17.
#   SKIP_INSTALL=1   Capture and resize only; leave assets/onboarding untouched.

set -euo pipefail

readonly REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly ALL_LOCALES=(en ar ur tr fr id de es)
readonly TARGET_WIDTH=414
readonly EXPECTED_HEIGHT=900
readonly ASSET_NAMES=(
  onboarding-01-tajweed-rules.png
  onboarding-02-tafseer.png
  onboarding-03-listen-ayah.png
  onboarding-04-bookmark-ayah.png
  onboarding-05-hizb-boundary.png
  onboarding-06-mushaf-bookmark.png
)

cd "$REPO_ROOT"

locales=("$@")
if [[ ${#locales[@]} -eq 0 ]]; then
  locales=("${ALL_LOCALES[@]}")
fi

resolve_simulator() {
  if [[ -n "${SIMULATOR_UDID:-}" ]]; then
    echo "$SIMULATOR_UDID"
    return
  fi

  local udid
  udid="$(xcrun simctl list devices booted \
    | grep -m1 -oE '[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}' || true)"

  if [[ -z "$udid" ]]; then
    echo "No booted simulator found. Boot an iPhone 17 (or set SIMULATOR_UDID)." >&2
    echo "  xcrun simctl boot 'iPhone 17'" >&2
    exit 1
  fi

  echo "$udid"
}

readonly SIMULATOR="$(resolve_simulator)"
echo "==> Simulator: $SIMULATOR"

failed_locales=()

for locale in "${locales[@]}"; do
  echo
  echo "==> Capturing '$locale'"

  out_dir="build/onboarding-capture/$locale"
  rm -rf "$out_dir"
  mkdir -p "$out_dir"

  if ! SCREENSHOT_OUTPUT_DIR="$out_dir" flutter drive \
    --driver=test_driver/app_store_screenshots_driver.dart \
    --target=integration_test/app_store_screenshots_test.dart \
    -d "$SIMULATOR" \
    --dart-define=ONBOARDING_ASSETS_ONLY=true \
    --dart-define="SCREENSHOT_LOCALE=$locale" \
    > "$out_dir/capture.log" 2>&1; then
    echo "    capture FAILED (see $out_dir/capture.log)" >&2
    failed_locales+=("$locale")
    continue
  fi

  # The harness asserts its way through each screen, so a missing file means a
  # screen silently changed shape. Fail loudly rather than shipping five images.
  missing=()
  for name in "${ASSET_NAMES[@]}"; do
    [[ -f "$out_dir/$name" ]] || missing+=("$name")
  done
  if [[ ${#missing[@]} -gt 0 ]]; then
    echo "    missing: ${missing[*]}" >&2
    failed_locales+=("$locale")
    continue
  fi

  for name in "${ASSET_NAMES[@]}"; do
    sips --resampleWidth "$TARGET_WIDTH" "$out_dir/$name" --out "$out_dir/$name" > /dev/null
    height="$(sips -g pixelHeight "$out_dir/$name" | awk '/pixelHeight/ {print $2}')"
    if [[ "$height" != "$EXPECTED_HEIGHT" ]]; then
      echo "    $name resized to ${TARGET_WIDTH}x${height}, expected ${EXPECTED_HEIGHT}." >&2
      echo "    Capture device is probably not an iPhone 17-class screen." >&2
      failed_locales+=("$locale")
      continue 2
    fi
  done

  # Duplicate images are the exact defect this rework exists to fix, so refuse
  # to install a set that contains any.
  duplicates="$(cd "$out_dir" && md5 -q "${ASSET_NAMES[@]}" | sort | uniq -d)"
  if [[ -n "$duplicates" ]]; then
    echo "    identical images captured — not installing '$locale'." >&2
    failed_locales+=("$locale")
    continue
  fi

  if [[ "${SKIP_INSTALL:-0}" == "1" ]]; then
    echo "    captured (install skipped)"
    continue
  fi

  dest="assets/onboarding/$locale"
  mkdir -p "$dest"
  for name in "${ASSET_NAMES[@]}"; do
    cp "$out_dir/$name" "$dest/${name#onboarding-}"
  done
  echo "    installed -> $dest"
done

echo
if [[ ${#failed_locales[@]} -gt 0 ]]; then
  echo "FAILED: ${failed_locales[*]}" >&2
  exit 1
fi

echo "All locales captured successfully."
echo "Now run: flutter test test/unit/onboarding_assets_test.dart"
