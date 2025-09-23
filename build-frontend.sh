#!/usr/bin/env bash
set -euo pipefail

pushd frontend > /dev/null

# Build Flutter web with same-origin API (empty base)
flutter build web --release --dart-define=API_BASE=

popd > /dev/null

# Clean existing static (keep folder if exists)
STATIC_DIR="src/main/resources/static"
mkdir -p "$STATIC_DIR"

# Copy build
rm -rf "${STATIC_DIR:?}/"*
cp -r frontend/build/web/* "$STATIC_DIR/"

echo "Frontend built and copied to $STATIC_DIR"