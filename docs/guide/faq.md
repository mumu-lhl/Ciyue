# FAQ

## Where do I get dictionaries?

Ciyue does not ship with dictionaries. Download `.mdx` / `.mdd` files, or StarDict dictionaries (`.ifo` / `.idx` / `.dict`), from the [recommended dictionaries](https://github.com/mumu-lhl/Ciyue/wiki#recommended-dictionaries) list on the Wiki, then add them in **Settings → Manage dictionaries**. For offline encyclopaedic dictionaries (Wiktionary, Wikipedia, Wikisource and more), you can also download `.zim` files from [Kiwix](https://www.kiwix.org/) via the [Kiwix ZIM directory on Wikimedia dumps](https://dumps.wikimedia.org/other/kiwix/zim/).

## Why does Ciyue need the INTERNET permission?

Ciyue uses WebView to render dictionary entries, and WebView requires the INTERNET permission to work — even when displaying local data. The permission is also used for update checks and third-party services you configure (such as an AI provider). Ciyue never initiates network requests on its own.

## The F-Droid version is older than the GitHub release. Why?

F-Droid builds and publishes apps on its own schedule, so its releases can lag behind GitHub by days or weeks. If you want updates as soon as they are published, install via [Obtainium](https://obtainium.imranr.dev/), which tracks GitHub releases directly — tap the Obtainium badge on the [Getting Started](./getting-started) page.

## How do app updates work? What are the update channels?

On **Settings → Check for updates** you can choose an update channel:

- **Stable** — official releases only (recommended for most users).
- **Beta / Alpha** — prereleases with new features that are still being tested.
- **Nightly** — automatic daily builds with the latest changes; may be unstable.

Desktop apps use the same three channels through the built-in updater.

## How do I back up my wordbook and settings?

Go to **Settings → Backup** to export your data (wordbook, history, tags, flashcards, settings) to a file. Keep that file somewhere safe; you can import it later on the same screen. For continuous multi-device sync, see [Cloud Sync](./cloud-sync).

## A dictionary shows garbled or missing content. What can I do?

- Make sure the matching `.mdd` resource file (if the dictionary has one) is placed next to the `.mdx` file with the same base name.
- For a StarDict dictionary, keep its `.ifo`, `.idx`, and `.dict` files together under the same base name.
- Some dictionaries need a custom CSS tweak: **Manage dictionaries → dictionary → Custom CSS**.
- If a dictionary crashes the lookup, please [open an issue](https://github.com/mumu-lhl/Ciyue/issues) with the dictionary name.

## (Linux) The entry area is blank, but the text can still be selected, copied and searched?

The page itself is fine; its frames are just not reaching Flutter. Ciyue picks the rendering mode automatically: virtual machines and some GPU drivers fall back to software rendering, while known good GPUs use hardware acceleration. If the automatic choice takes the wrong path on your GPU, force software rendering:

```bash
CIYUE_RENDER_MODE=software ciyue
```

Other values: `auto` (default, detect automatically) and `hardware` (force hardware acceleration). The lower-level `FLUTTER_INAPPWEBVIEW_SKIP_DMABUF_CHECK=1` and `FLUTTER_INAPPWEBVIEW_LINUX_DISABLE_GL=1` take precedence over `CIYUE_RENDER_MODE`.

If a visible WebView receives no frame within 5 seconds under hardware mode, Ciyue records the failure and **uses software rendering on the next start**, without any manual configuration. The record expires after 7 days so hardware gets another try. To retry immediately, use `CIYUE_RENDER_MODE=hardware ciyue`, which also clears the record. WebViews that were never visible are not counted as failures.

If the area stays blank under software rendering, the rendering mode is not the cause. Reproduce once with `ciyue -l` and report it on [GitHub](https://github.com/mumu-lhl/Ciyue/issues): the `rendering mode=` and `no frame within 5s` lines in the log show which layer stopped receiving frames.

## Only one of my MDX and StarDict dictionaries shows up. Why?

Ciyue identifies a dictionary by its path without the extension, so `foo.mdx` and `foo.ifo` / `foo.idx` / `foo.dict` count as the same dictionary: the MDX file is registered and the StarDict one is skipped. Give them different base names — for example `foo-mdx.mdx` and `foo-stardict.ifo` — to keep both.

## How do I use Ciyue with KOReader on Android?

Create a file named `dictionaries.lua` inside the `koreader` directory with:

```lua
{
    { "Ciyue", "Ciyue", false, "org.eu.mumulhl.ciyue", "send" }
}
```

Then look up words from KOReader via the dictionary action.

## How do I use the floating window with Moon+ Reader?

Enable **Settings → Other → Floating Window** in Ciyue. The window style follows the reader automatically: when the reader sends the position of the selected word (the ColorDict protocol), Ciyue opens a half-screen window on the opposite half of the screen so the word stays visible; without that information it shows the centred card instead. Turning the switch off makes lookups open the main Ciyue window.

To look words up from Moon+ Reader:

1. Select some text; in the menu that appears, tap **More**, then tap **Settings** to open the dictionary settings.
2. Set **Dictionary 1 (single tap on the dictionary button)** or **Dictionary 2 (long press on the dictionary button)** to **深蓝词典|欧路词典|MDict|ColorDict**.
3. Tick **Ciyue** in the dictionary list that appears.

If a different dictionary opens instead, Android has remembered a default for that action: open **Android Settings → Apps → that dictionary app → Open by default → Clear default preferences** and try again.

## Where is my data stored?

- **Android**: the app's private storage (`/data/data/org.eu.mumulhl.ciyue/`); dictionaries default to the app's documents directory, configurable in settings.
- **Windows**: `%APPDATA%\ciyue\`.
- **Linux**: `~/.local/share/ciyue/` (or `~/.var/app/...` for Flatpak).
- **macOS**: `~/Library/Application Support/ciyue/`.

## How can I contribute translations?

Translations are managed on [Weblate](https://hosted.weblate.org/engage/ciyue/). You can add a new language or improve existing translations there — no coding needed.

## I found a bug / have a feature request. Where do I report it?

Open an issue on [GitHub](https://github.com/mumu-lhl/Ciyue/issues). Please include your app version, platform, and steps to reproduce.

## A translation source suddenly stopped working. Why?

The free translation sources use public web endpoints rather than official APIs, so a provider can change or block an endpoint at any time. Disable that source in the translation settings and use the others, or switch to an official API source. See [Translation](./translation) for details.
