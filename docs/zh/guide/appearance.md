# 词典外观（主题、背景、自定义 CSS）

词条是在 WebView 里渲染的，颜色来自词典自己的 CSS。词悦只决定「怎么应用深色」，
并不知道某一本 `.mdx` 里写死了什么颜色——这也是同一本词典在一台设备上正常、
在另一台设备上黑底黑字的原因。

## 词典页是怎么跟随主题的

词悦跟随的是 **App 主题**，不是系统主题。在文档开始时它会往页面根节点注入一个类：

```html
<html class="ciyue-dark">   <!-- App 处于暗色模式 -->
```

而 WebView 自己的 `prefers-color-scheme` 跟的是**操作系统**，所以词典无法用它来
跟随词悦的主题。给词典写样式时请用 `html.ciyue-dark`：

```css
html.ciyue-dark { /* ... */ }
```

只要「App 主题」和「系统主题」不一致，这个区别就会显现——比如系统是亮色、
词悦被手动设为暗色。

## 深色模式下词典看不清怎么办

典型症状：黑底黑字、暗色页面里出现一块白、或者颜色看起来「反了两次」。

原因是词典用 `!important` 写死了颜色（`background: #fff !important;
color: #000 !important`）。Chromium 的自动暗化会重新映射页面的**计算颜色**，
但显式的 `!important` 声明优先级更高，于是可能出现背景被压暗、文字仍是黑色的
情况。自动暗化的效果取决于设备自带的 WebView 版本，所以在原生 Android 与
各厂商 ROM 上表现不同。

### 修法：一小段 CSS

把下面这段追加到词典里，并用「词悦暗色」这一条件限定。它只改颜色——不动布局，
也不用 `filter: invert(...)`（那会和自动暗化打架，反两次）。

```css
/* Ciyue dark patch —— 只在 App 为暗色模式时生效 */
html.ciyue-dark body {
  background: #17191d !important;
  color: #e6e6e6 !important;
}

html.ciyue-dark a { color: #79b8ff !important; }

html.ciyue-dark table,
html.ciyue-dark td,
html.ciyue-dark th,
html.ciyue-dark hr { border-color: #3b4048 !important; }

/* 图片不要被反色，也不要有浅色底板 */
html.ciyue-dark img,
html.ciyue-dark svg { background: transparent !important; filter: none !important; }
```

两个可放的位置：

1. **放在词典旁边**——在 `.mdx` 同目录新建 `<词典文件名>.css`（例如
   `daijirin.mdx` 对应 `daijirin.css`）。外部文件**优先于 `.mdd` 里的同名副本**，
   因此不需要重新打包资源包。这是「只修某一本」的正确位置。
2. **设置 → 外观 → 自定义 CSS**——全局唯一的一份样式，注入在所有词典 CSS 之后，
   所以能压过 `!important`。它作用于**所有**词典；只想影响某一本时，需要自己
   用选择器限定范围。

### 确认页面当前处在哪个主题

临时把下面这行贴进「自定义 CSS」：

```css
html.ciyue-dark { border-top: 8px solid lime !important; }
```

页面顶部出现绿色横条，说明词悦认为当前是暗色模式，上面那些规则会生效；没有绿条
说明 App 处于亮色模式，暗色规则不会应用。

## 影响渲染的几个设置

**词典背景颜色**——用你选的颜色覆盖页面背景（8 个预设 + 自定义取色，或「使用默认」）。
建议保持「使用默认」：写死的颜色会盖过词典自己的背景，在相反的主题下可能把文字
盖住。在 Windows 上，如果不设背景、处于暗色、又没开暗化，页面会退回白底。

**深色处理（仅 Windows / Linux）**——App 处于暗色时，词悦可以在页面里运行
[Dark Reader](https://darkreader.org/) 做 JavaScript 层面的转换。设置自定义词典
背景色后它会自动禁用（两者会抢同一批颜色）。Android 与 macOS 上没有这个选项，
走的是 Chromium 内置的自动暗化。

**自定义 CSS**——见上。因为它最后注入，是修「你没法改的词典」（例如资源打包在
`.mdd` 里）最可靠的手段。

## 各平台差异

| 平台 | 深色机制 | 说明 |
| --- | --- | --- |
| Android（原生 WebView） | Chromium 自动暗化 | 通常正常；写死颜色的词典仍可能需要上面的补丁 |
| Android（厂商 ROM，如 HarmonyOS 3） | 同一个 API，但 WebView 实现不同 | 可能出现「背景被压暗、文字仍黑」——需要 `html.ciyue-dark` 补丁 |
| Windows | Dark Reader（可选） | 不开暗化、又没设自定义背景时，暗色模式下页面仍是白底 |
| Linux / macOS | Dark Reader（可选） | 同样支持自动暗化 |

## 相关

- [词形还原](./word-forms) —— 词干还原与 Hunspell 配置。
- [常见问题](./faq) —— 资源缺失、词条乱码。
