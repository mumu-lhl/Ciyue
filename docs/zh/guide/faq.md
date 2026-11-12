# 常见问题

## 词典去哪里下载？

词悦不自带词典。从 Wiki 的[推荐词典](https://github.com/mumu-lhl/Ciyue/wiki#recommended-dictionaries)下载 `.mdx` / `.mdd` 文件，或者 StarDict 词典（`.ifo` / `.idx` / `.dict`），然后在 **设置 → 管理词典** 中添加。离线百科类词典（维基辞典、维基百科、维基文库等）也可以从 [Kiwix](https://www.kiwix.org/) 获取：到 [dumps.wikimedia.org/other/kiwix/zim/](https://dumps.wikimedia.org/other/kiwix/zim/) 下载 `.zim` 文件。

## 为什么词悦需要 INTERNET 权限？

词悦用 WebView 渲染词典条目，而 WebView 即使显示本地数据也需要 INTERNET 权限才能工作。该权限还用于检查更新和你配置的第三方服务（如 AI provider）。词悦不会自主发起网络请求。

## F-Droid 的版本比 GitHub 的旧，为什么？

F-Droid 按自己的节奏构建和发布应用，所以版本会比 GitHub 晚几天到几周。如果想第一时间收到更新，用 [Obtainium](https://obtainium.imranr.dev/) 安装——它直接跟踪 GitHub releases。点[快速上手](./getting-started) 页面的 Obtainium 徽标即可添加。

## 应用更新是怎么工作的？更新通道是什么？

在 **设置 → 检查更新** 里可以选择更新通道：

- **稳定版** —— 仅正式 release，推荐大多数用户使用。
- **Beta / Alpha** —— 带新功能的预发布版本，尚在测试。
- **Nightly** —— 每天自动构建的最新代码，可能不稳定。

桌面端通过内置更新器使用同样的三个通道。

## 怎么备份单词本和设置？

到 **设置 → 备份** 导出数据文件（单词本、历史、标签、抽认卡、设置）。妥善保存这个文件，之后可以在同一页面导入。如果要在多设备间持续同步，见[云同步](./cloud-sync)。

## 词典显示乱码或内容缺失怎么办？

- 确认同名的 `.mdd` 资源文件（如果词典有的话）和 `.mdx` 放在同一目录。
- StarDict 词典要把 `.ifo`、`.idx`、`.dict` 放在同一目录下，且主文件名相同。
- 有些词典需要调自定义 CSS：**管理词典 → 词典 → 自定义 CSS**。
- 如果某本词典导致查词崩溃，请到 [GitHub](https://github.com/mumu-lhl/Ciyue/issues) 提 issue 并注明词典名称。

## （Linux）词条区域是空白的，但文字能选中、复制和搜索？

页面本身是正常的，只是 WebView 的画面没有送到 Flutter。词悦默认自动选择渲染方式：虚拟机和部分显卡驱动退回软件渲染，已知良好的 GPU 使用硬件加速。如果自动选择在你的显卡上用错了路径，手动指定软件渲染：

```bash
CIYUE_RENDER_MODE=software ciyue
```

其他取值：`auto`（默认，自动选择）、`hardware`（强制硬件加速）。底层的 `FLUTTER_INAPPWEBVIEW_SKIP_DMABUF_CHECK=1` 和 `FLUTTER_INAPPWEBVIEW_LINUX_DISABLE_GL=1` 优先级更高，会覆盖 `CIYUE_RENDER_MODE`。

如果软件渲染下仍然空白，就不是渲染方式的问题。用 `ciyue -l` 复现一次，再到 [GitHub](https://github.com/mumu-lhl/Ciyue/issues) 反馈：日志里的 `rendering mode=` 和 `no frame within 5s` 两行能直接指出是哪一层没有收到帧。

## 同一目录里的 MDX 和 StarDict 词典只出现一个？

词悦用「去掉扩展名的路径」来标识一本词典，所以 `foo.mdx` 与 `foo.ifo` / `foo.idx` / `foo.dict` 会被当成同一本：MDX 会被注册，StarDict 那份会被跳过。想让两本同时出现，请把主文件名区分开，例如 `foo-mdx.mdx` 与 `foo-stardict.ifo`。

## 怎么在 Android 的 KOReader 里用词悦？

在 `koreader` 目录下创建 `dictionaries.lua` 文件，内容如下：

```lua
{
    { "Ciyue", "Ciyue", false, "org.eu.mumulhl.ciyue", "send" }
}
```

之后就可以在 KOReader 里通过词典动作查词了。

## 怎么在静读天下里用词悦的悬浮窗？

先在词悦的 **设置 → 其他 → 悬浮窗** 里打开开关。窗口样式由阅读器自动决定：阅读器提供了选中词的位置（ColorDict 协议）时，词悦会在屏幕另一半弹出半屏窗口，避开选中的词；没有提供位置信息时，显示居中卡片。关掉这个开关后，取词会直接打开词悦主窗口。

在静读天下里这样配置：

1. 选中一段文字，长按后出现的菜单里点 **更多**，再点 **设置**，打开词典设置。
2. 把 **词典1（单击词典按键）** 或 **词典2（长按词典按键）** 设为 **深蓝词典|欧路词典|MDict|ColorDict**。
3. 弹出词典列表时，勾选 **词悦**。

如果弹出的是别的词典，说明安卓记住了那款应用的默认打开方式：到 **安卓系统设置 → 应用 → 对应词典的应用信息 → 默认打开 → 清除默认偏好设置**，再试一次。

## 我的数据存在哪里？

- **Android**：应用私有存储（`/data/data/org.eu.mumulhl.ciyue/`）；词典默认放在应用的文档目录，可在设置里改。
- **Windows**：`%APPDATA%\ciyue\`。
- **Linux**：`~/.local/share/ciyue/`（Flatpak 版是 `~/.var/app/...`）。
- **macOS**：`~/Library/Application Support/ciyue/`。

## 怎么参与翻译？

翻译在 [Weblate](https://hosted.weblate.org/engage/ciyue/) 上管理。可以添加新语言或改进现有翻译，不需要会编程。

## 发现 bug / 有功能建议，去哪里反馈？

到 [GitHub](https://github.com/mumu-lhl/Ciyue/issues) 提 issue。请附上应用版本、平台和复现步骤。

## 某个翻译源突然不能用了，为什么？

免费翻译源用的是网页公开接口而非官方 API，服务商可能随时变更或封禁接口。请在翻译设置里停用该源、改用其他源，或换成官方 API 源。详见[翻译](./translation)页。
