#!/usr/bin/env python3
"""Builds the dictionaries used by the entry-anchor tests.

The fixtures cover in-entry anchors, cross-entry anchors and the ``##`` escape
for headwords that contain a literal ``#``:

* ``anchor-demo``        an entry with a long filler block *before* the
                         ``sumeru`` anchor, so a scroll is observable, plus one
                         link per supported spelling.
* ``anchor-demo#sumeru`` the headword that the escaped link has to reach.
* ``anchor-demo-other``  a second entry whose links jump into ``anchor-demo``;
                         its own ``local`` anchor also sits below a filler
                         block, so an in-place scroll is visible too.

Every headword is prefixed with ``anchor-demo``: the test dictionaries are
imported into a real group, and a headword such as ``tag`` would also be
answered by any other dictionary in that group, adding a tab per dictionary
and making the observed scroll ambiguous.

Two builds are written into the same directory:

* ``anchor-test-mdx.mdx`` — packed with ``mdict-utils`` (``pip install
  mdict-utils``), which produces a regular MDict file.
* ``anchor-test-stardict.ifo`` / ``.idx`` / ``.dict`` — written here so the
  field type stays ``h`` (HTML). The language display only uses a WebView, and
  therefore only resolves anchors, for HTML entries.

The two builds use different stems on purpose: a dictionary is identified by its
path without the extension, so ``anchor-test.mdx`` and ``anchor-test.ifo``
sitting side by side would collide — only the MDX file would be registered.
Distinct stems let both be imported at once, and the distinct titles keep the
tabs apart. The same rule is documented for users in the FAQ.

Run from the repository root:

    python3 tools/make_anchor_fixtures.py
"""

from __future__ import annotations

import subprocess
import tempfile
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
OUT_DIR = REPO_ROOT / "test" / "fixtures" / "anchor-dictionary"
MDX_STEM = "anchor-test-mdx"
STARDICT_STEM = "anchor-test-stardict"

FILLER_BEFORE = 60
FILLER_AFTER = 5


def _filler(label: str, count: int) -> str:
    """Enough text to push the anchor well below the viewport."""
    return "".join(
        f'<p class="filler">{label} filler line {i:03d} '
        "................................................</p>"
        for i in range(count)
    )


def _links(*pairs: tuple[str, str]) -> str:
    """Renders ``(href, label)`` pairs as one navigation block."""
    return '<nav class="links">' + "".join(
        f'<a href="{href}">{label}</a>' for href, label in pairs
    ) + "</nav>"


ENTRIES: dict[str, str] = {
    "anchor-demo": (
        _filler("before", FILLER_BEFORE)
        + '<a id="sumeru"></a>'
        + '<p class="marker">SUMMERU-MARKER</p>'
        + _filler("after", FILLER_AFTER)
        + '<a name="named"></a>'
        + '<p class="marker">NAMED-MARKER</p>'
        + _links(
            ("entry://anchor-demo#sumeru", "cross entry anchor"),
            ("entry://#sumeru", "same page anchor"),
            ("entry://anchor-demo##sumeru", "literal hash entry"),
            ("entry://#named", "same page named anchor"),
        )
    ),
    "anchor-demo#sumeru": '<p class="marker">LITERAL-HASH-ENTRY</p>',
    "anchor-demo-other": (
        '<p class="marker">OTHER-ENTRY</p>'
        + _links(
            ("entry://anchor-demo#sumeru", "jump into anchor"),
            ("entry://anchor-demo##sumeru", "jump to literal hash"),
            ("entry://#local", "same page local anchor"),
        )
        # The in-place anchor has to start below the fold: with the marker right
        # under the link there would be nothing to scroll and a broken
        # scrollIntoView would look exactly like a working one.
        + _filler("local", FILLER_BEFORE)
        + '<a id="local"></a>'
        + '<p class="marker">LOCAL-MARKER</p>'
        + _filler("after-local", FILLER_AFTER)
    ),
}

TITLE = "Anchor Test"
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
        title.write_text(f"{TITLE} (MDX)", encoding="utf-8")
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
        f"bookname={TITLE} (StarDict)\n"
        f"wordcount={len(ENTRIES)}\n"
        f"idxfilesize={len(idx_bytes)}\n"
        "sametypesequence=h\n"
        f"description={DESCRIPTION}\n",
        encoding="utf-8",
    )


def main() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    write_mdx(OUT_DIR / f"{MDX_STEM}.mdx")
    write_stardict(OUT_DIR / STARDICT_STEM)
    print(f"wrote fixtures to {OUT_DIR}")


if __name__ == "__main__":
    main()
