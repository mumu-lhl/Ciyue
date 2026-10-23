---
## [2.0.0-beta.1](https://github.com/mumu-lhl/Ciyue/compare/v1.23.2..v2.0.0-beta.1) - 2026-10-17

### 新功能

- **多源翻译** - 一次翻译同时查看多个来源的结果：免费在线服务、需要密钥的服务、以及你配置的任意 AI 服务，每个来源一张结果卡，可自由启用、禁用和排序
- **AI 对话升级** - 支持多个对话会话与流式回复，可附带图片提问、也能生成图片；新增专门的提示词管理页；AI 未配置时会明确提示缺少什么，不再静默无响应；新增 Agnes AI 服务商
- **学习复习闭环** - 测验答错的词自动收入错题本，可离线重练；新增选择、拼写、完形填空题型；加入情景练习，测验和对话都支持朗读
- **StarDict 词典** - 可像 MDict 一样添加 StarDict 词典（.ifo/.idx/.dict/.dz）；词条按应用主题原生渲染，HTML 词条仍用 WebView 打开
- **发音设置重做** - 可选发音包优先、仅发音包或仅 TTS；TTS 可调语速、音调并试听；发音包会显示条目数；键为 .mp3/.wav 的发音包现在也能播放
- **更新渠道** - 可在设置中切换正式版、测试版与 Nightly
- **桌面端查词页** - 新增前进、后退导航按钮
- **设置界面刷新** - 设置页与词典管理页改用更清爽的卡片布局

### 修复

- **(linux)** 修复 WebView 闪烁、黑屏、硬件 GPU 渲染损坏与 WebProcess 崩溃，内置 WebKit 运行时已升级
- **(词典)** 修复分组计数不刷新、删除词典后残留空行、开关词典时没有错误反馈
- **(翻译)** 修复重复点击导致付费翻译源重复计费、切换语言后结果不刷新
- **(查词页)** 修复从查词页继续搜索时页面无限堆叠、标签页历史不同步
- **(设置)** 修复一批设置、查词页与生词本的状态不更新和数据问题；修复 Hunspell 查询竞态
- **(f-droid)** 恢复 F-Droid 构建

### 性能

- **查词** - 多词典并行查询，搜索建议加入防抖，结果更快且不闪烁
- **启动与历史** - 启动更快，历史记录改用索引与增量更新
- **查词页** - 大幅减少 WebView 重排，滚动与缩放更流畅

---
## [1.23.2](https://github.com/mumu-lhl/Ciyue/compare/v1.23.1..1.23.2) - 2026-09-19

### 修复

