#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FRONT_DIR="$ROOT_DIR/front"
STATIC_DIR="$ROOT_DIR/cmd/dilmeterapi/static"
BUILD_DIR="$ROOT_DIR/build"

usage() {
  cat <<USAGE
Usage: ./build.sh [--app]

Builds the frontend and backend executable.

Options:
  --app      On macOS, also package build/Midir.app and build/Midir-macOS-<arch>.zip.
  -h, --help Show this help.

For a raw binary only, run: ./build.sh
For the double-clickable macOS app, run: ./build.sh --app
USAGE
}

PACKAGE_MACOS_APP=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --app)
      PACKAGE_MACOS_APP=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ "$PACKAGE_MACOS_APP" == "1" ]]; then
  if [[ "$(uname -s)" != "Darwin" ]]; then
    echo "Error: --app currently packages a macOS .app bundle and must be run on macOS." >&2
    exit 1
  fi
  exec "$ROOT_DIR/scripts/package-macos-app.sh"
fi

GOOS_VALUE="${GOOS:-$(go env GOOS)}"
GOARCH_VALUE="${GOARCH:-$(go env GOARCH)}"
OUTPUT_NAME="${OUTPUT_NAME:-Midir-${GOOS_VALUE}-${GOARCH_VALUE}}"
if [[ "$GOOS_VALUE" == "windows" ]]; then
  OUTPUT_NAME="${OUTPUT_NAME%.exe}.exe"
fi

echo "[1/5] Installing frontend dependencies..."
cd "$FRONT_DIR"
npm install

echo "[2/5] Building frontend..."
npm run build

echo "[3/5] Moving static files to backend..."
rm -rf "$STATIC_DIR"
mkdir -p "$STATIC_DIR"
cp -R "$FRONT_DIR/dist/"* "$STATIC_DIR/"

echo "[4/5] Tidying Go modules..."
cd "$ROOT_DIR"
go mod tidy

echo "[5/5] Building Go executable for ${GOOS_VALUE}/${GOARCH_VALUE}..."
mkdir -p "$BUILD_DIR"
GOOS="$GOOS_VALUE" GOARCH="$GOARCH_VALUE" go build -ldflags="-s -w" -trimpath -v -o "$BUILD_DIR/$OUTPUT_NAME" ./cmd/dilmeterapi

echo
echo "Build complete: $BUILD_DIR/$OUTPUT_NAME"
if [[ "$GOOS_VALUE" == "darwin" ]]; then
  echo "For the double-clickable macOS app bundle, run: ./build.sh --app"
fi
