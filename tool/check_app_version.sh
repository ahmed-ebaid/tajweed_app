#!/bin/bash
# Fails when pubspec.yaml, lib/core/constants/app_version.dart and the
# optional requested build name disagree, so a store build cannot ship with
# a stale version on the Settings screen.
set -euo pipefail
cd "$(dirname "$0")/.."
pubspec=$(sed -n 's/^version:[[:space:]]*\([^+]*\).*/\1/p' pubspec.yaml)
constant=$(sed -n "s/^const String appVersion = '\(.*\)';/\1/p" lib/core/constants/app_version.dart)
requested="${1:-$pubspec}"
if [ "$pubspec" != "$constant" ] || [ "$pubspec" != "$requested" ]; then
  echo "Version mismatch: pubspec.yaml=$pubspec app_version.dart=$constant requested=$requested" >&2
  exit 1
fi