- **(android)** 提升悬浮窗稳定性，优化连续查词 - ([48dd2f4](https://github.com/mumu-lhl/Ciyue/commit/48dd2f43f2ffc1de0318808b367bc1868b1b2319)) - Mumulhl
- **(android)** 强化悬浮查词流程与引擎生命周期管理 - ([08d7954](https://github.com/mumu-lhl/Ciyue/commit/08d7954e33399772a5a77a3e1a92b7119f9263d5)) - Mumulhl
- **(android)** 优化重复悬浮查词时的页面渲染与生命周期 - ([ecbde06](https://github.com/mumu-lhl/Ciyue/commit/ecbde0645b06389686c6bc0f088f35f94423e829)) - Mumulhl
- **(android)** 悬浮窗中按返回键优先退出嵌套查词路由 - ([dc244ab](https://github.com/mumu-lhl/Ciyue/commit/dc244ab0b4d9787f30e0fddde3ddbd7ce0631bae)) - Mumulhl
- **(android)** 悬浮窗位于根页面时按返回键直接关闭悬浮窗 - ([de2a5b3](https://github.com/mumu-lhl/Ciyue/commit/de2a5b30a1bb328ee22e5801f1338d625aa50468)) - Mumulhl
- **(android)** 悬浮窗支持侧边返回手势 - ([619d87c](https://github.com/mumu-lhl/Ciyue/commit/619d87c06cbb86feb356858c1d5fc7c81d8b9586)) - Mumulhl
- **(android)** 对齐悬浮窗中 WebView 的深浅色主题 - ([2452e45](https://github.com/mumu-lhl/Ciyue/commit/2452e454fa9bb993a4f155610798fd503f9aa0d7)) - Mumulhl
- **(android)** 修复多窗口环境下悬浮窗出现黑边及 ANR 无响应问题 - ([7e88cea](https://github.com/mumu-lhl/Ciyue/commit/7e88cead708b213bb7fd80726f5eab3a9dae5176)) - Mumulhl
- **(hunspell)** 静态链接 Android C++ 运行库以确保原生库正常加载 - ([164ec4c](https://github.com/mumu-lhl/Ciyue/commit/164ec4cbc8f26f264a6d269a484e196b38d98068)) - Mumulhl
- **(hunspell)** 支持解析多个词干并保留同音同形词 (#729) - ([e4c117d](https://github.com/mumu-lhl/Ciyue/commit/e4c117d2dfbb3fea9bb1060d74215725e8fdfce9)) - Mumulhl
- **(i18n)** 本地化 Hunspell 设置界面 - ([941637b](https://github.com/mumu-lhl/Ciyue/commit/941637bc48e373ca9fa996b04bb6e18a8c6dac15)) - Mumulhl
- **(linux)** 使用绝对路径解析 WPE 运行时路径以避免沙箱崩溃 - ([784ac48](https://github.com/mumu-lhl/Ciyue/commit/784ac488bbce157cb74b1183b28cd00f53a900a8)) - Mumulhl
- **(linux)** 解决 bubblewrap 沙箱路径问题并支持在 Debian 上安全降级 (#733) - ([8ef58ed](https://github.com/mumu-lhl/Ciyue/commit/8ef58edfbbaf2fee2fb6b7543f39ede80fd25fa5)) - Mumulhl
- **(linux)** 排除宿主图形库以正确加载 Debian 驱动并在 DRM 不可用时降级至软件渲染 (#734) - ([064ce69](https://github.com/mumu-lhl/Ciyue/commit/064ce699185b4a507bd098c025992ad34c5f9540)) - Mumulhl
- **(lookup)** 正确处理查词重定向与拼写建议 - ([c16c068](https://github.com/mumu-lhl/Ciyue/commit/c16c068199d703d23c8afa2d19987ff96ca3961b)) - Mumulhl
- **(mdict)** 正确解析词典中的 @@@LINK 跳转记录 - ([97cf247](https://github.com/mumu-lhl/Ciyue/commit/97cf247a3d5db250472622e9691e21cf91189933)) - Mumulhl
- **(webview)** 对词条链接中的 Unicode 字符进行编码以防截断 - ([a28263f](https://github.com/mumu-lhl/Ciyue/commit/a28263f6cd9b8e557b392f593fff9f95231fe667)) - Mumulhl
- **(word-display)** 改进查词页面的返回导航并新增复制按钮 - ([70970da](https://github.com/mumu-lhl/Ciyue/commit/70970da8a48ea9a0d3b53e1f02cfe4acfb8e041e)) - Mumulhl
- **(word-display)** 限制桌面端展开面板中的 WebView 高度约束 - ([0d4b404](https://github.com/mumu-lhl/Ciyue/commit/0d4b40424ee8090298a4628d7179d9fe57457cab)) - Mumulhl

### 新功能

- **(desktop)** 桌面端支持扫描词典文件夹 - ([c89b35b](https://github.com/mumu-lhl/Ciyue/commit/c89b35b26abe0bd45644bf39fec61c571efab392)) - Mumulhl
- **(hunspell)** 为每个词典添加两轮查询选项 (#729) - ([e9094ff](https://github.com/mumu-lhl/Ciyue/commit/e9094fffec42f15d01183cf117344d1318b9019b)) - Mumulhl
- **(hunspell)** 支持将短语拆分为单词并组合词干 (#732) - ([3ea6387](https://github.com/mumu-lhl/Ciyue/commit/3ea638767045a19da501d2dcd91f5d831a883dce)) - Mumulhl
- **(macos)** 新增 macOS 平台支持 - ([660f930](https://github.com/mumu-lhl/Ciyue/commit/660f93070e5fec3df4704ff7deeb213e2697d3c4)) - Mumulhl
- **(search)** 搜索栏标注拼写建议 - ([3bd6348](https://github.com/mumu-lhl/Ciyue/commit/3bd6348bbb7ae5c94ee921c9820f08e3f4a82f30)) - Mumulhl
- **(settings)** 将 Hunspell 设置入口移至主设置页面 - ([966b252](https://github.com/mumu-lhl/Ciyue/commit/966b2521a65480fe219e9333ab56955d86938488)) - Mumulhl
- **(translation)** 通过 Weblate 新增俄语翻译 - ([404a4fa](https://github.com/mumu-lhl/Ciyue/commit/404a4fa91d16cd8aad300504158f7d773f667981)) - Xapitonov

---
## [1.23.1](https://github.com/mumu-lhl/Ciyue/compare/v1.23.1-beta.2..v1.23.1) - 2026-08-31

### 修复

- **(linux)** 将自定义 URL 协议路由到正确的 WebView - ([bdff522](https://github.com/mumu-lhl/Ciyue/commit/bdff5229bbdda45d47c4e72433cf83377b140047)) - Mumulhl
- **(settings)** 显示历史记录页面标题 - ([d797cd9](https://github.com/mumu-lhl/Ciyue/commit/d797cd98a3626e4514d68c4d2976f850d07a90b5)) - Mumulhl
- **(translation)** 补全简体中文和繁体中文翻译 - ([ee55edd](https://github.com/mumu-lhl/Ciyue/commit/ee55edd1b277afb7fad7827fd970ad3ecd95c192)) - Mumulhl

### 新功能

- **(hunspell)** 新增可选的词形分析查询功能 - ([cbea448](https://github.com/mumu-lhl/Ciyue/commit/cbea448bb4a454663ba8d7d4b3d3d21c71e32bde)) - Mumulhl

---
## [1.23.0](https://github.com/mumu-lhl/Ciyue/compare/v1.22.2..v1.23.0) - 2026-08-28

### 修复

- **(android)** 更新 compile SDK - ([641379f](https://github.com/mumu-lhl/Ciyue/commit/641379fc09e0582b69f736f8b5864ae5fd8045cf)) - Mumulhl
- **(dictionary)** 在后台加载词典索引 - ([a2d8758](https://github.com/mumu-lhl/Ciyue/commit/a2d87582f4befc30595400dc5534d85babcac6cc)) - Mumulhl
- **(linux)** 恢复 WebView 渲染 (#715) - ([fec7ed8](https://github.com/mumu-lhl/Ciyue/commit/fec7ed81be066e1e92acae43fd4e495698123544)) - Mumulhl
- **(linux)** 保留 AppImage 数据路径 - ([81b9ca9](https://github.com/mumu-lhl/Ciyue/commit/81b9ca93cffc7902c047d9ba8a443a30643e5783)) - Mumulhl
- 降低 Linux 发布版 glibc 基线 (#700) - ([96690a6](https://github.com/mumu-lhl/Ciyue/commit/96690a6e2e5bfc05cb8473380f659641a7bd6076)) - Mumulhl
- 添加 keybinder deb 依赖 (#701) - ([7449737](https://github.com/mumu-lhl/Ciyue/commit/7449737d723b49246f4cee3d3a0122209cbbf00)) - Mumulhl
- 支持 Flutter 3.47.2 构建 - ([467d316](https://github.com/mumu-lhl/Ciyue/commit/467d316fb9a98fd03df8e172c09a1d1545371ffa)) - Mumulhl

### 新功能

- **(flashcards)** 新增间隔重复学习功能 (#714) - ([b087271](https://github.com/mumu-lhl/Ciyue/commit/b087271f5d81c702d92e0c0d6810042917bdfb9f)) - Mumulhl
- **(translation)** 通过 Weblate 新增繁体中文翻译 (#698) - ([e08f401](https://github.com/mumu-lhl/Ciyue/commit/e08f40168589fff9a3220b15d4244bd76bdcb386)) - Weblate (bot)
