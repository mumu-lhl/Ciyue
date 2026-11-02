# Keyboard shortcuts

Ciyue's shortcuts follow the conventions of [GoldenDict-ng](https://github.com/xiaoyifang/goldendict-ng) and EBWin: the keys you already know from other dictionaries do the same thing here.

Most of them are **desktop only**, because they need a physical keyboard. On Android they are of little use, unless you connect a Bluetooth keyboard.

## Two levels

The dictionary shortcuts work in two levels:

```
Ctrl+`  /  Ctrl+1…9      Groups: which dictionaries a lookup uses
        │
        └── Alt+0…9       Dictionaries: which result you are looking at
                            Alt+0 = AI explanation, Alt+1…9 = the first nine dictionaries
```

## Looking up

| Shortcut | Action |
|---|---|
| `Ctrl`+`F` | Move the focus into the search box |
| `Esc` | Move the focus into the search box **and select the text in it**, so typing replaces the word; press it again to return to the entry |
| `Enter` on a selection | Look up the selected text (see below) |

The wide window has two search boxes: the one in the left column and the one in the title bar of the entry. `Ctrl`+`F` and `Esc` go to the one you used last, so they follow you around the window instead of always landing on the left one.

### Looking up a selection

Select a word or a phrase in the entry and press `Enter` to look it up. This is EBWin's behaviour, and on the desktop it is the only way to look up a word: the right-click menu of the entry is Chromium's own.

Selecting beats double-clicking, because double-clicking only ever selects one part of a word in the languages that do not separate words with spaces:

| Language | Double-click selects | Selecting the phrase gets |
|---|---|---|
| German | `Bundesbank` of `Bundesbankdirektor` | `Bundesbankdirektor` |
| Japanese | `日本` of `日本語词典` | `日本語词典` |
| Chinese | `现代` of `现代汉语词典` | `现代汉语词典` |

On Android the long-press menu offers the same lookup next to *Copy* and *Read aloud*. Right-clicking a word selects it as well, so the menu looks up that word.

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

In the full-screen word list on mobile, `←` / `→` move to the previous / next word.

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

In the **Expansion** style there are no such tabs, and these keys do nothing at all.

## Reading

| Shortcut | Action |
|---|---|
| `Ctrl`+`R` | Read the word aloud — or stop it when it is already playing |
| `Ctrl`+`Shift`+`S` | Stop the playback |
| `Ctrl`+`↑` / `Ctrl`+`↓` | Pick the previous / next entry in the history |

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

## Notes

- The group and dictionary tab shortcuts only act while an entry is on screen.
- On a keyboard where the window manager takes `Alt`+a number, the dictionary tabs cannot be reached that way.
- `Ctrl`+`PgUp` and `Ctrl`+`PgDn` change the word tab; the same keys without `Ctrl` scroll the entry in the expansion layout.
- On the desktop layout the arrow keys move the keyboard focus between controls; `Enter` or `Space` activates the focused one.
