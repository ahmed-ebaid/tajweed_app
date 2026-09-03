#!/usr/bin/env bash
#
# Sets the four Worker secrets that Play Integrity verification needs.
#
# Until all four exist, the Android attestation route returns 503 (see the
# guard in src/attestation.ts). This script derives the signing-certificate
# digest from a keystore and pulls the service-account credentials out of the
# JSON key file, so the values always match what Google actually reports.
#
# Usage:
#   ./scripts/setup-play-integrity.sh \
#     --service-account ~/Downloads/play-integrity-sa.json \
#     [--keystore ~/.android/debug.keystore] \
#     [--alias androiddebugkey] \
#     [--storepass android] \
#     [--env prelive|production] \
#     [--package com.ebaidllc.tajweed_practice] \
#     [--dry-run]
#
# Defaults target the Android debug keystore and the prelive Worker, which is
# the combination that lets a sideloaded build pass on a real device.

set -euo pipefail

PACKAGE="com.ebaidllc.tajweed_practice"
KEYSTORE="${HOME}/.android/debug.keystore"
ALIAS="androiddebugkey"
STOREPASS="android"
TARGET_ENV="prelive"
SERVICE_ACCOUNT=""
DRY_RUN=0

die() { echo "error: $*" >&2; exit 1; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --service-account) SERVICE_ACCOUNT="${2:-}"; shift 2 ;;
    --keystore)        KEYSTORE="${2:-}";        shift 2 ;;
    --alias)           ALIAS="${2:-}";           shift 2 ;;
    --storepass)       STOREPASS="${2:-}";       shift 2 ;;
    --env)             TARGET_ENV="${2:-}";      shift 2 ;;
    --package)         PACKAGE="${2:-}";         shift 2 ;;
    --dry-run)         DRY_RUN=1;                shift   ;;
    -h|--help)         sed -n '2,22p' "$0"; exit 0 ;;
    *) die "unknown argument: $1" ;;
  esac
done

[[ -n "$SERVICE_ACCOUNT" ]] || die "--service-account is required"
[[ -f "$SERVICE_ACCOUNT" ]] || die "service account file not found: $SERVICE_ACCOUNT"
[[ -f "$KEYSTORE" ]]        || die "keystore not found: $KEYSTORE"

case "$TARGET_ENV" in
  prelive)    WRANGLER_ENV=(--env "") ;;
  production) WRANGLER_ENV=(--env production) ;;
  *) die "--env must be 'prelive' or 'production'" ;;
esac

for tool in keytool openssl node npx; do
  command -v "$tool" >/dev/null 2>&1 || die "$tool is required but not on PATH"
done

# Play Integrity reports the digest as base64url of the SHA-256 over the DER
# certificate, with padding stripped. Anything else silently fails to match.
#
# The export is checked on its own rather than piped straight into openssl: a
# failed keytool would otherwise feed empty input forward and yield the digest
# of the empty string, which is a valid-looking but completely wrong secret.
CERT_DER="$(mktemp)"
trap 'rm -f "$CERT_DER"' EXIT

if ! keytool -exportcert -keystore "$KEYSTORE" -alias "$ALIAS" \
     -storepass "$STOREPASS" >"$CERT_DER" 2>/dev/null || [[ ! -s "$CERT_DER" ]]; then
  die "could not read certificate from $KEYSTORE (wrong alias or password?)"
fi

CERT_DIGEST="$(
  openssl dgst -sha256 -binary <"$CERT_DER" \
    | openssl base64 \
    | tr '+/' '-_' \
    | tr -d '='
)"
[[ -n "$CERT_DIGEST" ]] || die "could not compute the certificate digest"

SA_EMAIL="$(node -e 'process.stdout.write(require(process.argv[1]).client_email ?? "")' "$SERVICE_ACCOUNT")"
SA_KEY="$(node -e 'process.stdout.write(require(process.argv[1]).private_key ?? "")' "$SERVICE_ACCOUNT")"
[[ -n "$SA_EMAIL" ]] || die "service account JSON has no client_email"
[[ -n "$SA_KEY" ]]   || die "service account JSON has no private_key"

echo "Target Worker env : $TARGET_ENV"
echo "Package name      : $PACKAGE"
echo "Keystore          : $KEYSTORE (alias: $ALIAS)"
echo "Cert SHA-256      : $CERT_DIGEST"
echo "SA email          : $SA_EMAIL"
echo "SA private key    : <${#SA_KEY} chars, hidden>"
echo

if [[ "$DRY_RUN" -eq 1 ]]; then
  echo "Dry run - no secrets were written."
  exit 0
fi

put_secret() {
  printf '%s' "$2" | npx wrangler secret put "$1" "${WRANGLER_ENV[@]}" >/dev/null
  echo "  set $1"
}

echo "Writing secrets..."
put_secret ANDROID_PACKAGE_NAME "$PACKAGE"
put_secret ANDROID_CERT_SHA256 "$CERT_DIGEST"
put_secret PLAY_INTEGRITY_SA_EMAIL "$SA_EMAIL"
put_secret PLAY_INTEGRITY_SA_PRIVATE_KEY "$SA_KEY"

echo
echo "Done. Build the app with the matching cloud project number:"
echo "  flutter run --dart-define=PLAY_INTEGRITY_CLOUD_PROJECT_NUMBER=<project-number>"
