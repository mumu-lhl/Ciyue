#!/bin/bash
set -e

# Configuration
BINARY_NAME="ciyue"
APP_NAME="Ciyue"
APP_ID="org.eu.mumulhl.ciyue"
ICON_PATH="assets/icon.png"
BUILD_DIR="build/linux/x64/release"
BUNDLE_DIR="$BUILD_DIR/bundle"
DEB_ROOT="build/deb"
DEB_ASSETS_DIR="linux/packaging/deb"
DESKTOP_FILE="linux/packaging/org.eu.mumulhl.ciyue.desktop"
METAINFO_FILE="linux/packaging/org.eu.mumulhl.ciyue.metainfo.xml"

# Ensure we are in the project root
cd "$(dirname "$0")/.."

# Check if flutter build has been run
if [ ! -d "$BUNDLE_DIR" ]; then
    echo "Error: Bundle directory not found at $BUNDLE_DIR"
    echo "Please run 'flutter build linux --release' first."
    exit 1
fi

# Extract version from pubspec.yaml
VERSION_RAW=$(grep 'version: ' pubspec.yaml | sed 's/version: //')
# Normalize version for DEB (replace + with -)
VERSION=$(echo $VERSION_RAW | sed 's/+/-/')

echo "=== 1. Preparing DEB Build Environment ==="
rm -rf "$DEB_ROOT"
mkdir -p "$DEB_ROOT/usr/bin"
mkdir -p "$DEB_ROOT/opt/$BINARY_NAME"
mkdir -p "$DEB_ROOT/usr/share/applications"
mkdir -p "$DEB_ROOT/usr/share/icons/hicolor/256x256/apps"
mkdir -p "$DEB_ROOT/usr/share/metainfo"
mkdir -p "$DEB_ROOT/DEBIAN"

echo "=== 2. Copying Files ==="
# Copy bundle to /opt/ciyue
cp -r "$BUNDLE_DIR/"* "$DEB_ROOT/opt/$BINARY_NAME/"

# Create symlink in /usr/bin
ln -sf "/opt/$BINARY_NAME/$BINARY_NAME" "$DEB_ROOT/usr/bin/$BINARY_NAME"

# Desktop file
cp "$DESKTOP_FILE" "$DEB_ROOT/usr/share/applications/$APP_ID.desktop"

# Icon
cp "$ICON_PATH" "$DEB_ROOT/usr/share/icons/hicolor/256x256/apps/$BINARY_NAME.png"

# Metainfo
cp "$METAINFO_FILE" "$DEB_ROOT/usr/share/metainfo/$APP_ID.appdata.xml"

echo "=== 3. Generating Control File from Template ==="
# Determine Architecture
ARCH=$(dpkg --print-architecture 2>/dev/null || echo "amd64")

# Calculate installed size in KB
INSTALLED_SIZE=$(du -sk "$DEB_ROOT" | cut -f1)

CONTROL_TEMPLATE="$DEB_ASSETS_DIR/control"
CONTROL_FILE="$DEB_ROOT/DEBIAN/control"

sed -e "s|@BINARY_NAME@|$BINARY_NAME|g" \
    -e "s|@VERSION@|$VERSION|g" \
    -e "s|@ARCH@|$ARCH|g" \
    -e "s|@INSTALLED_SIZE@|$INSTALLED_SIZE|g" \
    "$CONTROL_TEMPLATE" > "$CONTROL_FILE"

echo "=== 4. Building DEB Package ==="
if ! command -v dpkg-deb &> /dev/null; then
    echo "Error: 'dpkg-deb' not found. Please install 'dpkg' or 'apt-utils'."
    exit 1
fi

dpkg-deb --build "$DEB_ROOT" "${BINARY_NAME}_${VERSION}_${ARCH}.deb"

echo "=== 5. Cleanup ==="
rm -rf "$DEB_ROOT"

echo "=== Done! ==="
echo "DEB created: $(ls ${BINARY_NAME}_${VERSION}_${ARCH}.deb)"
