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

How many lemmas come back depends entirely on the Hunspell files you use — when
a form really has several stems, all of them are listed. For Japanese the stems
are kana, with the kanji form shown in parentheses.

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

**Japanese behaves oddly from a shell.** `hunspell -m` (the CLI) drops CJK text
while analysing, e.g. it reports `しかった st:しかる` for `美味しかった`, while the
library API used by Ciyue and GoldenDict correctly returns `st:美味しい`. **When
testing, write a small C++ program that calls the Hunspell API directly — do not
use the command-line `hunspell`.** A ready-made harness is in
[Testing a dictionary directly](#testing-a-dictionary-directly).

## Testing a dictionary directly

For English and German the command-line tool is enough:

```bash
hunspell -d ./en_US -s <<< "hoped"        # -> hope
hunspell -d ./de_DE -s <<< "abgekämpft"   # -> abkämpfen
```

Japanese is the case that needs a direct call: the CLI and the library do not
behave identically there, so the reliable way to see what a `.aff`/`.dic` pair
returns is to call `analyze()` yourself — the same function Ciyue and GoldenDict
use.

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

    // The entry point GoldenDict uses. `hunspell -m` wraps it as well,
    // but its output path is what mangles CJK text.
    std::vector<std::string> results = hunspell.analyze(argv[3]);

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

The output uses Hunspell's own format, e.g. `st:美味しい fl:XQ fl:Ta`, where
`st:` is the stem that word-form lookup will use.

</details>

## See also

- [FAQ](./faq) — dictionary and rendering problems.
- [Getting started](./getting-started) — adding dictionaries.
