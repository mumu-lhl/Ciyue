# Dictionary formats

Ciyue reads two dictionary families: **MDict** (`.mdx` / `.mdd`) and **StarDict**
(`.ifo` / `.idx` / `.dict`). Both hold the same kind of data — headwords, HTML or
plain-text definitions, and the pictures and audio those definitions reference —
but they are built very differently, and that difference decides how you convert,
patch or debug one.

This page describes what is inside each format, what Ciyue reads, and how to move
a dictionary from one format to the other.

::: warning One dictionary per stem
Ciyue identifies a dictionary by its path without the extension, so `dict.mdx`
and `dict.ifo` in the same folder count as the same dictionary: only the MDX one
is imported. To keep both, give them different base names — `dict-mdx.mdx` and
`dict-stardict.ifo`, for example.
:::

## MDict

An MDict dictionary is one `.mdx` file plus optional resource files:

| File | Contents |
| --- | --- |
| `name.mdx` | headwords and definitions |
| `name.mdd` | pictures, audio, CSS, JS |
| `name.1.mdd`, `name.2.mdd` | further resource archives (the `1` and `2` are part of the name) |

They all share the base name. `name.mdx` is the only file Ciyue needs to import
the dictionary, but resources are only found when the `.mdd` files sit next to
it.

::: info
MDict itself is closed-source freeware (Octopus Studio) and the format has never
been published as a specification, so every open-source reader — including the
one Ciyue uses — was reverse-engineered from the files. That is also why support
differs between tools. Versions 1.2 and 2.0 (`GeneratedByEngineVersion` in the
header) are what everything handles; 3.0 changes the encoding rules and is only
partially supported, though dictionaries built with it are rare.
:::

Inside, `.mdx` is a 4-byte header length, an XML header in UTF-16LE (`Title`,
`Description`, `Encoding`, `StyleSheet`, …), then the key index and the record
blocks. Both are compressed in chunks, so a lookup only inflates the block it
needs. `.mdd` uses the same container with file paths as keys. Definitions are
HTML in practice, and resource references use relative names.

Ciyue reads `.mdd` and split `.N.mdd` archives, and falls back to loose files
next to the `.mdx` when a resource is in neither. An MDX compressed with LZO is
rejected on import with an "unsupported compression" message: re-compress it
with zlib or convert the file.

### On the desktop, GoldenDict-ng is the reference

