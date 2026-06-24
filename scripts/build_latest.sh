#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_ROOT="$ROOT_DIR/build"
LATEST_DERIVED_DATA="$BUILD_ROOT/DerivedData"
NEXT_DERIVED_DATA="$BUILD_ROOT/DerivedData.next"

PROJECT="${PROJECT:-$ROOT_DIR/One.xcodeproj}"
SCHEME="${SCHEME:-One}"
DESTINATION="${DESTINATION:-generic/platform=iOS Simulator}"
CONFIGURATION="${CONFIGURATION:-Debug}"

cleanup_old_builds() {
  rm -rf "$ROOT_DIR/.build" "$ROOT_DIR/DerivedData"

  if [[ -d "$BUILD_ROOT" ]]; then
    find "$BUILD_ROOT" -mindepth 1 -maxdepth 1 \
      ! -name "$(basename "$LATEST_DERIVED_DATA")" \
      ! -name "$(basename "$NEXT_DERIVED_DATA")" \
      -exec rm -rf {} +
  fi
}

cleanup_failed_next_build() {
  local status=$?
  if [[ $status -ne 0 ]]; then
    rm -rf "$NEXT_DERIVED_DATA"
  fi
  exit "$status"
}

trap cleanup_failed_next_build EXIT

mkdir -p "$BUILD_ROOT"
cleanup_old_builds
rm -rf "$NEXT_DERIVED_DATA"

xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -destination "$DESTINATION" \
  -configuration "$CONFIGURATION" \
  -derivedDataPath "$NEXT_DERIVED_DATA" \
  CODE_SIGNING_ALLOWED=NO \
  build

rm -rf "$LATEST_DERIVED_DATA"
mv "$NEXT_DERIVED_DATA" "$LATEST_DERIVED_DATA"
cleanup_old_builds
