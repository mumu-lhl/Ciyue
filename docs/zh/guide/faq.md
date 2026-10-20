# 常见问题

## 词典去哪里下载？

词悦不自带词典。从 Wiki 的[推荐词典](https://github.com/mumu-lhl/Ciyue/wiki#recommended-dictionaries)下载 `.mdx` / `.mdd` 文件，然后在 **设置 → 管理词典** 中添加。

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
- 有些词典需要调自定义 CSS：**管理词典 → 词典 → 自定义 CSS**。
- 如果某本词典导致查词崩溃，请到 [GitHub](https://github.com/mumu-lhl/Ciyue/issues) 提 issue 并注明词典名称。

## 怎么在 Android 的 KOReader 里用词悦？

在 `koreader` 目录下创建 `dictionaries.lua` 文件，内容如下：

```lua
{
    { "Ciyue", "Ciyue", false, "org.eu.mumulhl.ciyue", "send" }
}
```

之后就可以在 KOReader 里通过词典动作查词了。

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
