# Getting Started

## Install

### Android

<p>
  <a href="https://github.com/mumu-lhl/Ciyue/releases/latest">
    <img src="https://github.com/NeoApplications/Neo-Backup/raw/034b226cea5c1b30eb4f6a6f313e4dadcbb0ece4/badge_github.png" alt="Get it on GitHub" height="80" />
  </a>
  <a href="https://f-droid.org/packages/org.eu.mumulhl.ciyue/">
    <img src="https://f-droid.org/badge/get-it-on.png" alt="Get it on F-Droid" height="80" />
  </a>
  <a href="https://apps.obtainium.imranr.dev/redirect?r=obtainium://add/https://github.com/mumu-lhl/Ciyue">
    <img src="https://raw.githubusercontent.com/ImranR98/Obtainium/main/assets/graphics/badge_obtainium.png" alt="Get it on Obtainium" height="80" />
  </a>
</p>

Tip: [Obtainium](https://obtainium.imranr.dev/) tracks GitHub releases directly, so you get updates faster than F-Droid, whose builds can lag behind.

### Windows

Download the installer (`ciyue-setup.exe`) or portable ZIP from the [latest release](https://github.com/mumu-lhl/Ciyue/releases/latest).

### Linux

- **Flatpak**: download `ciyue-x86_64.flatpak` from a release and install it with:

  ```bash
  flatpak install --user ./ciyue-x86_64.flatpak
  ```

- **Arch Linux**: install from the [AUR](https://aur.archlinux.org/packages/ciyue) or [archlinuxcn](https://github.com/archlinuxcn/repo/tree/master/archlinuxcn/ciyue) repository:

  ```bash
  yay -S ciyue
  ```

- **AppImage**:
  - via [AppMan](https://github.com/ivan-hc/AppMan) (rootless): `appman -i ciyue`
  - via [AM](https://github.com/ivan-hc/AM): `am -i ciyue`

### macOS

Download the DMG (`ciyue-macos.dmg`) from the [latest release](https://github.com/mumu-lhl/Ciyue/releases/latest).

## Download dictionaries

Ciyue does not ship with dictionaries. See the [recommended dictionaries](https://github.com/mumu-lhl/Ciyue/wiki#recommended-dictionaries) on the Wiki, then add your `.mdx` / `.mdd` files in **Settings → Manage dictionaries**.

## Cloud sync

Keep your wordbook, tags, flashcards, and history in sync across devices. See [Cloud sync setup](./cloud-sync).

## KOReader on Android

Create `dictionaries.lua` under directory `koreader`:

```lua
{
    { "Ciyue", "Ciyue", false, "org.eu.mumulhl.ciyue", "send" }
}
```
