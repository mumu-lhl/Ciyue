---
## [2.2.0](https://github.com/mumu-lhl/Ciyue/compare/v2.1.0..v2.2.0) - 2026-11-11

### Features

- **Search modes** - switch between prefix, suffix, multi-word AND, and full-text search, with a full-text index overview page to check, rebuild, or delete a dictionary's index; the search box has clear and mode buttons, and prefix/suffix use first/last-page icons
- **Collapsible search pane** - the search pane can now be collapsed on large screens, and portrait tablets use the phone layout
- **Wide-screen navigation** - the wide-screen navigation and search box roles are reworked, and the empty new-tab page keeps a search box
- **Mouse gestures on desktop** - rocker gestures now switch dictionary and word tabs on Linux (WPE) and Windows, with the wheel gesture using the left button; gesture actions are configured on the Other settings page
- **Custom right-click menu** - Windows and Linux now use Ciyue's own right-click menu
- **Look up a selection in a new tab** - on desktop, Ctrl+Enter looks up the selected text in a new tab
- **Step through dictionary tabs** - Alt+PgUp/PgDn now steps through dictionary tabs
- **CJK variant stems** - lookups now combine single-character variants, so words written with a variant character are found too
- **StarDict stylesheets** - a stylesheet file named after the dictionary is now loaded automatically
- **Translations** - hardcoded interface strings are now localized, and the Traditional Chinese (Hong Kong/Taiwan) and German translations are complete

### Bug Fixes

- **(shortcuts)** desktop shortcuts now work even when a native control has the focus, and history navigation uses Alt+Up/Down
- **(desktop)** back/forward navigation and the suggestion view are repaired
- **(wordbook)** the word list can now be paged through on desktop
- **(word page)** entries now follow the theme immediately when it flips, including MediaWiki-skinned dictionaries
- **(dictionary)** entries stay visible after a dictionary is toggled off and on again, instead of staying blank
- **(dictionary)** dictionary resources with non-ASCII file names now load with the correct charset
- **(zim)** links to articles inside a ZIM archive now open as entry lookups
- **(linux)** the app icon now shows in taskbars such as XFCE's
- **(linux)** closing a window or releasing an entry view no longer crashes occasionally
- **(linux)** lookups no longer crash on systems using software rendering without a GPU
- **(linux)** the bundle now takes OpenSSL from the host system, so proxy-related features work again on newer distributions like Debian 13
- **(linux)** the WebView is now sized in logical pixels, so entries render at the right size on HiDPI screens

---

## [2.1.0](https://github.com/mumu-lhl/Ciyue/compare/v2.0.1..v2.1.0) - 2026-11-03

### Features

- **Full-text search** - find words by searching inside definitions, with a per-dictionary index built in the background and managed from the dictionary properties page
- **ZIM dictionaries** - Kiwix/ZIM dictionaries can now be added and read, with entry titles resolved correctly
- **Online pronunciation** - pronunciation audio can now come from Wiktionary and Forvo, off by default; enable them in audio settings, with results cached and Forvo requests quota-guarded
- **Native text-to-speech on Linux** - Linux now uses native speech through speech-dispatcher or espeak-ng, with a voice picker and backend status in audio settings
- **Local web service and browser extension** - a local web query service and browser extension let a browser look words up in Ciyue, with dictionary groups, folding, dark mode, and AI explain/translate in the web view
- **Desktop command line and ciyue:// links** - desktop builds accept command-line arguments and `ciyue://` links, including editor integration, with diagnostics and readable file logs
- **Keyboard shortcuts and content zoom** - desktop keyboard shortcuts now cover lookup, tabs, dictionary groups, and entry zoom; the search box keeps focus correctly, and entry text scaling survives a reload on Android
- **Dictionary-group switcher on word pages** - word pages now have a dictionary-group switcher that keeps the previous entry while the new group loads, and the AI chat button is available in the expansion bar
- **Multiple text-to-speech voices** - several text-to-speech voices can now be kept, reordered, and switched, with the active voice shown clearly and long voice names no longer overflowing
- **Long-press pronunciation controls** - long-pressing the speaker on a word page now opens pronunciation settings, reachable on touch screens, with the sheet kept clear of the navigation bar
- **Entry anchors** - links that point to a section inside a dictionary entry now land in the right dictionary and scroll to the right place, with a `##` escape for literal hashes
- **Full-width and half-width lookup variants** - lookups now try full-width and half-width spellings, fold width in search suggestions, and resolve the StarDict headword before reading an entry
- **Hiragana long-vowel suggestions** - when nothing matches, Japanese lookups now also suggest long-vowel spellings
- **StarDict dictionaries in cloud sync** - StarDict dictionaries are now carried through cloud sync like other dictionaries
- **Pronunciation packs in .zip and .zips** - pronunciation packs can now be added as .zip and .zips files, and packs that previously failed to index now work
- **Editable text-to-speech preview** - the text-to-speech preview text in Settings can now be edited
- **Dictionary groups can be reordered** - dictionary groups can now be reordered from the manage-dictionaries page
- **Language names in their own script** - the language list in Settings now shows every language name written in its own script
- **Sidebar dictionary-group icon** - the sidebar toggle now uses the dictionary-group icon
- **Full-dev Android build branding** - the full-dev Android build now has its own app name and purple launcher icon, so it can be told apart from the regular build when both are installed
- **Documentation and translations** - new guides for dictionary formats, dictionary links, keyboard shortcuts, and the command line; the German translation is now complete

