#!/bin/bash

set -euo pipefail

PREFIX="/usr/local/bin"
BINARY_NAME="kira"

usage() {
  echo "Usage: $0 [--prefix /custom/bin]"
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --prefix)
      shift
      [[ $# -gt 0 ]] || usage
      PREFIX="$1"
      ;;
    -h|--help)
      usage
      ;;
    *)
      usage
      ;;
  esac
  shift
done

# Build
echo "📦 Building $BINARY_NAME..."
BUILD_DATE=$(date -u +%Y-%m-%dT%H:%M:%SZ)
GIT_TAG=$(git describe --tags --always 2>/dev/null || echo dev)
GIT_COMMIT=$(git rev-parse --short HEAD 2>/dev/null || echo unknown)
GIT_DIRTY=$(test -n "$(git status --porcelain 2>/dev/null)" && echo dirty || echo clean)
go build -ldflags "-X 'kira/internal/commands.Version=$GIT_TAG' -X 'kira/internal/commands.Commit=$GIT_COMMIT' -X 'kira/internal/commands.BuildDate=$BUILD_DATE' -X 'kira/internal/commands.Dirty=$GIT_DIRTY'" -o "$BINARY_NAME" cmd/kira/main.go
echo "✅ Build successful"

# Ensure destination exists (fallback to sudo if needed)
if ! mkdir -p "$PREFIX" 2>/dev/null; then
  echo "ℹ️ Creating $PREFIX with sudo"
  sudo mkdir -p "$PREFIX"
fi

# Require sudo if not writable
DEST="$PREFIX/$BINARY_NAME"

# Decide if we need sudo based on dest or directory writability
NEED_SUDO=0
if [ ! -w "$PREFIX" ]; then NEED_SUDO=1; fi
if [ -e "$DEST" ] && [ ! -w "$DEST" ]; then NEED_SUDO=1; fi

if [ "$NEED_SUDO" -eq 1 ]; then
  echo "ℹ️ Installing to $DEST with sudo"
  sudo mv -f "$BINARY_NAME" "$DEST"
  sudo chmod +x "$DEST"
else
  mv -f "$BINARY_NAME" "$DEST"
  chmod +x "$DEST"
fi

echo "✅ Installed $BINARY_NAME to $DEST"

# Show version/help
"$DEST" --help || true
