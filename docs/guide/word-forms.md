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
[Ciyue's Hunspell build](#ciyues-hunspell-build). For Japanese the stems are
kana, with the kanji form shown in parentheses.

## How to enable it

1. **Settings → Hunspell** — turn on *Enable word-form lookup*.
2. Import `.aff` + `.dic`: pick the folder that contains them, one pair per
   language. Nothing is bundled with the app.
3. Choose a lookup mode (below). What most people actually want is
   **Supplement**.

Stem lookups run in a separate isolate, so enabling this does not slow the UI
down.

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

## Ciyue's Hunspell build

Ciyue compiles Hunspell **1.7.3** with two local patches, both about stems:

- `hashmgr.cxx` — a second entry for the same word is only discarded when it has
  no flags **and** the same description. Upstream drops it whenever neither entry
  carries a flag, so two flagless `st:` lines for one spelling lose the second
  one ([hunspell#1171](https://github.com/hunspell/hunspell/issues/1171)).
- `hunspell.cxx` — `stem()` returns every `st:` field of an analysis record, not
  just the first.

The pin stays at 1.7.3 because those two files are replaced wholesale. Nothing in
Ciyue depends on the CLI-only CJK fix that later releases (1.7.6) carry: word-form
lookup never runs `hunspell -m`, and that bug lived in the tool's output path, not
in `analyze()` or `stem()`.

Together they let one spelling be listed several times, which is how Japanese
homonyms and Chinese variant characters are declared:

```text
たい積 st:体積
たい積 st:堆積
```

Stock Hunspell 1.7.3 and later keeps only the first line; older builds keep both.
GoldenDict and a distro `hunspell` use whatever library the system provides, so
on 1.7.3+ they report fewer stems for the same files.

The workaround for a stock build is to give the duplicates a flag the `.aff`
never defines:

```text
たい積/X st:体積
たい積/X st:堆積
```

`alen != 0` sends the entry down the `next_homonym` branch instead of the
duplicate check, and since no affix rule uses `X`, no extra word forms appear.
Dictionaries padded this way work unchanged in Ciyue — the undefined flag is
simply carried along — so there is no reason to strip it.

## Chinese: simplified, traditional and variant characters

Chinese has no inflection, so a Chinese `.dic` uses `st:` for a different job:
recording which characters are the same character written another way. Ciyue
reads such a table **per character as well as per word**, which is what lets a
query typed in one form reach a headword stored in another.

A table like that is published at <https://github.com/yx-wh/hunspell_zh_CN>:
import its `zh_CN.aff` and `zh_CN.dic` and it works. The rest of this section is
what the file contains, and how to build your own.

### The `.aff` stays an empty shell

```text
SET UTF-8
LANG zh
FLAG long
```

Nothing else — no affix rules, no compound settings. Hunspell then behaves as a
hash table from a spelling to its variants, which is all this needs.

### One line per character, written in both directions

```text
闲 st:閒
闲 st:閑
閒 st:闲
閑 st:闲
适 st:適
適 st:适
```

Both directions have to be listed. `闲 st:閒` only turns `闲` into `閒`; without
`閒 st:闲` the reverse query (`閒适` → `闲适`) finds nothing. `闲` also needs two
lines, which is only safe because of the patch described in
[Ciyue's Hunspell build](#ciyues-hunspell-build) — a stock build would keep
`闲 st:閒` and drop `闲 st:閑`.

Single-character lines are also what makes mixed spellings work — the table never
has to contain them, because the combinations are built at query time:

| Submitted | Spellings read from the table above |
| --- | --- |
| `闲适` | `闲适`, `閒適`\*, `閑适`, `閒适`, `闲適`, `閑適` |

\* from a word-level line, see below. Every other entry is a character
combination: `闲適` would need no line of its own.

### One line per word when character-wise conversion is not enough

```text
闲适 st:閒適
```

A word-level line is read **before** the character combinations, so the form the
table's author chose comes first, even when it replaces more characters than a
combination would. It is also the only way to express a mapping that is not
character-for-character — 干/乾/幹 or 发/髮/發 style splits, or a wording whose
traditional form has a different length.

### What this does not do

- **It is exact, not a prefix.** `st:` maps whole words, so typing `木红` does not
  suggest a headword stored as `木紅毬`; submit `木红球` (or `木紅毬`) instead and
  the characters are expanded. The suggestion list keeps working on the prefix
  you typed.
- **Only spellings your table covers are reachable.** A character with no entry
  stays as typed — the expansion reuses what the `.dic` declares and adds
  nothing of its own.
- **The lookup mode decides when variants are used.** In Supplement mode an
  exact entry and its variants show side by side; in Fallback mode the variants
  are only tried for dictionaries where the exact spelling found nothing.

### Building the table

A table generated from several common Chinese dictionaries is published at
<https://github.com/yx-wh/hunspell_zh_CN>; build your own when it does not cover
the dictionaries you read.

1. Export the headwords of the dictionaries you actually read. The table is worth
   building from real headwords, because a `st:` target that no dictionary
   contains resolves to nothing.
2. Convert each headword to the standard form — OpenCC `t2s` is a good start,
   then fix the one-to-many characters by hand (`发` → `髮` / `發`, `干` →
   `乾` / `幹`).
3. Write **both** directions for every pair, and add the single-character pairs
   from a variant-character table:

   ```python
   lines.append(f"{variant} st:{standard}")
   lines.append(f"{standard} st:{variant}")
   ```

4. Put the result next to the empty `.aff` above and import the pair. A table
   generated from one dictionary set only knows that set's vocabulary — an extra
   dictionary is best folded in by regenerating it.

Most word-level lines such a table carries are derivable and can be dropped: one
that Ciyue rebuilds from the single-character lines, and that OpenCC produces
anyway, is needed by neither reader. `prune_zh_dic.py` in the repository above
runs that comparison and takes a 29 MB table down to under 1 MB without losing a
candidate — 1.1 million word-level lines fall to 37 thousand.

## Encoding: `.dic` files use composed forms

Ciyue normalises every query to **NFC** before handing it to Hunspell — the form
keyboards, web pages and the maintained sets above already use. A `.dic` you
built yourself carries no such guarantee, and Hunspell compares bytes without
ever normalising: a file written in decomposed form (`e` + U+0301 instead of
`é`) matches nothing at all.

The symptom is narrow and easy to misread: dictionary entries still appear, but
a word never resolves to its lemma — as if word-form lookup were switched off.
Convert the file once:

```bash
python3 -c "import sys,unicodedata; p=sys.argv[1]; t=open(p,encoding='utf-8').read(); open(p,'w',encoding='utf-8').write(unicodedata.normalize('NFC',t))" de_DE.dic
```

The `.aff` side cannot fix this for you: `MAP` and `REP` only feed `suggest()`,
and `ICONV` — the one directive that rewrites input — only works if the file's
author wrote it. That is why the normalisation sits in the query path instead of
depending on the dictionary.

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
stock Hunspell 1.7.3 and later keeps only the first entry; Ciyue's patched build
keeps both — see [Ciyue's Hunspell build](#ciyues-hunspell-build). Giving the
duplicates a flag the `.aff` never defines (`たい積/X st:堆積`) restores them in
either build.

## Testing a dictionary directly

The command-line tool is the quickest way to see what a `.aff`/`.dic` pair
returns, and a current build handles CJK correctly:

```bash
hunspell -d ./en_US -s <<< "hoped"        # -> hope
hunspell -d ./de_DE -s <<< "abgekämpft"   # -> abkämpfen
hunspell -d ./ja_JP -s <<< "美味しかった"  # -> 美味しい
```

Two CLI traps are worth knowing:

- **Old builds dropped CJK text.** `hunspell -m` from older releases reported
  `しかった st:しかる` for `美味しかった`; that was the output layer, not the
  dictionary. 1.7.6 returns `st:美味しい`, the same as the library API.
- **Every build from 1.7.3 on drops duplicate `st:` lines** that share a word
  and carry no flags (issue #1171). Ciyue's bundled Hunspell does not, so a
  distro build can report fewer stems than Ciyue for the same files.

To see what Ciyue itself gets, call `stem()` — the function behind word-form
lookup — instead of the CLI.

<details>
<summary>Test harness (C++, ~20 lines)</summary>

```cpp
#include <hunspell/hunspell.hxx>
#include <iostream>
#include <vector>
#include <string>

int main(int argc, char * argv[]) {
    if (argc < 4) {
        std::cerr << "Usage: " << argv[0]
                  << " <aff_file> <dic_file> <word>" << std::endl;
        return 1;
    }

    // Open the dictionary pair.
    Hunspell hunspell(argv[1], argv[2]);

    // Word-form lookup goes through Hunspell_stem, which filters analyze()
    // down to the `st:` fields. Swap in analyze() to see the whole record.
    std::vector<std::string> results = hunspell.stem(argv[3]);

    for (const auto & line : results) {
        std::cout << line << std::endl;
    }

    return 0;
}
```

Build and run:

```bash
# Debian/Ubuntu
sudo apt install libhunspell-dev
# macOS
brew install hunspell

g++ test_analyze.cpp -o test_analyze $(pkg-config --cflags --libs hunspell)
./test_analyze ja_JP.aff ja_JP.dic 美味しかった
```

`stem()` prints one stem per line, e.g. `美味しい`. Switch the call back to
`analyze()` to see the raw record (`st:美味しい fl:XQ fl:Ta`), where `st:` is the
field word-form lookup keeps.

</details>

## See also

- [FAQ](./faq) — dictionary and rendering problems.
- [Getting started](./getting-started) — adding dictionaries.