### Bug Fixes

- **(android)** dictionaries can now be added from SD-card folders, with a copy fallback when a folder path cannot be resolved
- **(dictionary)** StarDict lookups that ran at the same time could return wrong results; concurrent reads are now serialised
- **(dictionary)** closing a dictionary that never finished loading no longer hangs
- **(dictionary)** healthy StarDict dictionaries are no longer deleted when a file check runs
- **(dictionary)** turning dictionaries on or off while a group is still loading now sticks
- **(lookup)** lookups no longer answer before Hunspell has finished loading, and stale cached results are dropped once a dictionary group has loaded
- **(lookup)** looking up a sentence finds its phrasal verb more reliably, and long German compound words split correctly again
- **(stardict)** sound links inside StarDict entries now play, and audio and video embedded by dictionary converters play again
- **(linux)** the app now shows its icon in the taskbar and tray, and is mapped to its desktop file
- **(linux)** dictionary entries render correctly on systems using the VirGL software renderer
- **(linux)** the Linux bundle now takes Wayland, GLib/GStreamer, and GTK from the host system, so desktop input methods work and host-coupled library conflicts go away
- **(windows)** clicking dictionary entry and sound links now works through the JavaScript bridge
- **(windows)** on Windows without the WebView2 runtime, Ciyue now prompts to install it at startup instead of failing
- **(word page)** the "not found" page now refreshes when the dictionary group changes
- **(settings)** settings segmented buttons no longer squeeze list-tile titles, and fall back to what fits when they run out of room
- **(settings)** the Gothic translation no longer shows an empty box where the back button and navigation bar should be, its labels no longer overflow their controls, and "Gothic" is named in Gothic in the language list
- **(settings)** a long translation no longer breaks the main page navigation bar
- **(word page)** the word page now uses a plain back button

---
## [2.0.1](https://github.com/mumu-lhl/Ciyue/compare/v2.0.0..v2.0.1) - 2026-10-29

### Features

- **Not-found suggestions** - when a lookup misses, the page now suggests spellings, readings of the word as several headwords, and phrasal verbs a phrase may be hiding
- **Dictionary resources from zip archives** - StarDict images can live in a `res.zip` archive next to the dictionary, and audio packs can be shipped as `.zip` files alongside `.mdd` files, with no need to unzip anything by hand
- **Lookup variants** - lookups now try the spellings a dictionary might actually store, including case and kana variants, so a word is found however it is capitalized or written
- **WebDAV over plain HTTP** - cloud sync now accepts WebDAV servers over plain HTTP, so local and LAN servers work
- **Documentation and translations** - the About page now links to the documentation site, with new guides for word-form lookup, appearance, and pronunciation; the Chinese translation is now complete

