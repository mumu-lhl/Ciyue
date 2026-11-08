# Keyboard shortcuts

Ciyue's shortcuts follow the conventions of [GoldenDict-ng](https://github.com/xiaoyifang/goldendict-ng), [EBWin](https://ebstudio.info/manual/EBWin4/EBWin4.html) and [EBMac](https://ebstudio.info/manual/EBMac/index.php): the keys you already know from other dictionaries do the same thing here.

Most of them are **desktop only**, because Flutter on Android has trouble keeping the focus needed to trigger a keyboard shortcut. On Android, apart from a few shortcuts, most cannot activate reliably because the focus gets lost. Fortunately, the Android devices that actually use a keyboard are few — only UMPCs like the GPD Win Max or OneXPlayer running Waydroid, and some Android tablets and phones with a built-in keyboard. And on a UMPC you can use the desktop build anyway.

## Two levels

The dictionary shortcuts work in two levels:

```
Ctrl+`  /  Ctrl+1…9      Groups: which dictionaries a lookup uses
        │
        └── Alt+0…9       Dictionaries: which result you are looking at
                            Alt+0 = AI explanation, Alt+1…9 = the first nine dictionaries
                            Alt+PgUp / Alt+PgDn = previous / next dictionary tab
```

## Looking up

| Shortcut | Action |
|---|---|
| `Ctrl`+`F` | Move the focus into the search box |
| `Esc` | Move the focus into the search box **and select the text in it**, so typing replaces the word; press it again to return to the entry |
| `Enter` on a selection | Look up the selected text (see below) |
| `Ctrl`+`Enter` on a selection | Look it up in a new tab, the way `Ctrl`+click does for a link |

The wide window has two search boxes: the one in the left column and the one in the title bar of the entry. `Ctrl`+`F` and `Esc` go to the one you used last, so they follow you around the window instead of always landing on the left one.

### Looking up a selection

Select a word or a phrase in the entry and press `Enter` to look it up. This is EBWin and EBMac's behaviour, and on the desktop it is currently the only way to look up a selected word: the entry's right-click menu is Chromium's own, offering only *Copy* and *Inspect Element*.

Selecting and pressing Enter beats double-clicking a single word, because in languages that do not separate words with spaces what a double-click selects is down to luck; and even in a language like English you sometimes meet compound words and phrasal verbs that a double-click cannot catch:

| Language | Word to look up | A single click selects the whole word |
|---|---|---|
| German | `Bundesbank` within `Bundesbankdirektor` | `Bundesbankdirektor` |
| Japanese | `日本語` within `日本語辞典` | `日本語辞典` |
| Chinese | `汉语` within `现代汉语词典` | `现代汉语词典` |
| English | `throw away` | `throw` or `away` |

On Android, the long-press menu also offers the same lookup next to *Copy* and *Read aloud*; right-clicking a word selects it as well, and the menu's *Query* item looks up that word.

## Tabs

Ciyue has three kinds of tabs, and they are easy to mix up.

### Word tabs

The browser-like tabs at the top hold one word each.

| Shortcut | Action |
|---|---|
| `Ctrl`+`T` | Open a new tab |
| `Ctrl`+`W` | Close the current tab |
| `Ctrl`+`Tab` | Go to the next tab |
| `Ctrl`+`Shift`+`Tab` | Go to the previous tab |
| `Ctrl`+`PgDn` / `Ctrl`+`PgUp` | Go to the next / previous tab |

When the entry was opened from a word list, `←` / `→` move to the previous / next word. This holds on the desktop too, not only in the full-screen list on mobile.

### Dictionary groups

A group decides which dictionaries a lookup uses. The groups are listed in the menu at the top of the window, in the order they were created, and the shortcuts follow that order.

| Shortcut | Action |
|---|---|
| `Ctrl` + backquote | Switch to the first group, the default one |
| `Ctrl`+`1` … `Ctrl`+`9` | Switch to the second to the tenth group |

A number that names no group does nothing. After the switch, the word on screen is looked up again with the dictionaries of the new group.

### Dictionary tabs

When the dictionary switch style is **Tabs**, every dictionary gets a tab in the entry. The numbers pick one of them.

| Shortcut | Action |
|---|---|
| `Alt`+`1` … `Alt`+`9` | Show the first to the ninth dictionary |
| `Alt`+`0` | Show the AI explanation, when it is enabled |
| `Alt`+`PgUp` | Show the previous dictionary tab |
| `Alt`+`PgDn` | Show the next dictionary tab |

Stepping wraps around at either end, the way word tabs do with `Ctrl`+`Tab`. The AI tab is part of the cycle when the explanation is enabled, and stepping reaches dictionaries past the ninth, which the number keys cannot name.

In the **Expansion** style there are no such tabs, and these keys do nothing at all.

## Reading

| Shortcut | Action |
|---|---|
| `Ctrl`+`R` | Read the word aloud — or stop it when it is already playing |
| `Ctrl`+`Shift`+`S` | Stop the playback |
| `Alt`+`↑` / `Alt`+`↓` | Pick the previous / next entry in the history |
| `Alt`+`←` / `Alt`+`→` | Go back / forward through the history of the entry |
| `PgDn` / `PgUp` | Page through the entry, in the expansion layout |

## Zooming the entry

| Shortcut | Action |
|---|---|
| `Ctrl`+= / `Ctrl`++ | Enlarge the entry |
| `Ctrl`+- | Shrink the entry |
| `Ctrl`+`0` | Back to the normal size |

Only the entry is scaled, the rest of the window keeps its size. The level is remembered between restarts, and [Appearance](/guide/appearance) has a slider for it.

`Ctrl`+= and `Ctrl`++ are the same key on most keyboards; both are bound, so either works.

## Other pages

| Shortcut | Action | Where |
|---|---|---|
| `Ctrl`+`Enter` | Translate the text | Translation |
| `Ctrl`+`Enter` | Check the text | Writing Check |
| `Space` | Show the answer | Flashcards |
| `1` … `4` | Rate the card | Flashcards |

## Mouse gestures (desktop)

Two mouse gestures switch tabs while reading an entry. **Settings → Appearance** lets each gesture be assigned its own action: off, switch dictionary tabs, or switch word tabs.

| Gesture | How | Default action |
|---|---|---|
| Rocker | Hold the **left** button and click the **right** one | Next dictionary tab |
| Wheel | Hold the **left** button and scroll up / down | Previous / next word tab |

Both gestures start by holding the left button: clicking the right one is a rocker, scrolling is a wheel gesture, and the two do not conflict. The left button is used instead of the middle one because the middle button is usually the wheel itself — holding it down while scrolling is awkward.

Rocker only has this one direction: dictionary tabs wrap around, so a few presses cycle back to the start. The wheel gesture is bidirectional, which suits moving back and forth through a longer list of word tabs.

In the **Expansion** style there are no dictionary tabs, so that action falls back to switching word tabs instead of doing nothing.

- Windows, Linux and macOS only; Android has no right button or wheel.
- An ordinary right click is untouched — the context menu is suppressed only while the left button is held. On macOS `Ctrl`+left click is a system-level right click and is excluded from the gesture.
- Wheel events are throttled so one physical scroll does not jump several tabs, and the page's own scrolling is stopped while the left button is held.
- The click that follows a gesture is swallowed, so it cannot open a dictionary link by accident.

## Notes

- The group and dictionary tab shortcuts only act while an entry is on screen.
- On a keyboard where the window manager takes `Alt`+a number, the dictionary tabs cannot be reached that way.
- `Ctrl`+`PgUp` and `Ctrl`+`PgDn` change the word tab, while `Alt`+`PgUp` and `Alt`+`PgDn` change the dictionary tab; the same keys without a modifier scroll the entry in the expansion layout.
- Shortcuts with a modifier also fire while the entry's native WebView holds the focus, regardless of which control is focused. Bare `PgUp` / `PgDn` still belong to the entry's scrolling and to text fields.
- History navigation uses only `Alt`+`↑` / `↓`: macOS Mission Control takes `Ctrl`+`↑` / `↓`, while window tiling on KDE, GNOME and Windows takes `Super` / `Win`+`↑` / `↓`. `Alt` is the pair every mainstream desktop leaves free. Inside a macOS text field `Option`+`↑` / `↓` moves to the paragraph start / end, so Ciyue yields to the field while it has the focus.
- On the desktop layout the arrow keys move the keyboard focus between controls; `Enter` or `Space` activates the focused one.