MDict itself renders entries with the old Internet Explorer WebBrowser control
(the IE7/8 generation, with JavaScript stopping at ES5), so a modern `.mdx` that
relies on flexbox, `word-break`, `localStorage` or ES6 does not display
correctly in the app that defined the format. Since GoldenDict-ng is what most
people actually run on a PC, it — not MDict — has become the de facto reference
for new dictionaries. The [`pangloss`](https://lib.rs/crates/pangloss) converter
says so plainly:

> Every non-trivial format targets a concrete reader, f.e. goldendict-ng in the
> case of Mdict. While other readers may be able to import the format, they
> usually don't support the same range of features.

| Format | Target reader |
| --- | --- |
| Yomitan | Yomitan |
| StarDict | KOReader |
| MDict | GoldenDict-ng |
| DSL (read only) | GoldenDict-ng |

When a dictionary "looks broken" in one app, first check which reader it was
built for: entries are usually written against the newest engine, not the
oldest.

## StarDict

StarDict is a folder of small files that share a base name:

| File | Required | Contents |
| --- | --- | --- |
| `name.ifo` | yes | plain-text metadata: `bookname`, `wordcount`, `idxfilesize`, `sametypesequence`, … |
| `name.idx` | yes | headword index |
| `name.dict` | yes | definitions |
| `name.syn` | no | synonym index |

`bookname` is the title Ciyue shows. Each `.idx` record is the headword as UTF-8,
a `\0`, then a 4-byte big-endian offset and a 4-byte big-endian length into
`.dict`. Records are sorted by byte value, which is what makes the binary search
possible. A `.ifo` that carries `idxoffsetbits=64` uses 8-byte offsets instead
(the StarDict 3.0 layout).

`.dict` holds the definitions. With `sametypesequence` set, every record is a
concatenation of fields of exactly those types and carries no type bytes;
without it, every field is prefixed by one type byte. The common types:

| Type | Meaning |
| --- | --- |
| `m` | plain text |
| `h` | HTML |
| `g` | Pango markup |
| `x` | XDXF |
| `t` | phonetic transcription |
| `y` | Chinese Pinyin / Japanese kana |
| `r` | list of resource files |
| `W` | WAV audio |
| `P` | picture |

`.idx`, `.syn` and `.dict` may be stored compressed: `.idx.gz` / `.syn.gz`
(gzip) and `.dict.dz` (dictzip — a gzip container whose blocks can be read
independently, so lookups stay random-access). Ciyue reads all three spellings.

### Resource files: `res/` and `res.zip`

StarDict itself has no resource container: pictures and audio sit in a `res/`
folder next to the dictionary, and entries reference them as `res/pic.png` or
`pic.png`.

GoldenDict-ng extended this by letting the same folder ship as a zip, with no
unpacking:

| Path | Note |
| --- | --- |
| `res/` | plain directory |
| `res.zip` | archive with the contents of `res/` at its root |
| `name.res.zip` | same, named after the dictionary |

The archive must not add a top-level `res/` of its own — its root *is* `res/`.
Ciyue looks for `res/`, then `res.zip`, `name.res.zip` and `res/res.zip`, and
inside an archive accepts both `pic.png` and `res/pic.png`, so a zip built for
GoldenDict-ng works as it is.

## Which one to use

- **MDict** compresses better and is a single file, which is why most published
  dictionaries ship that way. It is also harder to open: reading or patching an
  `.mdx` needs a tool.
- **StarDict** is plain files and a tiny index format, so it is easy to inspect,
  diff and patch by hand, and almost every open-source dictionary app reads it.
  With `res.zip` and `.dict.dz` it no longer costs thousands of small files.

## Converting

Ciyue writes neither format. Use the tools below.

### MDict → StarDict (pyglossary)

[pyglossary](https://github.com/ilius/pyglossary) needs Python 3.12 or newer:

```bash
pip install pyglossary
pyglossary book.mdx book.ifo
```

Formats are detected from the extensions; pass `--read-format` /
`--write-format` when they are ambiguous (`pyglossary --help` lists the names).
Useful options:

- `--sqlite` — keep the intermediate data in SQLite instead of RAM; use it for
  large dictionaries.
- `--no-interactive` — for scripts; requires both file names.
- `--remove-html-all` — strip HTML from the definitions (needs `lxml` and
  `beautifulsoup4`); usually you want to keep it.

StarDict output has to be sorted, so pyglossary may switch to the SQLite mode on
its own.

### StarDict → MDict (mdict-utils)

pyglossary can read MDict but not write it. To go the other way,
[mdict-utils](https://github.com/zhansliu/mdict-utils) packs the plain-text
format that MDict tools use:

```bash
pip install mdict-utils
mdict -a source.txt book.mdx --title "My dictionary" --description "..."
```

`source.txt` holds one record per headword: the headword on its own line, the
definition after it, and a line with `</>` between records.

```
word
<p>definition</p>
</>
```

pyglossary's tab-separated output is one small step away from that; a short
script that splits each line and writes `</>` between entries is usually all it
takes.

The same tool is handy for inspection:

```bash
mdict -m book.mdx          # header
mdict -k book.mdx | head   # first headwords
mdict -q word book.mdx     # one entry
mdict -x book.mdx -d out/  # unpack entries and .mdd resources
```

## Common pitfalls

- **Keep the base name.** Renaming one file of a pair (`.mdx` + `.mdd`) or a trio
  (`.ifo` + `.idx` + `.dict`) breaks the dictionary; rename them together.
- **`res.zip` without an outer folder** if the dictionary also has to work in
  GoldenDict-ng.
- **Check the title after converting.** It comes from the MDict header or the
  StarDict `bookname`, whichever the converter wrote; an empty one falls back to
  the file name.
- **Audio may stop working.** pyglossary rewrites MDict's
  `<a href="sound://…">` into `<audio src="…">`, which some readers do not
  render. If the speaker icon disappears after conversion, that is why.

## Where to find dictionaries

- [FreeMdict forum](https://forum.freemdict.com/) — the largest community for
  MDX/StarDict dictionaries, with format discussions and conversion recipes.
- [GoldenDict-ng's format notes](https://xiaoyifang.github.io/goldendict-ng/dictformats/)
  — the reference for `res.zip`, dictzip and the other formats it reads.

Respect the licence of whatever you download or convert; many dictionaries are
only free for personal use.

## Related

- [Getting started](./getting-started) — importing a dictionary.
- [Word-form lookup](./word-forms) — Hunspell files, which are separate from the
  dictionary format itself.
- [FAQ](./faq) — import errors and display problems.
