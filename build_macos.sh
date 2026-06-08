#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="$PROJECT_DIR/build"
SDK_PATH="$(xcrun --sdk iphoneos --show-sdk-path)"

mkdir -p "$BUILD_DIR"

xcrun --sdk iphoneos clang \
  -arch arm64 \
  -dynamiclib \
  -fobjc-arc \
  -isysroot "$SDK_PATH" \
  -miphoneos-version-min=12.0 \
  -install_name "@rpath/tola.dylib" \
  -framework Foundation \
  -framework UIKit \
  "$PROJECT_DIR/TolaDylib/Tola.m" \
  -o "$BUILD_DIR/tola.dylib"

echo "Built: $BUILD_DIR/tola.dylib"
