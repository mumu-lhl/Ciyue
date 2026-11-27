# Word-form lookup (Hunspell)

Word-form lookup traces an inflected form back to its lemma: looking up `hoped`
also finds `hope`, and `reconstructiveness` finds `reconstruct`.

The feature is **off by default** and needs external Hunspell files. The reason
is that the work happens in the *engine* rather than inside dictionary content:
nothing has to be packed into the `.mdx`, and any language you can find an
`.aff`/`.dic` pair for can be supported.

## What it does

| Query | Result |
| --- | --- |
| `hoped` | `hoped` (exact entry) + `hope` (lemma) |
| `rims` | `RIMS` (exact entry) + `rim` (lemma) |
| `fällt` (de) | `fällt` + `fallen` / `fällen` |
| `abgekämpft` (de) | `abkämpfen` |
| `かって` (ja) | `かって` (勝手) / `かう` (買う) / `かつ` (勝つ) / `かる` (狩る) |
| `闲适` (zh) | `闲适` (exact entry) + every spelling your table declares, e.g. `閒適` |

How many lemmas come back depends entirely on the Hunspell files you use — when
a form really has several stems, all of them are listed. That is partly Ciyue's
own doing: a stock Hunspell would drop some of them, see
[Ciyue's Hunspell build](../internals/word-forms#ciyues-hunspell-build). For Japanese the stems are
kana, with the kanji form shown in parentheses.

## How to enable it

1. **Settings → Hunspell** — turn on *Enable word-form lookup*.
2. Import `.aff` + `.dic`: pick the folder that contains them, one pair per
   language. Nothing is bundled with the app.
3. Choose a lookup mode (below). For most people, **Supplement** is the more
   useful choice.

Stem lookups run in the background, so enabling this does not slow the UI down.

## Encoding

Ciyue sends lookup words to Hunspell as UTF-8 and decodes the results as UTF-8;
it does not transcode between encodings. The `.aff` must declare `SET UTF-8`,
and the `.dic` must actually be stored as UTF-8.

Legacy dictionaries still import, and ASCII words may work, but accented or
Cyrillic words will not resolve. Some old GoldenDict packs have this problem:
“better morphologies” 1.0 uses ISO-8859-1 for `es_ES` and KOI8-R for `ru_RU`.
Convert both files before importing:

```bash
# ISO-8859-1 example; use the encoding named by the original SET line
iconv -f ISO-8859-1 -t UTF-8 es_ES.aff | sed 's/^SET .*/SET UTF-8/' > es_ES.aff.utf8
iconv -f ISO-8859-1 -t UTF-8 es_ES.dic > es_ES.dic.utf8
```

Verify a few non-ASCII words, then replace the originals. Keep `SET UTF-8`
uppercase and do not add a BOM. GitHub serves the exact bytes committed, so
store the converted UTF-8 files in the repository.

## Fallback vs Supplement

| Query | Fallback (default) | Supplement |
| --- | --- | --- |
| `rims` | only the `RIMS` entry | `RIMS` + `rim` |
| `hoped` | only the `hoped` entry | `hoped` + `hope` |

**Fallback** means: stems are only tried when no dictionary has an exact entry.
So if a dictionary happens to contain `RIMS` or `hoped`, the lemma is never
looked up. **Supplement** always shows the stems side by side with the exact
entry, which is also what GoldenDict does.

If a word is found in one mode but not the other, check this switch first.

## Where to get Hunspell files

The Hunspell dictionaries shipped by an operating system (Debian, for example)
are usually designed for spell checking only and have **no hand-written `st:`
entries**, so irregular forms cannot be resolved at all. Maintained sets:

- English: <https://github.com/yx-wh/hunspell_en_US> — fixed suffix flags,
  missing stem links and derivation labels, plus an extended word list.
- German: <https://github.com/yx-wh/hunspell_de_DE> — over 2,000 added `st:` lines
  for the participles and `zu`-infinitives of separable verbs.
- Japanese: <https://github.com/yx-wh/hunspell_ja_JP> — Japanese normally needs
  no spell checking, so it needs a purpose-built Hunspell dictionary. This set
  builds on Gary's original version and adds mixed-script (kana + kanji) to kanji
  resolution (e.g. まん延 → 蔓延), more verb conjugations, and half-width kana.
- Chinese: <https://github.com/yx-wh/hunspell_zh_CN> — an empty `.aff` and a `st:`
  table generated from several Chinese dictionaries. The published `zh_CN.dic` is
  the pruned build, which is all Ciyue and GoldenDict-ng need; a reader that
  neither composes characters nor runs OpenCC has to build the full table with
  the scripts in that repository.

## Common problems

**Nothing changes after enabling it.** Check three things in order: the toggle,
whether any `.aff`/`.dic` pair was imported, and the current lookup mode. In
Fallback mode, words with an exact hit look exactly as if the feature were off.

**`hoped` still returns `hop`.** The Hunspell files shipped by an operating
system (Debian, for example) carry the `hop/D` flag, and this `.aff` does not
double the final consonant, so `hop + ed` produces `hoped` as well (the correct
form is `hopped`). Switch to the corrected English set above, or remove the `D`
flag from `hop` yourself.

**German `fällt` only returns one lemma.** Both `fallen` and `fällen` have
`fällt` as their third-person singular, but Hunspell can only report what the
`.dic` declares; a set without the matching `st:` entries will return fewer.

**`abzukämpfen` / `abgekämpft` do not resolve.** For separable verbs the `zu`
and `ge` are infixes, which Hunspell cannot strip — they have to be annotated
explicitly with `st:`. See the German set above.

**One spelling, two `st:` lines, and only one lemma comes back.** If a `.dic`
lists the same word twice with different `st:` and neither line carries a flag,
a stock build returns only the first: its `stem()` takes the first `st:` field
of an analysis record, while Ciyue's patched build returns both — see
[Ciyue's Hunspell build](../internals/word-forms#ciyues-hunspell-build).

## See also

- [How word-form lookup works](../internals/word-forms) — the patched Hunspell build, the Chinese variant-character table, NFC normalisation, and testing a dictionary directly.
- [FAQ](./faq) — dictionary and rendering problems.
- [Getting started](./getting-started) — adding dictionaries.
