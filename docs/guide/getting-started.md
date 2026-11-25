# Getting Started

## Install

Install Ciyue first — see the [Download](/download) page for the latest stable and nightly builds for Android, Windows, Linux, and macOS.

## Download dictionaries

Ciyue does not ship with dictionaries. See the [recommended dictionaries](https://github.com/mumu-lhl/Ciyue/wiki#recommended-dictionaries) on the Wiki, then add your `.mdx` / `.mdd` files, or StarDict dictionaries (`.ifo` / `.idx` / `.dict`), in **Settings → Manage dictionaries**. [Dictionary formats](./dictionary-formats) explains what each of those files is for, and how to convert between the two families.

For offline encyclopaedic dictionaries, you can also grab `.zim` files from [Kiwix](https://www.kiwix.org/): download Wiktionary, Wikipedia and Wikisource from the [Kiwix ZIM directory on Wikimedia dumps](https://dumps.wikimedia.org/other/kiwix/zim/).

## Cloud sync

Keep your wordbook, tags, flashcards, and history in sync across devices. See [Cloud sync setup](./cloud-sync).

## KOReader on Android

Create `dictionaries.lua` under directory `koreader`:

```lua
{
    { "Ciyue", "Ciyue", false, "org.eu.mumulhl.ciyue", "send" }
}
```
