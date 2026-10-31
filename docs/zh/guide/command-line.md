# 命令行与 ciyue:// 链接

桌面端（Linux、macOS、Windows）支持命令行参数和 `ciyue://` 链接。你可以从终端、脚本或浏览器直接发起查词，不必先打开应用。

## 查词

```bash
ciyue hello
ciyue "break the ice"
ciyue break the ice
```

所有位置参数会用空格拼接，所以不加引号的短语也能查。如果 shell 会展开其中的特殊字符，请用引号包住。想查以 `-` 开头的词条时，先用 `--` 结束选项解析：

```bash
ciyue -- --word
```

重复启动不会开新窗口：参数会转发给已运行的实例，由它来到前台并执行查词。

## 选项

| 选项 | 说明 |
| :--- | :--- |
| `-h`, `--help` | 打印帮助并退出。 |
| `-v`, `--version` | 打印版本并退出。 |
| `-l`, `--log-to-file` | 把调试日志追加到应用支持目录下的 `ciyue.log`。 |
| `-r`, `--reset-window-state` | 把主窗口恢复为 800×600 并居中。 |
| `--no-tts` | 仅在本次运行中禁用语音合成。 |
| `-g`, `--group-name <name>` | 查词前切换到指定名称的词典组。 |
| `-m`, `--main-window` | 在主窗口中查词（默认行为）。 |
| `-p`, `--popup-group-name <name>` | 为兼容 goldendict 保留；行为等同 `--group-name`。 |
| `-s`, `--scanpopup`, `--popup` | 为兼容 goldendict 保留；映射到主窗口。 |
| `-t`, `--toggle-popup` | 为兼容 goldendict 保留；显示并聚焦主窗口。 |

## ciyue:// 链接

```text
ciyue://query?word=hello
ciyue://query?word=break%20the%20ice&group=Default
ciyue://word/hello
ciyue://hello
```

- `query` 读取 `word`（或 `q`）以及可选的 `group` / `popup-group` 参数。
- `word/<文本>` 从路径中取词。
- 直接把主机名当作查询词。

和桌面协议处理器一样，把整个链接作为**一个参数**传入：

```bash
ciyue "ciyue://query?word=hello&group=Default"
```

## 注册协议

### Linux

安装包里带有 `org.eu.mumulhl.ciyue.desktop`，其中声明了 `MimeType=x-scheme-handler/ciyue;` 和 `Exec=ciyue %U`。安装后刷新桌面数据库：

```bash
update-desktop-database ~/.local/share/applications
xdg-mime query default x-scheme-handler/ciyue
```

### Windows

Inno Setup 安装包会注册 `HKEY_CLASSES_ROOT\ciyue`，命令为 `"{app}\Ciyue.exe" "%1"`。绿色版需要手动注册。

### macOS

`Info.plist` 中声明了 `ciyue` 的 `CFBundleURLTypes`。应用运行时打开的链接会通过 method channel 转发；从终端启动时的参数会在启动阶段读取。

## 日志

`--log-to-file` 写入的内容与应用内日志页一致：

- Linux：`~/.local/share/org.eu.mumulhl.ciyue/ciyue.log`
- macOS：`~/Library/Application Support/org.eu.mumulhl.ciyue/ciyue.log`
- Windows：`%APPDATA%\org.eu.mumulhl.ciyue\ciyue.log`

具体目录以平台提供的应用支持目录为准。

## 在 Vim / Emacs 中使用

查词词只是命令行参数，所以编辑器可以把光标下的单词或选中的文本直接交给词悦。词悦是单实例，重复调用会复用已经打开的窗口。

### Vim

把下面这段加到 `~/.vimrc` 或 `autoload/Ciyue.vim`：

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

    " 把连续空白压成一个空格，再去掉两端标点（含中日文标点）
    let word = substitute(word, '\_s\+', ' ', 'g')
    let punct = '、。！？「」【】『』・…（）｛｝［］,;:!?''"()\[\]{}<>'
    let word = substitute(word, '^['.punct.']*\(.\{-}\)['.punct.']*$', '\1', '')

    if word == ""
        echohl ErrorMsg | echo "无可用查询内容" | echohl None
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
    echo "正在查询: " . word
endfunction

nnoremap <silent> <M-d> :call CiyueLookup('n')<CR>
vnoremap <silent> <M-d> :call CiyueLookup('v')<CR>
```

如果 `ciyue` 不在 `PATH` 里（例如直接运行 `build/linux/...` 下的产物），把 `cmd` 里的命令换成绝对路径。Windows 同理，把 `Ciyue.exe` 换成完整路径。

### Emacs

```elisp
(defun ciyue-lookup ()
  "查询选区或光标下的单词"
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
        (message "正在查询: %s" word)))))

(global-set-key (kbd "M-d") 'ciyue-lookup)
```

`async-shell-command` 会弹出 `*Async Shell Command*` 缓冲区，用下面这行隐藏：

```elisp
(add-to-list 'display-buffer-alist
             '("\\*Async Shell Command\\*"
               (display-buffer-no-window)))
```

## 说明

- 命令行参数和 `ciyue://` 仅桌面端支持。Android 仍然使用系统的划词菜单。
- 窗口相关选项是尽力而为：窗口无法创建时，查词仍会执行。
