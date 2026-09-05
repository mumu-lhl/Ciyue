#!/usr/bin/env bash
# CI-only source build. Install beside libWPEWebKit, keeping the sandbox enabled.
set -euo pipefail
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
OUTPUT=${1:?Usage: build_wpe_runtime.sh OUTPUT_DIRECTORY}
mkdir -p "$OUTPUT"
OUTPUT=$(realpath "$OUTPUT")
WORK="$ROOT/build/wpe-source"
VERSION=2.44.2
SHA256=2a3d23cb4fb071ca0db3a09c5a85f27b8bcc6094a2026d3b7407bed4f99218f7
mkdir -p "$WORK"
ARCHIVE="$WORK/wpewebkit-$VERSION.tar.xz"
curl --fail --location --retry 3 "https://wpewebkit.org/releases/wpewebkit-$VERSION.tar.xz" -o "$ARCHIVE"
printf '%s  %s\n' "$SHA256" "$ARCHIVE" | sha256sum --check -
# Start from pristine sources: never silently reapply a patch to stale output.
rm -rf "$WORK/wpewebkit-$VERSION" "$WORK/build"
tar -xJf "$ARCHIVE" -C "$WORK"
python3 "$ROOT/tools/patch_wpe_runtime.py" "$WORK/wpewebkit-$VERSION"

# Match the archived Arch package's ABI and installation layout. Release mode
# deliberately stays enabled; no developer-mode environment overrides needed.
export CC=clang CXX=clang++
cmake -S "$WORK/wpewebkit-$VERSION" -B "$WORK/build" -G Ninja \
  -DPORT=WPE -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_INSTALL_LIBDIR=lib \
  -DCMAKE_INSTALL_LIBEXECDIR=lib -DCMAKE_SKIP_RPATH=ON \
  -DCMAKE_C_FLAGS_RELEASE='-O2 -DNDEBUG -fcf-protection=none' \
  -DCMAKE_CXX_FLAGS_RELEASE='-O2 -DNDEBUG -fcf-protection=none' \
  -DCMAKE_EXE_LINKER_FLAGS=-fuse-ld=lld \
  -DCMAKE_SHARED_LINKER_FLAGS=-fuse-ld=lld \
  -DUSE_LIBBACKTRACE=OFF -DDEVELOPER_MODE=OFF \
  -DENABLE_BUBBLEWRAP_SANDBOX=ON \
  -DENABLE_DOCUMENTATION=OFF -DENABLE_MINIBROWSER=OFF \
  -DENABLE_API_TESTS=OFF -DENABLE_LAYOUT_TESTS=OFF
# WebKit compilation is memory-intensive; don't use unrestricted nproc.
cmake --build "$WORK/build" --parallel "${WPE_BUILD_JOBS:-2}"
DESTDIR="$OUTPUT" cmake --install "$WORK/build" --strip
# Preserve license notices with the bundled runtime.
mkdir -p "$OUTPUT/usr/lib/wpe-webkit-2.0/licenses"
find "$WORK/wpewebkit-$VERSION/Source" -type f \
  \( -name 'COPYING*' -o -name 'LICENSE*' \) -print0 | sort -z |
  while IFS= read -r -d '' file; do
    printf '\n### %s\n' "${file#"$WORK/wpewebkit-$VERSION/"}"
    cat "$file"
  done > "$OUTPUT/usr/lib/wpe-webkit-2.0/licenses/THIRD_PARTY_NOTICES"
# Only the installed runtime is cached; reclaim space before Flutter packaging.
rm -rf "$WORK"
