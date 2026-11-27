#!/usr/bin/env bash
# Write android/keystore.properties + android/app/upload-keystore.jks from
# GitHub Actions secrets. Does nothing when ANDROID_KEYSTORE_BASE64 is unset
# (F-Droid rebuilds with its own key; GitHub APKs stay debug-signed).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PROPS="$ROOT/android/keystore.properties"
JKS="$ROOT/android/app/upload-keystore.jks"

signed=false
if [[ -n "${ANDROID_KEYSTORE_BASE64:-}" ]]; then
  if [[ -z "${ANDROID_KEYSTORE_PASSWORD:-}" || -z "${ANDROID_KEY_ALIAS:-}" || -z "${ANDROID_KEY_PASSWORD:-}" ]]; then
    echo "::error::ANDROID_KEYSTORE_BASE64 is set but password/alias secrets are missing."
    exit 1
  fi
  echo "$ANDROID_KEYSTORE_BASE64" | base64 -d > "$JKS"
  chmod 600 "$JKS"
  umask 077
  cat > "$PROPS" <<EOF
storePassword=${ANDROID_KEYSTORE_PASSWORD}
keyPassword=${ANDROID_KEY_PASSWORD}
keyAlias=${ANDROID_KEY_ALIAS}
storeFile=upload-keystore.jks
EOF
  chmod 600 "$PROPS"
  signed=true
  echo "Configured release signing (keystore written, values not logged)."
else
  echo "ANDROID_KEYSTORE_BASE64 unset; Gradle will sign the release APK with the debug key."
fi

if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  echo "signed=${signed}" >> "$GITHUB_OUTPUT"
fi
