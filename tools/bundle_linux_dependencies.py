#!/usr/bin/env python3
"""Collect and verify a Linux bundle's recursive ELF dependency closure."""

from __future__ import annotations

import argparse
from collections import deque
from dataclasses import dataclass
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys


# These are supplied by the target system's glibc ABI. Bundling them would tie
# the application to the build container's dynamic loader instead of improving
# portability.
GLIBC_RUNTIME_LIBRARIES = {
    "ld-linux-x86-64.so.2",
    "libanl.so.1",
    "libc.so.6",
    "libdl.so.2",
    "libm.so.6",
    "libpthread.so.0",
    "libresolv.so.2",
    "librt.so.1",
    "libutil.so.1",
}

NEEDED_RE = re.compile(r"\(NEEDED\).*Shared library: \[(.+)]")
SONAME_RE = re.compile(r"\(SONAME\).*Library soname: \[(.+)]")


@dataclass(frozen=True)
class ElfMetadata:
    needed: tuple[str, ...]
    soname: str | None


def elf_metadata(path: Path) -> ElfMetadata | None:
    try:
        with path.open("rb") as stream:
            if stream.read(4) != b"\x7fELF":
                return None
    except OSError as error:
        raise RuntimeError(f"Cannot read {path}: {error}") from error

    result = subprocess.run(
        ["readelf", "--dynamic", str(path)],
        check=False,
        capture_output=True,
        text=True,
        env={**os.environ, "LC_ALL": "C"},
    )
    if result.returncode != 0:
        raise RuntimeError(f"readelf failed for {path}:\n{result.stderr.strip()}")

    needed = tuple(match.group(1) for match in NEEDED_RE.finditer(result.stdout))
    soname_match = SONAME_RE.search(result.stdout)
    return ElfMetadata(needed, soname_match.group(1) if soname_match else None)


def iter_elf_files(root: Path):
    for path in sorted(root.rglob("*")):
        if path.is_file() and not path.is_symlink() and elf_metadata(path) is not None:
            yield path


def library_index(search_roots: list[Path]) -> dict[str, Path]:
    index: dict[str, Path] = {}
    candidates: list[Path] = []
    for root in search_roots:
        if root.is_dir():
            candidates.extend(path for path in root.rglob("*.so*") if path.is_file())

    for path in sorted(candidates, key=lambda item: (len(item.parts), str(item))):
        index.setdefault(path.name, path.resolve())
    return index


def provided_libraries(library_dir: Path) -> dict[str, Path]:
    provided: dict[str, Path] = {}
    for path in sorted(library_dir.iterdir()):
        if not (path.is_file() or path.is_symlink()):
            continue
        resolved = path.resolve()
        metadata = elf_metadata(resolved)
        if metadata is None:
            continue
        provided[path.name] = path
        if metadata.soname:
            provided.setdefault(metadata.soname, path)
    return provided


def ensure_loader_name(library_dir: Path, name: str, source: Path) -> Path:
    destination = library_dir / name
    if destination.exists() or destination.is_symlink():
        return destination

    if source.parent == library_dir:
        destination.symlink_to(source.name)
        return destination

    shutil.copy2(source.resolve(), destination)
    patchelf = shutil.which("patchelf")
    if patchelf:
        subprocess.run([patchelf, "--remove-rpath", str(destination)], check=True)
    return destination


def collect(bundle_dir: Path, search_roots: list[Path]) -> None:
    library_dir = bundle_dir / "lib"
    index = library_index(search_roots)
    provided = provided_libraries(library_dir)
    queue = deque(iter_elf_files(bundle_dir))
    inspected: set[Path] = set()

    while queue:
        binary = queue.popleft().resolve()
        if binary in inspected:
            continue
        inspected.add(binary)
        metadata = elf_metadata(binary)
        if metadata is None:
            continue

        for needed in metadata.needed:
            if needed in GLIBC_RUNTIME_LIBRARIES:
                continue
            if needed in provided:
                provider = provided[needed]
                if provider.name != needed and not (library_dir / needed).exists():
                    provider = ensure_loader_name(library_dir, needed, provider)
                    provided[needed] = provider
                queue.append(provider)
                continue
            source = index.get(needed)
            if source is None:
                raise RuntimeError(f"Unable to locate {needed}, required by {binary}")
            destination = ensure_loader_name(library_dir, needed, source)
            print(f"Bundled {needed} from {source}")
            provided[needed] = destination
            queue.append(destination)


def verify(bundle_dir: Path) -> None:
    library_dir = bundle_dir / "lib"
    provided_names: set[str] = set()
    for path in library_dir.iterdir():
        if path.is_symlink() and not path.exists():
            raise RuntimeError(f"Bundle contains a broken library symlink: {path}")
        if path.is_file() and elf_metadata(path.resolve()) is not None:
            provided_names.add(path.name)
    missing: dict[str, list[Path]] = {}
    for binary in iter_elf_files(bundle_dir):
        metadata = elf_metadata(binary)
        assert metadata is not None
        for needed in metadata.needed:
            if needed not in GLIBC_RUNTIME_LIBRARIES and needed not in provided_names:
                missing.setdefault(needed, []).append(binary)

    if missing:
        details = "\n".join(
            f"  {name}: {', '.join(str(path) for path in dependents)}"
            for name, dependents in sorted(missing.items())
        )
        raise RuntimeError(
            "Bundle has dependencies that would fall back to the build/host system:\n"
            + details
        )


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--bundle", type=Path, required=True)
    parser.add_argument("--search", action="append", default=[], type=Path)
    parser.add_argument("--verify-only", action="store_true")
    args = parser.parse_args()

    bundle_dir = args.bundle.resolve()
    if not (bundle_dir / "lib").is_dir():
        parser.error(f"bundle library directory does not exist: {bundle_dir / 'lib'}")

    try:
        if not args.verify_only:
            if not args.search:
                parser.error("at least one --search directory is required when collecting")
            collect(bundle_dir, [path.resolve() for path in args.search])
        verify(bundle_dir)
    except RuntimeError as error:
        print(error, file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
