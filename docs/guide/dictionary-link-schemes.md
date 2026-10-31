# Dictionary Link Schemes: A Deep Dive

Ciyue supports the link conventions that MDict, Babylon and GoldenDict
dictionaries already use. The [Dictionary Links](./dictionary-links) page lists
the shapes you can *write*. This page explains *why* those rules exist — by
looking at how GoldenDict-ng, MDict and Babylon actually treat them, where
Ciyue goes further, and what a compatible reader must (and must not) support.

## Two layers of schemes

Every link scheme in this ecosystem falls into one of two layers.

**Authored into dictionary files** — what dictionary makers actually write:

| Scheme | Origin | Meaning |
| --- | --- | --- |
| `entry://word` | MDX / MDict | jump to entry `word` |
| `bword://word` | Babylon `.bgl` | same as `entry://word` |
| `gdlookup://localhost/word` | GoldenDict-ng | cross-dictionary lookup of `word` |
| `sound://file` | MDX / Babylon | play audio `file` |

**Generated at runtime by GoldenDict-ng's loaders** — never present in a source
file: `gdau`, `bres`, `gico`, `gdprg`, `gdtts`, `gdinternal`.

GoldenDict-ng registers *both* `bword` and `entry` (and `gdlookup`) as custom
URL schemes and treats them identically: it extracts the headword and looks it
up across all loaded dictionaries (`main.cc` registers the schemes;
`utils.hh` resolves `bword`/`entry`/`gdlookup` the same way). That is why a
single reader can follow either spelling.

### Cross-format mixing only works in GoldenDict-ng

Because each loader only rewrites *its own* scheme, you can build hybrids that
only GoldenDict-ng understands:

- An **MDX that contains `bword://word`**: the MDX loader's link rewriter only
  knows `entry://` and `sound://`; it leaves `bword://` untouched, and the
  global `bword` scheme handler picks it up. Original MDict never sees `bword:`
  and cannot follow it.
- A **Babylon `.bgl` that contains `entry://word`**: the BGL loader only
  normalizes `bword:`, so `entry://` passes through to the global handler.
  Original Babylon does not understand `entry://`.

Even for the "standard" spelling the behavior differs: GoldenDict-ng rewrites
`entry://word` into `gdlookup://localhost/word`, a lookup that spans **all**
loaded dictionaries, whereas MDict's own `entry://` only jumps **within the
current `.mdx`**.

## `sound://` and the StarDict conversion trap

`sound://` is the MDX/Babylon audio convention. In GoldenDict-ng **only the MDX
loader** rewrites `sound://` → `gdau://` (the internal audio scheme). The
StarDict loader does *not* rewrite `sound://`: its link rewriter passes any `a`
link that contains a `:` through untouched, and its `<audio>` handler only
converts sources that have **no** `://` in them. Since `sound` is not a
registered scheme, a `sound://` link surviving into a StarDict file is simply a
dead link.

This is exactly why converting an MDX to StarDict with a tool that keeps the
MDX-style `sound://` links makes the audio stop working: the audio tag is no
longer rewritten. By contrast, `<audio src="relative.wav">` (no `://`) *does*
work in the StarDict loader, because it gets rewritten into `gdau://`.

Practical guidance:

- If a dictionary has MDX audio, just load the original MDX — it is natively
  supported and `sound://` is handled correctly.
- If you must produce StarDict, make the converter emit StarDict-native relative
  resources (a relative `<audio>` source, or the `snd:` resource form) rather
  than MDX-style `sound://` links.

## `gdlookup://localhost/word` — the stable cross-reference

Unlike `gdau://` (below), this form is **stable and portable**:

- `localhost` is a hard-coded constant in GoldenDict-ng's scheme handling; the
  meaningful part is the headword in the path.
- Resolution looks the word up across all loaded dictionaries, so moving,
  renaming, or copying the dictionary file does not matter.
- It is content-addressed, not location-addressed, which means it can be
  hand-authored — and indeed appears in real dictionaries (including some made
  by the Ciyue author).

Ciyue supports it: its entry-URL check accepts `gdlookup` with host
`localhost`.

### Why `localhost` at all?

The original GoldenDict commit `e4e5a969` (Konstantin Isakov, the GoldenDict
author) says it plainly:

> Switch to `gdlookup://localhost/word` scheme in dsl word references. This
> fixes cases with uppercased/capitalized words.

