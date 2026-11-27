# How word-form lookup works

This page documents the implementation behind [Word-form lookup](../guide/word-forms): the patched Hunspell build Ciyue ships, how the Chinese variant-character table is designed, why queries are normalised to NFC, and how to test a `.aff`/`.dic` pair directly.

## Ciyue's Hunspell build

Ciyue compiles Hunspell **1.7.6** with one local patch, in `hunspell.cxx`:
`stem()` returns every `st:` field of an analysis record, not just the first.
Upstream takes only the first field, so a stock build reports fewer stems for
the same files — GoldenDict and a distro `hunspell` use whatever library the
system provides.

The patch is what lets one spelling be listed several times, which is how
Japanese homonyms and Chinese variant characters are declared:

```text
たい積 st:体積
たい積 st:堆積
```

The other half of this used to be a second patch, in `hashmgr.cxx`: a second
entry for the same word was only discarded when it had no flags **and** the
same description. Upstream dropped it whenever neither entry carried a flag,
so two flagless `st:` lines for one spelling lost the second one
([hunspell#1171](https://github.com/hunspell/hunspell/issues/1171)). Upstream
has since fixed that itself — two entries now count as duplicates only when
both are flagless **and** describe the word the same way, and anything else is
kept as a homonym — so Ciyue no longer carries the patch: `hashmgr.cxx` comes
straight from upstream, and the vendored copy is gone. The hook also compiles
the new upstream `hunspelltrace.cxx`, which the 1.7.6 sources include — the
link fails without it.

Tables padded for the old behaviour still work unchanged. Giving the
duplicates a flag the `.aff` never defines —

```text
たい積/X st:体積
たい積/X st:堆積
```

— used to send the entries down the homonym branch instead of the duplicate
check, and since no affix rule uses `X`, no extra word forms appear. The
padding is no longer needed for new tables, and the undefined flag is simply
carried along in Ciyue, so there is no reason to strip it from existing ones.

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
lines, which only works because of the patch described in
[Ciyue's Hunspell build](#ciyues-hunspell-build): Ciyue's build returns every
`st:` field, while a stock build returns only the first, so `閑` would never
come back.

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

## Japanese: `ICONV`, not `st:`

Japanese needs the opposite of the Chinese table. An old form (`圖`) and its
shinjitai (`図`) are the same word written another way, and modern dictionaries
headword the shinjitai — so the relation is a **one-way normalisation**, not an
equivalence class. It belongs in the `.aff`, and it is already there — the same
table that folds half-width katakana. It starts with its row count (`ICONV 406`)
and then has one line per pair:

```text
ICONV ｶﾞ ガ        # half-width katakana -> full-width
ICONV 圖 図        # 旧字体 -> 新字体
```

`ICONV` rewrites the query *before* `analyze()`/`stem()` runs, so the
normalised spelling is what gets deinflected:

| Query | After `ICONV` | `stem()` |
| --- | --- | --- |
| `圖らず` | `図らず` | `図らず`, `図る` |
| `圖書館` | `図書館` | `図書館` |

That is why `st:` is the wrong tool here: a `st:` row only maps the spelling
you typed, so `圖らず → 図らず` would stop at the spelling and never reach
`図る`. `ICONV` folds first, and the existing `5A`/`f2` affix rules do the
rest — for every word containing the character, without a row per word.

Two consequences worth keeping:

- **`.dic` source spellings must follow `ICONV`.** `圖/Zz st:図` is unreachable
  once `圖` is rewritten to `図`, and the loss is silent (`spell()` still says
  yes). `apply_iconv_to_dic.py` in `hunspell_ja_JP` rewrites the heads and
  folds the now self-referential `st:` rows; run it (and then
  `add_homonym_flag.py`) whenever the `ICONV` table changes.
- **Do not put simplified Chinese in `ICONV`.** `图 → 図` is a cross-orthography
  equivalence rather than a normalisation, so it stays a `st:` row and adds a
  candidate instead of rewriting the query. The boundary: that path yields a
  spelling to look up, not a lemma, so `图らず` does not deinflect to `図る`.

Nor should the table be made bidirectional. `図 → 圖` would double the variants
of every query containing the character, and the dictionaries that would
benefit (headwords in 旧字体/異体字) are proper nouns and old-spelling phrases
that are typed in their own form anyway.

## Encoding: UTF-8 and composed forms

Ciyue's FFI passes every query as UTF-8 and decodes the results as UTF-8; it
does not transcode. Hunspell reads `SET` from the `.aff` and expects the bytes
of the word in that encoding, so only `SET UTF-8` matches Ciyue's input. A
Latin-1 or KOI8-R pair still imports, and ASCII words may work, but non-ASCII
lookups fail. Convert both files to UTF-8 and change the `SET` line. Do not use
the Hunspell CLI to decide whether Ciyue can use a dictionary: the CLI performs
its own iconv conversion and may succeed where Ciyue does not.

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
- **A stock build reports fewer stems for the same files.** Upstream 1.7.6
  keeps both `st:` lines in the table, but `stem()` still takes only the first
  `st:` field of an analysis record, so only the first stem comes back.
  Ciyue's bundled Hunspell returns every `st:` field — see
  [Ciyue's Hunspell build](#ciyues-hunspell-build).

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

