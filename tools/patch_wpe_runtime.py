#!/usr/bin/env python3
"""Patch the pinned WPE 2.44.2 sources, never ELF string tables.

All three consumers must agree: process executables, injected bundle, and
bubblewrap mount paths. Fail closed if an upstream update changes these seams.
"""
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]


def patch(source: Path) -> None:
    webkit = source / "Source/WebKit"
    changes = {
        "Shared/glib/ProcessExecutablePathGLib.cpp": (
            "FileSystem::stringFromFileSystemRepresentation(PKGLIBEXECDIR)",
            "FileSystem::stringFromFileSystemRepresentation(wpeRuntimeDirectory())",
        ),
        "UIProcess/API/glib/WebKitWebContext.cpp": (
            'static const char* injectedBundlePath = PKGLIBDIR G_DIR_SEPARATOR_S "injected-bundle" G_DIR_SEPARATOR_S;',
            'static const char* injectedBundlePath = g_build_filename(wpeRuntimeDirectory(), "injected-bundle", nullptr);',
        ),
        "UIProcess/Launcher/glib/BubblewrapLauncher.cpp": (
            '"--ro-bind-try", PKGLIBEXECDIR, PKGLIBEXECDIR,',
            '"--ro-bind-try", wpeRuntimeDirectory(), wpeRuntimeDirectory(),',
        ),
    }
    outputs = {}
    for relative, (old, new) in changes.items():
        path = webkit / relative
        text = path.read_text()
        if text.count(old) != 1 or text.count('#include "config.h"') != 1:
            raise ValueError(f"Unexpected WPE source: {path}")
        outputs[path] = text.replace(old, new).replace(
            '#include "config.h"', '#include "config.h"\n#include "WPERuntimeDirectory.h"'
        )
    # Validate every seam before writing any file.
    for path, text in outputs.items():
        path.write_text(text)
    (webkit / "Shared/glib/WPERuntimeDirectory.h").write_bytes(
        (ROOT / "linux/packaging/wpe/WPERuntimeDirectory.h").read_bytes()
    )


if __name__ == "__main__":
    patch(Path(sys.argv[1]))
