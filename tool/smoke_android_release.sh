#!/usr/bin/env bash
set -euo pipefail

readonly PACKAGE_NAME="com.ebaidllc.tajweed_practice"
readonly APK="${1:-build/app/outputs/flutter-apk/app-release.apk}"
readonly SERIAL="${ANDROID_SERIAL:-}"
readonly TIMEOUT_SECONDS="${QURAN_SMOKE_TIMEOUT_SECONDS:-180}"
ADB="${ADB:-adb}"

if [[ ! -f "$APK" ]]; then
  echo "Release APK not found: $APK" >&2
  exit 2
fi
if ! "$ADB" get-state >/dev/null 2>&1; then
  echo "No authorized Android device found. Set ANDROID_SERIAL if more than one is connected." >&2
  exit 2
fi
if [[ -n "$SERIAL" ]]; then
  ADB=("$ADB" -s "$SERIAL")
else
  ADB=("$ADB")
fi

# -r preserves app data and refuses a signing-certificate mismatch rather than
# uninstalling the Play-installed app and risking user data.
"${ADB[@]}" install -r "$APK"
"${ADB[@]}" logcat -c
"${ADB[@]}" shell monkey -p "$PACKAGE_NAME" 1 >/dev/null

echo "Open the Quran reader on the device. Waiting for visible Arabic Quran text..."
readonly DEADLINE=$((SECONDS + TIMEOUT_SECONDS))
while (( SECONDS < DEADLINE )); do
  if "${ADB[@]}" shell uiautomator dump /sdcard/quran-smoke-window.xml >/dev/null 2>&1; then
    if "${ADB[@]}" shell cat /sdcard/quran-smoke-window.xml 2>/dev/null | \
      python3 -c 'import re,sys; sys.exit(0 if re.search(r"[\u0600-\u06ff]", sys.stdin.read()) else 1)'; then
      if "${ADB[@]}" logcat -d -s flutter:I '*:S' | \
        grep -Eq 'This build is missing PLAY_INTEGRITY_CLOUD_PROJECT_NUMBER|Quran text validation failed|Unable to load Mushaf page'; then
        echo "Smoke test failed: Quran loading errors were logged." >&2
        "${ADB[@]}" logcat -d -s flutter:I '*:S' | \
          grep -E 'This build is missing PLAY_INTEGRITY_CLOUD_PROJECT_NUMBER|Quran text validation failed|Unable to load Mushaf page' >&2 || true
        exit 1
      fi
      echo "Smoke test passed: Arabic text is visible and no Quran load failure was logged."
      exit 0
    fi
  fi
  sleep 5
done

echo "Smoke test timed out without finding visible Arabic text in the device UI." >&2
"${ADB[@]}" logcat -d -s flutter:I '*:S' | \
  grep -E 'This build is missing PLAY_INTEGRITY_CLOUD_PROJECT_NUMBER|Quran text validation failed|Unable to load Mushaf page' >&2 || true
exit 1
