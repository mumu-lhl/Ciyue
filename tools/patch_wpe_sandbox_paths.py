#!/usr/bin/env python3
"""Normalize sandbox executable paths in WPE binaries to standard /usr/bin.

Arch Linux builds detect bwrap as /usr/sbin/bwrap and xdg-dbus-proxy as
/usr/sbin/xdg-dbus-proxy due to the sbin symlink in Arch. On Debian, Ubuntu,
and other standard distributions, /usr/sbin is not merged with /usr/bin,
so bwrap and xdg-dbus-proxy reside exclusively in /usr/bin.
Replace the embedded paths in-place without shifting any section offsets.
"""
from pathlib import Path
import sys

REPLACEMENTS = [
    (b"/usr/sbin/bwrap\0", b"/usr/bin/bwrap\0\0"),
    (b"/usr/sbin/xdg-dbus-proxy\0", b"/usr/bin/xdg-dbus-proxy\0\0"),
]


def patch_file(path: Path) -> bool:
    path = path.resolve()
    original = path.read_bytes()
    content = bytearray(original)
    modified = False

    for old, new in REPLACEMENTS:
        assert len(old) == len(new), f"Replacement length mismatch: {old!r} vs {new!r}"
        count = content.count(old)
        if count > 0:
            content = content.replace(old, new)
            modified = True
            print(f"Replaced {count} occurrence(s) of {old.decode('latin1', errors='replace')} in {path.name}")

    if modified:
        assert len(content) == len(original), f"File size changed for {path.name}"
        assert b"/usr/sbin/bwrap\0" not in content
        assert b"/usr/sbin/xdg-dbus-proxy\0" not in content
        path.write_bytes(content)
        print(f"Successfully patched sandbox paths in {path.name}")
    return modified


def main() -> int:
    targets = sys.argv[1:]
    if not targets:
        print("Usage: patch_wpe_sandbox_paths.py <directory_or_file> ...", file=sys.stderr)
        return 1

    patched_any = False
    for target_str in targets:
        target = Path(target_str)
        if target.is_dir():
            for child in sorted(target.glob("libWPEWebKit-2.0.so*")):
                if child.is_file() and not child.is_symlink():
                    if patch_file(child):
                        patched_any = True
        elif target.is_file():
            if patch_file(target):
                patched_any = True
        else:
            print(f"Target not found: {target}", file=sys.stderr)
            return 1

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
