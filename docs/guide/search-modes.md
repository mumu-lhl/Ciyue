# Search modes

The search bar can look up words in four different ways. Tap the **mode
button** — it sits at the right edge of the search bar, and also in the
expanded search view next to the clear (✕) button — to cycle through them.
The current mode is shown by its icon, and on long-press by a tooltip such
as "Search mode: Prefix". Your choice is saved and restored the next time
you open Ciyue.

The four modes, in cycle order:

| Mode | Icon | Matches | Needs the full-text index? |
| --- | --- | --- | --- |
| Prefix (default) | ⏮ | Headwords **starting with** your query. | No |
| Suffix | ⏭ | Headwords **ending with** your query. | Yes |
| Multi-word | 🔗 | Headwords containing **every** term you type, not necessarily adjacent. | Yes |
| Full text | 🔍 | Text **inside definitions**, not just headwords. | Yes |

## Prefix — the default

Headwords that begin with what you type, e.g. `app` → `apple`, `application`.
This is the original Ciyue behaviour and needs no setup: it works as soon as
a dictionary is loaded.

## Suffix — a reverse dictionary

Headwords that **end** with your query, so you can look a word up by its tail.
This is the reverse-dictionary / 倒序词典 idea: if you can only remember the
ending — say you want a word ending in "动" (movement) but can't recall 翕动 —
typing 动 lists 按兵不动, 摆动, 半自动, 暴动, 被动 … and you pick the one you
meant.

Suffix matching is served by a reversed-headword column added to the
full-text index, so it needs that index (see below).

## Multi-word — combine terms

Headwords that contain **all** the characters you type, in any order and not
necessarily next to each other. Search `中国` (or `中 国`) and the suggestions
include 中国 (adjacent, in order), 国中 (adjacent, reversed), 中国通 and
大秦景教流行中国碑 (both containing the adjacent pair 中国), and 中立国,
中华民国鄂州约法, 中华民国北伐铁血团 (with other characters in between).
Every headword holds both characters, but they need not be adjacent or in
order — an intent neither prefix nor suffix matching can express.

## Full text — search the definitions

Matches your query **inside the definitions**, not just the headwords. Type a
concept or a phrase and Ciyue lists every entry whose article mentions it,
with a snippet of the surrounding text. This is the same engine as the
standalone "Search in definitions" results, now available directly in the
search bar.

## The full-text index

Suffix, Multi-word and Full text all read from the **full-text index** that
Ciyue builds per dictionary. Prefix does not use it.

When you first use one of those three modes, Ciyue starts building the index
in the background — the same build the full-text page runs. Until an index is
ready, the search bar shows a status row instead of results:

- **Building…** — the index is being created; results appear once it finishes.
- **Index not built** — tap it to open the full-text page, where the build
  runs and reports progress.
- **Index failed** — tap it to retry from the full-text page.

You can also build and manage every dictionary's index at once from
**Settings → Manage Dictionaries → the index-overview icon**, which lists
each dictionary's status, on-disk size and build / cancel / rebuild actions.

## See also

- [Word-Form Lookup](./word-forms) — resolve inflected forms to their lemma.
- [Getting Started](./getting-started) — add dictionaries.
- [Issue #824](https://github.com/mumu-lhl/Ciyue/issues/824) — the proposal
  that introduced search modes.
