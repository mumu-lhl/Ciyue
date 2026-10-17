# FAQ

## Where do I get dictionaries?

Ciyue does not ship with dictionaries. Download `.mdx` / `.mdd` files from the [recommended dictionaries](https://github.com/mumu-lhl/Ciyue/wiki#recommended-dictionaries) list on the Wiki, then add them in **Settings → Manage dictionaries**.

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
- Some dictionaries need a custom CSS tweak: **Manage dictionaries → dictionary → Custom CSS**.
- If a dictionary crashes the lookup, please [open an issue](https://github.com/mumu-lhl/Ciyue/issues) with the dictionary name.

## How do I use Ciyue with KOReader on Android?

Create a file named `dictionaries.lua` inside the `koreader` directory with:

```lua
{
    { "Ciyue", "Ciyue", false, "org.eu.mumulhl.ciyue", "send" }
}
```

Then look up words from KOReader via the dictionary action.

## Where is my data stored?

- **Android**: the app's private storage (`/data/data/org.eu.mumulhl.ciyue/`); dictionaries default to the app's documents directory, configurable in settings.
- **Windows**: `%APPDATA%\ciyue\`.
- **Linux**: `~/.local/share/ciyue/` (or `~/.var/app/...` for Flatpak).
- **macOS**: `~/Library/Application Support/ciyue/`.

## How can I contribute translations?

Translations are managed on [Weblate](https://hosted.weblate.org/engage/ciyue/). You can add a new language or improve existing translations there — no coding needed.

## I found a bug / have a feature request. Where do I report it?

Open an issue on [GitHub](https://github.com/mumu-lhl/Ciyue/issues). Please include your app version, platform, and steps to reproduce.
