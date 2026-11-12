#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/build"
SHARED_DIR="$ROOT_DIR/common"
LAMBDA_DIR="$ROOT_DIR/lambda"

PYTHON_VERSION="3.11"
PLATFORM="manylinux2014_x86_64"

LAMBDAS=("$@")
if [ ${#LAMBDAS[@]} -eq 0 ]; then
    LAMBDAS=("canary" "error_counter")
fi

echo "Building Lambdas: ${LAMBDAS[*]}"
echo "Build dir: $BUILD_DIR"
echo

mkdir -p "$BUILD_DIR"

for LAMBDA_NAME in "${LAMBDAS[@]}"; do
    LAMBDA_PATH="$LAMBDA_DIR/$LAMBDA_NAME"
    BUILD_PATH="$BUILD_DIR/$LAMBDA_NAME"

    if [ ! -d "$LAMBDA_PATH" ]; then
        echo "ERROR: Lambda '$LAMBDA_NAME' not found at $LAMBDA_PATH"
        exit 1
    fi

    echo "=== Building $LAMBDA_NAME ==="

    rm -rf "$BUILD_PATH"
    mkdir -p "$BUILD_PATH"

    find "$LAMBDA_PATH" -maxdepth 1 -name '*.py' -exec cp {} "$BUILD_PATH/" \;

    mkdir -p "$BUILD_PATH/common"
    find "$SHARED_DIR" -maxdepth 1 -name '*.py' -exec cp {} "$BUILD_PATH/common/" \;

    if [ -f "$LAMBDA_PATH/requirements.txt" ]; then
        echo "Installing dependencies..."
        pip install \
            --target "$BUILD_PATH" \
            --no-cache-dir \
            --platform "$PLATFORM" \
            --only-binary=:all: \
            --python-version "$PYTHON_VERSION" \
            --upgrade \
            -r "$LAMBDA_PATH/requirements.txt" \
            --quiet
    fi

    rm -f "$BUILD_DIR/${LAMBDA_NAME}.zip"
    if command -v zip > /dev/null 2>&1; then
        (cd "$BUILD_PATH" && zip -rq "$BUILD_DIR/${LAMBDA_NAME}.zip" .)
    else
        python - "$BUILD_PATH" "$BUILD_DIR/${LAMBDA_NAME}.zip" <<'PY'
import os, sys, zipfile
build_path, out_path = sys.argv[1], sys.argv[2]
with zipfile.ZipFile(out_path, "w", zipfile.ZIP_DEFLATED) as zf:
    for root, _dirs, files in os.walk(build_path):
        for f in files:
            full = os.path.join(root, f)
            zf.write(full, os.path.relpath(full, build_path))
PY
    fi

    SIZE=$(du -h "$BUILD_DIR/${LAMBDA_NAME}.zip" | cut -f1)
    echo "Built: $BUILD_DIR/${LAMBDA_NAME}.zip ($SIZE)"
    echo
done

echo "=== Done ==="
ls -lh "$BUILD_DIR"/*.zip