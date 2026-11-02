# 快速上手

## 安装

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

小提示：[Obtainium](https://obtainium.imranr.dev/) 直接跟踪 GitHub releases，更新比 F-Droid 快（F-Droid 的构建发布会有延迟）。

### Windows

从 [latest release](https://github.com/mumu-lhl/Ciyue/releases/latest) 下载安装包（`ciyue-setup.exe`）或绿色版 ZIP。

### Linux

- **Flatpak**：从 release 下载 `ciyue-x86_64.flatpak` 后安装：

  ```bash
  flatpak install --user ./ciyue-x86_64.flatpak
  ```

- **Arch Linux**：从 [AUR](https://aur.archlinux.org/packages/ciyue) 或 [archlinuxcn](https://github.com/archlinuxcn/repo/tree/master/archlinuxcn/ciyue) 仓库安装：

  ```bash
  yay -S ciyue
  ```

- **AppImage**：
  - 通过 [AppMan](https://github.com/ivan-hc/AppMan)（免 root）：`appman -i ciyue`
  - 通过 [AM](https://github.com/ivan-hc/AM)：`am -i ciyue`

### macOS

从 [latest release](https://github.com/mumu-lhl/Ciyue/releases/latest) 下载 DMG（`ciyue-macos.dmg`）。

需要 macOS 12 (Monterey) 或更高版本。DMG 是通用二进制，Apple Silicon 和 Intel Mac 都能运行。开机自启动需要 macOS 13 (Ventura) 或更高版本；在 macOS 12 上该开关不生效。

## 下载词典

词悦不自带词典。从 Wiki 的[推荐词典](https://github.com/mumu-lhl/Ciyue/wiki#recommended-dictionaries)下载 `.mdx` / `.mdd` 文件，或者 StarDict 词典（`.ifo` / `.idx` / `.dict`），然后在 **设置 → 管理词典** 中添加。[词典格式](./dictionary-formats) 说明了这些文件各自的作用，以及两种格式之间如何转换。

## 云同步

在多设备间同步单词本、标签、抽认卡和历史记录。见[云同步设置](./cloud-sync)。

## Android 上的 KOReader

在 `koreader` 目录下创建 `dictionaries.lua` 文件：

```lua
{
    { "Ciyue", "Ciyue", false, "org.eu.mumulhl.ciyue", "send" }
}
```
