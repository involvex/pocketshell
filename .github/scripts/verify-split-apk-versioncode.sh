#!/usr/bin/env bash
# Confirm a split APK's versionCode is pubspec build * 10 + ABI
# (armeabi-v7a=1, arm64-v8a=2, x86_64=3).
set -euo pipefail

apk="${1:?apk path}"
abi_digit="${2:?ABI digit 1|2|3}"

if [[ ! -f "$apk" ]]; then
  echo "missing APK: $apk" >&2
  exit 1
fi

build="$(sed -nE 's/^version:[[:space:]]*[0-9]+\.[0-9]+\.[0-9]+\+([0-9]+).*/\1/p' pubspec.yaml | head -1)"
if [[ -z "$build" ]]; then
  echo "could not parse pubspec.yaml version build number" >&2
  exit 1
fi
expected="$((build * 10 + abi_digit))"

find_aapt() {
  local dir candidate
  for dir in \
    "${ANDROID_HOME:-}" \
    "${ANDROID_SDK_ROOT:-}" \
    "${HOME}/Android/Sdk" \
    /usr/local/lib/android/sdk \
    /opt/android-sdk; do
    if [[ -n "$dir" && -d "$dir/build-tools" ]]; then
      candidate="$(find "$dir/build-tools" \( -name aapt -o -name aapt.exe \) -type f 2>/dev/null | sort | tail -1)"
      if [[ -n "$candidate" ]]; then
        printf '%s\n' "$candidate"
        return 0
      fi
    fi
  done
  if command -v aapt >/dev/null 2>&1; then
    command -v aapt
    return 0
  fi
  return 1
}

aapt="$(find_aapt || true)"
if [[ -z "$aapt" ]]; then
  echo "aapt not found (set ANDROID_HOME or ANDROID_SDK_ROOT)" >&2
  exit 1
fi

badging="$("$aapt" dump badging "$apk")"
# Anchor to the package: line. Greedy .*name= matches compileSdkVersionCodename
# (API 16+ is '16') and fails CI with unexpected applicationId: 16.
pkg="$(printf '%s\n' "$badging" | sed -nE "s/^package: name='([^']+)'.*/\1/p" | head -1)"
code="$(printf '%s\n' "$badging" | sed -nE "s/^package:.*versionCode='([0-9]+)'.*/\1/p" | head -1)"
name="$(printf '%s\n' "$badging" | sed -nE "s/^package:.*versionName='([^']+)'.*/\1/p" | head -1)"

echo "package=$pkg versionName=$name versionCode=$code expected=$expected aapt=$aapt"
if [[ "$pkg" != "com.involvex.ssh_app_flutter" ]]; then
  echo "unexpected applicationId: $pkg" >&2
  exit 1
fi
if [[ "$code" != "$expected" ]]; then
  echo "versionCode $code != expected $expected (build $build * 10 + $abi_digit)" >&2
  exit 1
fi
