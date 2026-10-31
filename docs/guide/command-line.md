# Command Line and ciyue:// Links

The desktop builds (Linux, macOS, and Windows) accept command line arguments and `ciyue://` links. Start a lookup from a terminal, a script, or a browser without opening the app first.

## Look up a word

```bash
ciyue hello
ciyue "break the ice"
ciyue break the ice
```

Every positional argument is joined with spaces, so an unquoted phrase works too. Quote the phrase when your shell would otherwise expand it. To look up an entry that starts with a dash, stop option parsing first:

```bash
ciyue -- --word
```

A second launch does not open another window. The arguments are forwarded to the running instance, which comes to the front and performs the lookup.

## Options

| Option | Description |
| :--- | :--- |
| `-h`, `--help` | Print help and exit. |
| `-v`, `--version` | Print the version and exit. |
| `-l`, `--log-to-file` | Append debug logs to `ciyue.log` in the application support directory. |
| `-r`, `--reset-window-state` | Reset the main window to 800×600 and centre it. |
| `--no-tts` | Disable text-to-speech for this run only. |
| `-g`, `--group-name <name>` | Switch to the named dictionary group before the lookup. |
| `-m`, `--main-window` | Look the word up in the main window (the default). |
| `-p`, `--popup-group-name <name>` | Accepted for goldendict compatibility; behaves like `--group-name`. |
| `-s`, `--scanpopup`, `--popup` | Accepted for goldendict compatibility; maps to the main window. |
| `-t`, `--toggle-popup` | Accepted for goldendict compatibility; shows and focuses the main window. |

## ciyue:// links

```text
ciyue://query?word=hello
ciyue://query?word=break%20the%20ice&group=Default
ciyue://word/hello
ciyue://hello
```

- `query` reads `word` (or `q`) plus the optional `group` / `popup-group` parameters.
- `word/<text>` takes the word from the path.
- A bare host is treated as the word itself.

Pass the whole link as one argument, the same way the desktop handler does:

```bash
ciyue "ciyue://query?word=hello&group=Default"
```

## Registering the scheme

### Linux

The package ships `org.eu.mumulhl.ciyue.desktop`, which declares `MimeType=x-scheme-handler/ciyue;` and `Exec=ciyue %U`. After installing it, refresh the desktop database:

```bash
update-desktop-database ~/.local/share/applications
xdg-mime query default x-scheme-handler/ciyue
```

### Windows

The Inno Setup installer registers `HKEY_CLASSES_ROOT\ciyue` with `"{app}\Ciyue.exe" "%1"`. A portable build has to be registered manually.

### macOS

`Info.plist` declares `CFBundleURLTypes` for `ciyue`. Links opened while the app runs are forwarded through a method channel, and arguments from a terminal launch are read at startup.

## Logs

`--log-to-file` writes the same messages shown on the in-app log page:

- Linux: `~/.local/share/org.eu.mumulhl.ciyue/ciyue.log`
- macOS: `~/Library/Application Support/org.eu.mumulhl.ciyue/ciyue.log`
- Windows: `%APPDATA%\org.eu.mumulhl.ciyue\ciyue.log`

The exact folder is the application support directory reported by the platform.

## Use from Vim or Emacs

The lookup word is just an argument, so an editor can pass the word under the cursor or the selected text to Ciyue. Ciyue is single-instance, so repeated calls reuse the window that is already open.

### Vim

Add this to `~/.vimrc` or `autoload/Ciyue.vim`:

```vim
function! CiyueLookup(mode)
    let save_reg = @"
    let save_reg_type = getregtype('"')
    let word = ""

    if a:mode == 'v'
        silent normal! gvy
        let word = @"
        silent normal! \<Esc>
    else
        let word = expand("<cword>")
    endif

    call setreg('"', save_reg, save_reg_type)

    " Collapse whitespace, then trim punctuation (CJK included).
    let word = substitute(word, '\_s\+', ' ', 'g')
    let punct = '、。！？「」【】『』・…（）｛｝［］,;:!?''"()\[\]{}<>'
    let word = substitute(word, '^['.punct.']*\(.\{-}\)['.punct.']*$', '\1', '')

    if word == ""
        echohl ErrorMsg | echo "Nothing to look up" | echohl None
        return
    endif

    let cmd = ""
    if has("win32") || has("win64")
        let cmd = 'start /b Ciyue.exe "' . word . '"'
    elseif has("mac")
        let cmd = '/Applications/Ciyue.app/Contents/MacOS/Ciyue "' . word . '" &'
    else
        let cmd = 'ciyue "' . word . '" &'
    endif

    silent! call system(cmd)
    echo "Looking up: " . word
endfunction

nnoremap <silent> <M-d> :call CiyueLookup('n')<CR>
vnoremap <silent> <M-d> :call CiyueLookup('v')<CR>
```

If `ciyue` is not on `PATH` (for example, you run a build from `build/linux/...`), put its absolute path in `cmd`. On Windows, use the full path to `Ciyue.exe` as well.

### Emacs

```elisp
(defun ciyue-lookup ()
  "Look up the region or the word at point in Ciyue."
  (interactive)
  (let ((word (if (use-region-p)
                  (buffer-substring-no-properties (region-beginning) (region-end))
                (current-word nil t))))
    (when word
      (setq word (replace-regexp-in-string "[[:space:]]+" " " word))
      (setq word (replace-regexp-in-string "^[[:space:]]+\\|[[:space:]]+$" "" word))
      (unless (string= word "")
        (async-shell-command
         (concat "ciyue " (shell-quote-argument word)) nil nil)
        (message "Looking up: %s" word)))))

(global-set-key (kbd "M-d") 'ciyue-lookup)
```

`async-shell-command` opens a `*Async Shell Command*` buffer. Hide it with:

```elisp
(add-to-list 'display-buffer-alist
             '("\\*Async Shell Command\\*"
               (display-buffer-no-window)))
```

## Notes

- Argument parsing and the `ciyue://` scheme are desktop-only. Android keeps using the system text-selection menu.
- Window options are best-effort: if a window cannot be created, the lookup still runs.
