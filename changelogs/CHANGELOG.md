---
## [1.23.2](https://github.com/mumu-lhl/Ciyue/compare/v1.23.1..1.23.2) - 2026-09-19

### Bug Fixes

- **(android)** stabilize floating window - ([48dd2f4](https://github.com/mumu-lhl/Ciyue/commit/48dd2f43f2ffc1de0318808b367bc1868b1b2319)) - Mumulhl
- **(android)** harden floating lookup - ([08d7954](https://github.com/mumu-lhl/Ciyue/commit/08d7954e33399772a5a77a3e1a92b7119f9263d5)) - Mumulhl
- **(android)** stabilize repeated floating lookups - ([ecbde06](https://github.com/mumu-lhl/Ciyue/commit/ecbde0645b06389686c6bc0f088f35f94423e829)) - Mumulhl
- **(android)** pop floating lookup routes - ([dc244ab](https://github.com/mumu-lhl/Ciyue/commit/dc244ab0b4d9787f30e0fddde3ddbd7ce0631bae)) - Mumulhl
- **(android)** close floating window at root - ([de2a5b3](https://github.com/mumu-lhl/Ciyue/commit/de2a5b30a1bb328ee22e5801f1338d625aa50468)) - Mumulhl
- **(android)** support floating edge back - ([619d87c](https://github.com/mumu-lhl/Ciyue/commit/619d87c06cbb86feb356858c1d5fc7c81d8b9586)) - Mumulhl
- **(android)** align floating WebView theme - ([2452e45](https://github.com/mumu-lhl/Ciyue/commit/2452e454fa9bb993a4f155610798fd503f9aa0d7)) - Mumulhl
- **(android)** fix floating window letterboxing and ANR in multi-window environments - ([7e88cea](https://github.com/mumu-lhl/Ciyue/commit/7e88cead708b213bb7fd80726f5eab3a9dae5176)) - Mumulhl
- **(hunspell)** link Android C++ runtime - ([164ec4c](https://github.com/mumu-lhl/Ciyue/commit/164ec4cbc8f26f264a6d269a484e196b38d98068)) - Mumulhl
- **(hunspell)** support multiple st: stems and preserve homonyms (#729) - ([e4c117d](https://github.com/mumu-lhl/Ciyue/commit/e4c117d2dfbb3fea9bb1060d74215725e8fdfce9)) - Mumulhl
- **(i18n)** localize Hunspell settings - ([941637b](https://github.com/mumu-lhl/Ciyue/commit/941637bc48e373ca9fa996b04bb6e18a8c6dac15)) - Mumulhl
- **(linux)** resolve WPE runtime paths absolutely - ([784ac48](https://github.com/mumu-lhl/Ciyue/commit/784ac488bbce157cb74b1183b28cd00f53a900a8)) - Mumulhl
- **(linux)** resolve bubblewrap sandbox paths and fallback on Debian (#733) - ([8ef58ed](https://github.com/mumu-lhl/Ciyue/commit/8ef58edfbbaf2fee2fb6b7543f39ede80fd25fa5)) - Mumulhl
- **(linux)** exclude host graphics stack to resolve Debian driver paths (#734) - ([064ce69](https://github.com/mumu-lhl/Ciyue/commit/064ce699185b4a507bd098c025992ad34c5f9540)) - Mumulhl
- **(lookup)** handle redirects and spell suggestions - ([c16c068](https://github.com/mumu-lhl/Ciyue/commit/c16c068199d703d23c8afa2d19987ff96ca3961b)) - Mumulhl
- **(mdict)** resolve @@@LINK records - ([97cf247](https://github.com/mumu-lhl/Ciyue/commit/97cf247a3d5db250472622e9691e21cf91189933)) - Mumulhl
- **(webview)** encode Unicode entry links - ([a28263f](https://github.com/mumu-lhl/Ciyue/commit/a28263f6cd9b8e557b392f593fff9f95231fe667)) - Mumulhl
- **(word-display)** improve lookup navigation - ([70970da](https://github.com/mumu-lhl/Ciyue/commit/70970da8a48ea9a0d3b53e1f02cfe4acfb8e041e)) - Mumulhl
- **(word-display)** bound desktop webviews - ([0d4b404](https://github.com/mumu-lhl/Ciyue/commit/0d4b40424ee8090298a4628d7179d9fe57457cab)) - Mumulhl

### Features

- **(desktop)** scan dictionary folders - ([c89b35b](https://github.com/mumu-lhl/Ciyue/commit/c89b35b26abe0bd45644bf39fec61c571efab392)) - Mumulhl
- **(hunspell)** add two-pass lookup option per dictionary (#729) - ([e9094ff](https://github.com/mumu-lhl/Ciyue/commit/e9094fffec42f15d01183cf117344d1318b9019b)) - Mumulhl
- **(hunspell)** support splitting phrases into words and combining stems (#732) - ([3ea6387](https://github.com/mumu-lhl/Ciyue/commit/3ea638767045a19da501d2dcd91f5d831a883dce)) - Mumulhl
- **(macos)** add macOS platform support - ([660f930](https://github.com/mumu-lhl/Ciyue/commit/660f93070e5fec3df4704ff7deeb213e2697d3c4)) - Mumulhl
- **(search)** label spelling suggestions - ([3bd6348](https://github.com/mumu-lhl/Ciyue/commit/3bd6348bbb7ae5c94ee921c9820f08e3f4a82f30)) - Mumulhl
- **(settings)** move hunspell entry to root settings page below flashcards - ([966b252](https://github.com/mumu-lhl/Ciyue/commit/966b2521a65480fe219e9333ab56955d86938488)) - Mumulhl
- **(translation)** translated using Weblate (Russian) - ([404a4fa](https://github.com/mumu-lhl/Ciyue/commit/404a4fa91d16cd8aad300504158f7d773f667981)) - Xapitonov

---
## [1.23.1](https://github.com/mumu-lhl/Ciyue/compare/v1.23.1-beta.2..v1.23.1) - 2026-08-31

### Bug Fixes

- **(linux)** route custom URL schemes to the correct WebView - ([bdff522](https://github.com/mumu-lhl/Ciyue/commit/bdff5229bbdda45d47c4e72433cf83377b140047)) - Mumulhl
- **(settings)** show the title on the history page - ([d797cd9](https://github.com/mumu-lhl/Ciyue/commit/d797cd98a3626e4514d68c4d2976f850d07a90b5)) - Mumulhl
- **(translation)** complete the Simplified and Traditional Chinese translations - ([ee55edd](https://github.com/mumu-lhl/Ciyue/commit/ee55edd1b277afb7fad7827fd970ad3ecd95c192)) - Mumulhl

### Features

- **(hunspell)** add optional morphology lookup - ([cbea448](https://github.com/mumu-lhl/Ciyue/commit/cbea448bb4a454663ba8d7d4b3d3d21c71e32bde)) - Mumulhl

---
## [1.23.0](https://github.com/mumu-lhl/Ciyue/compare/v1.22.2..v1.23.0) - 2026-08-28

### Bug Fixes

- **(android)** update compile sdk - ([641379f](https://github.com/mumu-lhl/Ciyue/commit/641379fc09e0582b69f736f8b5864ae5fd8045cf)) - Mumulhl
- **(dictionary)** load indexes in background - ([a2d8758](https://github.com/mumu-lhl/Ciyue/commit/a2d87582f4befc30595400dc5534d85babcac6cc)) - Mumulhl
- **(linux)** restore WebView rendering (#715) - ([fec7ed8](https://github.com/mumu-lhl/Ciyue/commit/fec7ed81be066e1e92acae43fd4e495698123544)) - Mumulhl
- **(linux)** preserve AppImage data paths - ([81b9ca9](https://github.com/mumu-lhl/Ciyue/commit/81b9ca93cffc7902c047d9ba8a443a30643e5783)) - Mumulhl
- lower Linux release glibc baseline (#700) - ([96690a6](https://github.com/mumu-lhl/Ciyue/commit/96690a6e2e5bfc05cb8473380f659641a7bd6076)) - Mumulhl
- add keybinder deb dependency (#701) - ([7449737](https://github.com/mumu-lhl/Ciyue/commit/7449737d723b49246f4cee3d3a0122209cbbf00)) - Mumulhl
- support Flutter 3.47.2 builds - ([467d316](https://github.com/mumu-lhl/Ciyue/commit/467d316fb9a98fd03df8e172c09a1d1545371ffa)) - Mumulhl

### Features

- **(flashcards)** add spaced repetition (#714) - ([b087271](https://github.com/mumu-lhl/Ciyue/commit/b087271f5d81c702d92e0c0d6810042917bdfb9f)) - Mumulhl
- **(translation)** translated using Weblate (Chinese (Traditional Han script)) (#698) - ([e08f401](https://github.com/mumu-lhl/Ciyue/commit/e08f40168589fff9a3220b15d4244bd76bdcb386)) - Weblate (bot)
