#!/usr/bin/env python3
"""Builds the dictionaries used by the entry-anchor tests.

The fixtures cover in-entry anchors, cross-entry anchors and the ``##`` escape
for headwords that contain a literal ``#``:

* ``tag``        an entry with a long filler block *before* the ``sumeru``
                 anchor, so a scroll is observable, plus one link per
                 supported spelling.
* ``tag#sumeru`` the headword that the escaped link has to reach.
* ``other``      a second entry whose links jump into ``tag``.

Two builds are written:

* ``anchor-test.mdx`` — packed with ``mdict-utils`` (``pip install
  mdict-utils``), which produces a regular MDict file.
* ``anchor-test.ifo`` / ``.idx`` / ``.dict`` — written here so the field type
  stays ``h`` (HTML). The language display only uses a WebView, and therefore
  only resolves anchors, for HTML entries.

Run from the repository root:

    python3 tools/make_anchor_fixtures.py
"""

from __future__ import annotations

import subprocess
import tempfile
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
OUT_DIR = REPO_ROOT / "test" / "fixtures" / "anchor-dictionary"

FILLER_BEFORE = 60
FILLER_AFTER = 5


def _filler(label: str, count: int) -> str:
    """Enough text to push the anchor well below the viewport."""
    return "".join(
        f'<p class="filler">{label} filler line {i:03d} '
        "................................................</p>"
        for i in range(count)
    )


ENTRIES: dict[str, str] = {
    "tag": (
        _filler("before", FILLER_BEFORE)
        + '<a id="sumeru"></a>'
        + '<p class="marker">SUMMERU-MARKER</p>'
        + _filler("after", FILLER_AFTER)
        + '<a name="named"></a>'
        + '<p class="marker">NAMED-MARKER</p>'
        + '<nav class="links">'
        + '<a href="entry://tag#sumeru">cross entry anchor</a>'
        + '<a href="entry://#sumeru">same page anchor</a>'
        + '<a href="entry://tag##sumeru">literal hash entry</a>'
        + '<a href="entry://#named">same page named anchor</a>'
        + "</nav>"
    ),
    "tag#sumeru": '<p class="marker">LITERAL-HASH-ENTRY</p>',
    "other": (
        '<p class="marker">OTHER-ENTRY</p>'
        + '<nav class="links">'
        + '<a href="entry://tag#sumeru">jump into tag anchor</a>'
        + '<a href="entry://tag##sumeru">jump to literal hash</a>'
        + '<a href="entry://#local">same page local anchor</a>'
        + "</nav>"
        + '<a id="local"></a>'
        + '<p class="marker">LOCAL-MARKER</p>'
    ),
}

TITLE = "Anchor Test Dictionary"
DESCRIPTION = "Fixture for entry-anchor tests."


def write_mdx(out: Path) -> None:
    """Packs the entries into ``out`` with the ``mdict`` command."""
    with tempfile.TemporaryDirectory() as tmp_name:
        tmp = Path(tmp_name)
        source = tmp / "source.txt"
        # One headword line, one single-line HTML body, then the separator.
        with source.open("w", encoding="utf-8") as handle:
            for word, body in ENTRIES.items():
                handle.write(f"{word}\n{body}\n</>\n")

        title = tmp / "title.txt"
        title.write_text(TITLE, encoding="utf-8")
        description = tmp / "description.txt"
        description.write_text(DESCRIPTION, encoding="utf-8")

        subprocess.run(
            [
                "mdict",
                "-a",
                str(source),
                str(out),
                "--title",
                str(title),
                "--description",
                str(description),
            ],
            check=True,
        )


def write_stardict(base: Path) -> None:
    """Writes an HTML-typed StarDict dictionary next to ``base``."""
    dict_bytes = bytearray()
    idx_bytes = bytearray()
    # StarDict indexes are ordered by byte value; the headwords are ASCII.
    for word in sorted(ENTRIES):
        body = ENTRIES[word].encode("utf-8")
        idx_bytes += word.encode("utf-8")
        idx_bytes.append(0)
        idx_bytes += len(dict_bytes).to_bytes(4, "big")
        idx_bytes += len(body).to_bytes(4, "big")
        dict_bytes += body

    base.with_suffix(".dict").write_bytes(dict_bytes)
    base.with_suffix(".idx").write_bytes(idx_bytes)
    base.with_suffix(".ifo").write_text(
        "StarDict's dict ifo file\n"
        "version=2.4.2\n"
        f"bookname={TITLE}\n"
        f"wordcount={len(ENTRIES)}\n"
        f"idxfilesize={len(idx_bytes)}\n"
        "sametypesequence=h\n"
        f"description={DESCRIPTION}\n",
        encoding="utf-8",
    )


def main() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    write_mdx(OUT_DIR / "anchor-test.mdx")
    write_stardict(OUT_DIR / "anchor-test")
    print(f"wrote fixtures to {OUT_DIR}")


if __name__ == "__main__":
    main()
