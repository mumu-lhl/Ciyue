#!/bin/bash
set -e

# Configuration
BINARY_NAME="ciyue"
APP_NAME="Ciyue"
APP_ID="org.eu.mumulhl.ciyue"
ICON_PATH="assets/icon.png"
BUILD_DIR="build/linux/x64/release"
BUNDLE_DIR="$BUILD_DIR/bundle"
APPDIR="$BUILD_DIR/AppDir"
ASSETS_DIR="linux/packaging/appimage"
PACKAGING_DIR="linux/packaging"

# Ensure we are in the project root
cd "$(dirname "$0")/.."

# Check if flutter build has been run
if [ ! -d "$BUNDLE_DIR" ]; then
    echo "Error: Bundle directory not found at $BUNDLE_DIR"
    echo "Please run 'flutter build linux --release' first."
    exit 1
fi

echo "=== 1. Preparing AppDir ==="
rm -rf "$APPDIR"
mkdir -p "$APPDIR"
cp -r "$BUNDLE_DIR/"* "$APPDIR/"

echo "=== 2. Copying Metadata Files ==="
# Desktop file (Root for AppImage)
cp "$PACKAGING_DIR/$APP_ID.desktop" "$APPDIR/"
ln -sf "$APP_ID.desktop" "$APPDIR/$BINARY_NAME.desktop"

# Desktop file (Standard path for AppStream validation)
mkdir -p "$APPDIR/usr/share/applications"
cp "$PACKAGING_DIR/$APP_ID.desktop" "$APPDIR/usr/share/applications/"

# Icon (Standard path)
mkdir -p "$APPDIR/usr/share/icons/hicolor/256x256/apps"
cp "$ICON_PATH" "$APPDIR/usr/share/icons/hicolor/256x256/apps/$BINARY_NAME.png"
# Icon (Root for AppImage)
cp "$ICON_PATH" "$APPDIR/$BINARY_NAME.png"

# AppRun script
cp "$ASSETS_DIR/AppRun" "$APPDIR/AppRun"
chmod +x "$APPDIR/AppRun"

# Metainfo
mkdir -p "$APPDIR/usr/share/metainfo"
cp "linux/packaging/org.eu.mumulhl.ciyue.metainfo.xml" "$APPDIR/usr/share/metainfo/org.eu.mumulhl.ciyue.appdata.xml"

echo "=== 3. Getting appimagetool ==="
if [ ! -x "appimagetool" ]; then
    echo "Downloading appimagetool..."
    wget -q -O appimagetool "https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-x86_64.AppImage"
    chmod +x appimagetool
fi

echo "=== 4. Building AppImage ==="
export ARCH=x86_64
# -u defines the update information.
# You can change this string to your actual update server/GitHub repo.
UPDATE_INFO="gh-releases-zsync|mumu-lhl|Ciyue|latest|Ciyue-latest-x86_64.AppImage.zsync"

./appimagetool --appimage-extract-and-run -u "$UPDATE_INFO" "$APPDIR" "${APP_NAME}-x86_64.AppImage"

echo "=== Done! ==="
echo "AppImage created: ${APP_NAME}-x86_64.AppImage"
