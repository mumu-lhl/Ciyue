#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEST_DIR="$PROJECT_ROOT/assets/third_party/darkreader"
TEMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TEMP_DIR"' EXIT

if ! command -v npm >/dev/null 2>&1; then
  echo "Error: npm is required to download Dark Reader." >&2
  exit 1
fi

VERSION="$(npm view darkreader@latest version)"
if [[ -z "$VERSION" ]]; then
  echo "Error: could not determine the latest Dark Reader version." >&2
  exit 1
fi

TARBALL="$(npm pack "darkreader@$VERSION" --pack-destination "$TEMP_DIR" --silent)"
PACKAGE_DIR="$TEMP_DIR/package"
tar -xzf "$TEMP_DIR/$TARBALL" -C "$TEMP_DIR"

if [[ ! -f "$PACKAGE_DIR/darkreader.js" || ! -f "$PACKAGE_DIR/LICENSE" ]]; then
  echo "Error: Dark Reader $VERSION package is missing darkreader.js or LICENSE." >&2
  exit 1
fi

mkdir -p "$DEST_DIR"
install -m 0644 "$PACKAGE_DIR/darkreader.js" "$DEST_DIR/darkreader.js"
install -m 0644 "$PACKAGE_DIR/LICENSE" "$DEST_DIR/LICENSE"
cat > "$DEST_DIR/NOTICE" <<EOF
Dark Reader v$VERSION, distributed from the official npm package.
Source: https://www.npmjs.com/package/darkreader
Updated by: tools/update_darkreader.sh
EOF

echo "Installed Dark Reader v$VERSION in assets/third_party/darkreader/"