A URL **host** is always folded to lower case by the parser; a **path** is not.
`gdlookup://Word` would arrive as `word`, breaking case-sensitive lookups. The
dummy authority `localhost` exists for one reason: to push the headword into
the **path**, where its case is preserved.

Ciyue rediscovered the same bug and fixed it in the same way. Earlier Ciyue
carried the headword in the host, so `entry://Abend` arrived as `abend`, and
`entry://A.D.` / `entry://tag:sumeru` were parsed as `host:port` and resolved
to nothing (the `:` in `tag:sumeru` is read as the port separator — a pitfall
first hit while building a Genshin dictionary, where links like
`entry://tag:sumeru` are used). The fix moves the word into the path as
`gdlookup://localhost/<percent-encoded>`, which is exactly the shape GoldenDict
uses, for exactly the same reason. Those cases are now permanent regression
tests in Ciyue.

## `gdau://` — why a compatible reader can ignore it

`gdau://<id>/file` looks similar to `gdlookup://` but is fundamentally
different:

- `<id>` is an **MD5 of the dictionary's absolute file path(s)**
  (`makeDictionaryId` in GoldenDict-ng). It changes if the file moves or the
  machine changes.
- `<file>` is the resource name within that dictionary.
- It is resolved by looking the dictionary up *by that id hash*, then fetching
  the resource.

Because the id is a path-derived hash, `gdau://` is **not portable and not
authorable** — you cannot write a `gdau://` link that works anywhere but the
machine/session that produced it. And it is only ever *emitted at runtime* by
GoldenDict-ng's loaders (MDX rewrites `sound://` → `gdau://`; StarDict rewrites
`<audio src="rel">` → `gdau://`). No source dictionary file contains `gdau://`.

So a third-party reader that wants to be a superset of GoldenDict-ng should
support the *authored* layer (`entry`, `bword`, `gdlookup://localhost/…`,
`sound://`) and need not — and should not expect to receive — `gdau://`. Ciyue
uses its own audio plumbing (`sound://` plus a local HTTP server serving the
dictionary's `res/` and `.mdd` resources) instead.

## `#` handling: where Ciyue is a strict superset

For the **anchor** (scroll-to) part, GoldenDict-ng and Ciyue are equivalent:
both carry it as a `?gdanchor=` query parameter rather than a `#` fragment,
precisely so the fragment is not swallowed before the handler sees it.

The difference is what happens when a **special character appears inside the
headword itself**:

- GoldenDict-ng inserts the headword **raw** into the path
  (`gdlookup://localhost/<word>`). A `#` (or `?` or `/`) inside the word becomes
  a fragment/query/path separator and truncates the word; its `gdlookup` +
  fragment branch then falls back to a fragile `window.location = url`.
- Ciyue **percent-encodes every byte** of the headword, so `#` → `%23`,
  `/` → `%2F`, `?` → `%3F` never collide with URL syntax. The word round-trips
  intact (verified by tests such as `a%2Fb` → `a/b` and
  `%74%61%67%3A…` → `tag:sumeru`). Ciyue also rescues a `#` that survives in
  the fragment when the page script did not rewrite the link.

So on the "special characters inside the identifier" axis, Ciyue ⊃
GoldenDict-ng.

## Summary

| Scheme | Authored? | Stable / portable? | GD-ng | Ciyue |
| --- | --- | --- | --- | --- |
| `entry://word` | yes (MDX) | yes | yes | yes |
| `bword://word` | yes (Babylon) | yes | yes | yes |
| `gdlookup://localhost/word` | yes (can be hand-written) | yes (content-addressed) | yes | yes |
| `sound://file` | yes (MDX/Babylon) | yes | MDX loader rewrites → `gdau` | yes (+ local server) |
| `<audio src="rel">` | yes | yes | StarDict loader → `gdau` | yes |
| `gdau://<id>/file` | no (runtime only) | no (path-MD5 id) | yes (internal) | no (own audio mechanism) |
| `bres`/`gico`/`gdprg`/`gdtts`/`gdinternal` | no (runtime only) | no | yes (internal) | no (own resource mechanism) |

**Takeaway.** To be a true superset of GoldenDict-ng at the *dictionary-loading*
layer, support the de-facto authored conventions — `entry`, `bword`,
`gdlookup://localhost/…`, and `sound://`. The GD-internal schemes
(`gdau`, `bres`, `gico`, `gdprg`, `gdtts`, `gdinternal`) are runtime artifacts;
substitute your own resource mechanism for them rather than trying to parse
them.
