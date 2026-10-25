# Dictionary appearance (theme, background, custom CSS)

Dictionary entries are rendered in a WebView, so their colours come from the
dictionary's own CSS. Ciyue decides how dark mode is applied, but it cannot know
what colours a particular `.mdx` hard-codes — which is why the same dictionary
can look right on one device and unreadable on another.

## How dictionary pages follow the theme

Ciyue follows the **app** theme, not the system theme. At document start it
injects a class on the page root:

```html
<html class="ciyue-dark">   <!-- app theme is dark -->
```

The WebView's own `prefers-color-scheme` follows the **operating system**, so a
dictionary cannot use it to track Ciyue's theme. If you write CSS for a
dictionary, key it on `html.ciyue-dark` instead:

```css
html.ciyue-dark { /* ... */ }
```

This distinction matters whenever the app theme and the system theme disagree —
for example, a system in light mode with Ciyue forced to dark.

## If a dictionary is unreadable in dark mode

Typical symptoms: black text on a black background, a white block in an
otherwise dark page, or colours that look "inverted twice".

The cause is a dictionary that sets explicit colours with `!important`
(`background: #fff !important; color: #000 !important`). Chromium's automatic
darkening re-maps a page's *computed* colours, but an explicit `!important`
declaration wins, so the background may end up dark while the text stays black.
How well this works depends on the WebView build shipped by the device, which is
why behaviour differs between stock Android and vendor ROMs.

### Fix: one small block of CSS

Append this to the dictionary, scoped to the app's dark mode. It only changes
colours — never layout, and never `filter: invert(...)`, which fights the
automatic darkening and produces the "double inverted" look.

```css
/* Ciyue dark patch — only active while the app is in dark mode. */
html.ciyue-dark body {
  background: #17191d !important;
  color: #e6e6e6 !important;
}

html.ciyue-dark a { color: #79b8ff !important; }

html.ciyue-dark table,
html.ciyue-dark td,
html.ciyue-dark th,
html.ciyue-dark hr { border-color: #3b4048 !important; }

/* Keep images from being inverted or given a light plate. */
html.ciyue-dark img,
html.ciyue-dark svg { background: transparent !important; filter: none !important; }
```

Two places to put it:

1. **Next to the dictionary** — create `<dictionary file name>.css` beside the
   `.mdx` (for `daijirin.mdx`, that is `daijirin.css`). An external file
   **overrides the copy inside the `.mdd`**, so you do not have to repack the
   resource file. This is the right place for per-dictionary fixes.
2. **Settings → Appearance → Custom CSS** — a single global stylesheet injected
   after every dictionary's CSS, so it can override `!important` rules. It
   applies to *all* dictionaries; scope it with a selector if you only want it
   to affect one.

### Check which theme the page sees

Paste this into Custom CSS temporarily:

```css
html.ciyue-dark { border-top: 8px solid lime !important; }
```

A green bar at the top means the page is in dark mode as far as Ciyue is
concerned. No bar means the app is in light mode, and the dark rules above will
not apply.

## Settings that affect rendering

**Dictionary background colour** — overrides the page background with a colour
you pick (eight presets plus a custom picker, or *Use default*). Prefer leaving
it on *Use default*: a fixed colour wins over the dictionary's own background
and can hide text in the opposite theme. On Windows, leaving it unset while in
dark mode without Dark Reader falls back to a white page.

**Light/dark handling (Windows and Linux only)** — when the app is dark, Ciyue
can run [Dark Reader](https://darkreader.org/) inside the page as a JavaScript
transform. It is disabled while a custom dictionary background colour is set,
because the two would fight over the same colours. On Android and macOS this
option does not exist; Chromium's built-in automatic darkening is used instead.

**Custom CSS** — see above. Because it is injected last, it is the most reliable
way to fix a dictionary you cannot edit (for example one whose resources are
inside an `.mdd`).

## Platform differences

| Platform | Dark mode mechanism | Notes |
| --- | --- | --- |
| Android (stock WebView) | Chromium automatic darkening | Usually correct; dictionaries with hard-coded colours may still need the patch above |
| Android (vendor ROM, e.g. HarmonyOS 3) | Same API, different WebView build | Automatic darkening can leave text black while the background is darkened — apply the `html.ciyue-dark` patch |
| Windows | Dark Reader (optional) | Without Dark Reader and without a custom background, the page stays white in dark mode |
| Linux / macOS | Dark Reader (optional) | Automatic darkening is available as well |

## See also

- [Word-Form Lookup](./word-forms) — lemma resolution and Hunspell setup.
- [FAQ](./faq) — missing resources, garbled entries.
