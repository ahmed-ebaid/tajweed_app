#!/usr/bin/env bash
set -euo pipefail

readonly REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly EXPECTED_PROJECT_NUMBER="312770688680"
readonly BUILD_TARGET="${1:-appbundle}"

if [[ "$BUILD_TARGET" != "appbundle" && "$BUILD_TARGET" != "apk" ]]; then
  echo "Usage: PLAY_INTEGRITY_CLOUD_PROJECT_NUMBER=$EXPECTED_PROJECT_NUMBER \"$0\" [appbundle|apk]" >&2
  exit 2
fi

if [[ -z "${PLAY_INTEGRITY_CLOUD_PROJECT_NUMBER:-}" ]]; then
  echo "PLAY_INTEGRITY_CLOUD_PROJECT_NUMBER is required for every Android build." >&2
  exit 2
fi
if [[ ! "$PLAY_INTEGRITY_CLOUD_PROJECT_NUMBER" =~ ^[1-9][0-9]*$ ]]; then
  echo "PLAY_INTEGRITY_CLOUD_PROJECT_NUMBER must be a positive integer." >&2
  exit 2
fi
if [[ "$PLAY_INTEGRITY_CLOUD_PROJECT_NUMBER" != "$EXPECTED_PROJECT_NUMBER" ]]; then
  echo "Unexpected Play Integrity project number; expected $EXPECTED_PROJECT_NUMBER." >&2
  exit 2
fi

if [[
  "$BUILD_TARGET" == "appbundle" &&
  ! -f "$REPO_ROOT/android/key.properties" &&
  ! -f "$HOME/.config/tajweed/key.properties"
]]; then
  echo "Release app bundles require the upload signing configuration (key.properties)." >&2
  exit 2
fi

cd "$REPO_ROOT"
flutter build "$BUILD_TARGET" --release \
  "--dart-define=PLAY_INTEGRITY_CLOUD_PROJECT_NUMBER=$PLAY_INTEGRITY_CLOUD_PROJECT_NUMBER"
