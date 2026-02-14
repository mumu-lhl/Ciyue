#!/bin/bash
set -e

# Configuration
BINARY_NAME="ciyue"
APP_NAME="Ciyue"
APP_ID="org.eu.mumulhl.ciyue"
ICON_PATH="assets/icon.png"
BUILD_DIR="build/linux/x64/release"
BUNDLE_DIR="$BUILD_DIR/bundle"
RPM_ROOT="build/rpm"
RPM_ASSETS_DIR="linux/packaging/rpm"
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
# Normalize version for RPM (replace + with _, - with ~)
VERSION=$(echo $VERSION_RAW | cut -d'+' -f1 | sed 's/-/~/g')
RELEASE=$(echo $VERSION_RAW | cut -d'+' -f2)
[ "$RELEASE" == "$VERSION_RAW" ] && RELEASE=1

echo "=== 1. Preparing RPM Build Environment ==="
rm -rf "$RPM_ROOT"
mkdir -p "$RPM_ROOT"/{BUILD,RPMS,SOURCES,SPECS,SRPMS,BUILDROOT}

echo "=== 2. Generating SPEC File from Template ==="
SPEC_TEMPLATE="$RPM_ASSETS_DIR/$BINARY_NAME.spec"
SPEC_FILE="$RPM_ROOT/SPECS/$BINARY_NAME.spec"
DESKTOP_FILE="$DESKTOP_FILE"
# Use C locale for standard date format in changelog (e.g., Sat Feb 14 2026)
CURRENT_DATE=$(LC_ALL=C date +"%a %b %d %Y")

# Use absolute paths for the spec file replacements to avoid issues during rpmbuild
ABS_BUNDLE_DIR="$(pwd)/$BUNDLE_DIR"
ABS_DESKTOP_FILE="$(pwd)/$DESKTOP_FILE"
ABS_ICON_PATH="$(pwd)/$ICON_PATH"
ABS_METAINFO_FILE="$(pwd)/$METAINFO_FILE"

sed -e "s|@VERSION@|$VERSION|g" \
    -e "s|@RELEASE@|$RELEASE|g" \
    -e "s|@BUNDLE_DIR@|$ABS_BUNDLE_DIR|g" \
    -e "s|@DESKTOP_FILE@|$ABS_DESKTOP_FILE|g" \
    -e "s|@ICON_PATH@|$ABS_ICON_PATH|g" \
    -e "s|@METAINFO_FILE@|$ABS_METAINFO_FILE|g" \
    -e "s|@DATE@|$CURRENT_DATE|g" \
    "$SPEC_TEMPLATE" > "$SPEC_FILE"

echo "=== 3. Building RPM Package ==="
if ! command -v rpmbuild &> /dev/null; then
    echo "Error: 'rpmbuild' not found. Please install 'rpm-build' (Fedora/RHEL) or equivalent."
    exit 1
fi

# Define QA_RPATHS to ignore invalid RPATH errors (0x0002) which are common in Flutter builds
export QA_RPATHS=$(( 0x0002 ))

rpmbuild --define "_topdir $(pwd)/$RPM_ROOT" -bb "$SPEC_FILE"

echo "=== 4. Finalizing ==="
# Move resulting RPMs to root and cleanup
mv "$RPM_ROOT"/RPMS/*/*.rpm .
rm -rf "$RPM_ROOT"

echo "=== Done! ==="
echo "RPM created: $(ls *.rpm)"