### Bug Fixes

- **(android)** fixed the window staying black after returning to the foreground on Mali devices; Impeller is disabled until the upstream engine fix lands
- **(floating window)** fixed the black screen on a second process-text lookup and the previous word showing instead of the new one
- **(word page)** fixed dictionary links, resource paths, and audio playback: links open the right word, files placed next to a dictionary resolve, pronunciations that cannot be played explain why, and dead links land on the "not found" page
- **(lookup)** words that look identical but are stored differently, such as accented characters, now match consistently across history, the wordbook, and Hunspell, instead of creating duplicate rows for the same visible word
- **(dictionary)** importing a dictionary now says why it failed, including LZO-compressed files, which need to be converted first; StarDict dictionaries with compressed indexes now import; the Hunspell page shows which word lists failed to load and why
- **(dictionary)** adding a dictionary group no longer falsely reports failure
- **(settings)** the last row of settings pages is no longer hidden under the system navigation bar
- **(cloud sync)** the wordbook now refreshes after rebinding and syncing, and the rebind button label is translated
- **(windows)** caption buttons are visible in light mode, and word pages update in place instead of keeping stale content
- **(f-droid)** fixed the reproducible build so F-Droid can ship the update

---

## [2.0.0](https://github.com/mumu-lhl/Ciyue/compare/v1.23.2..v2.0.0) - 2026-10-24

### Features

- **Multi-source translation** - translate with many sources side by side: free online services, key-based services, and any of your AI providers, each with its own result card; enable, disable, and reorder sources freely
- **AI chat, upgraded** - multiple conversations, streaming replies, questions with attached images, image generation, a dedicated page for managing custom prompts, and clear errors when the AI provider is not configured yet; adds the Agnes AI provider
- **A real review loop for learning** - wrong quiz answers are collected in a mistake book and can be re-quizzed offline; quizzes gain choice, spelling, and cloze question types; scenario practice, and read-aloud in quizzes and chat
- **StarDict dictionaries** - add StarDict dictionaries (.ifo/.idx/.dict/.dz) just like MDict ones; entries render natively in the app theme, and HTML entries still open in the WebView
- **Pronunciation, redone** - choose packs first, packs only, or TTS only; TTS speech rate and pitch with a preview; see how many entries each pronunciation pack contains; packs keyed by .mp3/.wav audio now play as well
- **Update channels** - switch between Stable, Beta, and Nightly in settings
- **Desktop word pages** - back and forward navigation buttons
- **Refreshed settings** - settings and dictionary management pages rebuilt with a cleaner card layout
- **Structured word explanations** - AI word explanations now follow a fixed structure and render natively in the app theme, falling back to plain text when a model does not follow the structure

### Bug Fixes

- **(linux)** fixed WebView flickering, black screens, rendering corruption on hardware GPUs, and WebProcess crashes; the built-in WebKit runtime was upgraded
- **(dictionary)** fixed group counts not refreshing, ghost rows left after deleting a dictionary, and missing error feedback when toggling dictionaries
- **(translation)** fixed repeated translation taps charging paid sources twice, and stale results after switching languages
- **(word page)** fixed word pages stacking endlessly when searching from a word page, and tab history falling out of sync
- **(settings)** fixed a batch of stale-state and data bugs across settings, word pages, and the wordbook; fixed hunspell lookup races
- **(f-droid)** restored F-Droid builds
- **(word page)** fixed dictionary entries ignoring the app's dark theme inside the WebView; external .css/.js files placed next to a dictionary now override the copies inside it
- **(floating window)** the floating window no longer disappears after 30 idle seconds; the lookup engine stays alive and is only released under memory pressure

### Performance

- **Lookup** - dictionaries are queried in parallel and search suggestions are debounced, so results arrive faster without flicker
- **Startup and history** - faster startup, and history is now indexed and updated incrementally
- **Word pages** - far fewer WebView relayouts, so scrolling and resizing are smoother
- **Dictionary import** - dictionary indexes are now stored as a compact binary file instead of JSON, so opening a cached dictionary is several times faster on large dictionaries; StarDict lookups no longer load the whole word list into memory

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
