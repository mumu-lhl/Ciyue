# 词典链接 Scheme 原理解析

词悦支持 MDict、Babylon 与 GoldenDict 词典既有的链接约定。[词条内链接](./dictionary-links)
一页列出了你可以*书写*的写法；本页解释这些规则*为什么*如此——通过剖析
GoldenDict-ng、MDict 与 Babylon 实际如何处理它们、词悦在何处更进一步，以及
一个兼容的阅读器**必须**（和**不必**）支持什么。

## 两层 scheme

这个生态里的每个链接 scheme 都属于以下两层之一。

**写进词典文件里的**（词典制作者真正写下的）：

| Scheme | 来源 | 含义 |
| --- | --- | --- |
| `entry://word` | MDX / MDict | 跳转到词条 `word` |
| `bword://word` | Babylon `.bgl` | 与 `entry://word` 相同 |
| `gdlookup://localhost/word` | GoldenDict-ng | 跨词典查词 `word` |
| `sound://file` | MDX / Babylon | 播放音频 `file` |

**由 GoldenDict-ng 加载器在运行时生成的**（绝不会出现在源文件中）：
`gdau`、`bres`、`gico`、`gdprg`、`gdtts`、`gdinternal`。

GoldenDict-ng 把 `bword`、`entry`（以及 `gdlookup`）都注册为自定义 URL
scheme 并一视同仁：提取词头后在所有已加载词典中查词（`main.cc` 注册这些
scheme，`utils.hh` 对 `bword`/`entry`/`gdlookup` 用同一套逻辑解析）。这正是
单个阅读器能同时兼容两种拼写的缘故。

### 跨格式混用只在 GoldenDict-ng 里生效

由于每个加载器只改写*自己*的 scheme，你可以造出只有 GoldenDict-ng 才懂的
混合体：

- **含 `bword://word` 的 MDX**：MDX 加载器的链接改写只认 `entry://` 和
  `sound://`，于是 `bword://` 原样保留，最终由全局 `bword` scheme 处理器接住。
  原版 MDict 不认 `bword:`，无法跳转。
- **含 `entry://word` 的 Babylon `.bgl`**：BGL 加载器只规范化 `bword:`，
  `entry://` 因而原样保留、交给全局处理器。原版 Babylon 不懂 `entry://`。

即便是"标准"拼写，行为也不同：GoldenDict-ng 把 `entry://word` 改写成
`gdlookup://localhost/word`——一次**跨所有**已加载词典的查词；而 MDict 自己的
`entry://` 只在**当前 `.mdx` 内部**跳转。

## `sound://` 与 StarDict 转换陷阱

`sound://` 是 MDX/Babylon 的音频约定。在 GoldenDict-ng 里**只有 MDX 加载器**
会把 `sound://` 改写成 `gdau://`（其内部的音频 scheme）。StarDict 加载器**不会**
改写 `sound://`：它的链接改写对带有 `:` 的 `a` 链接原样放过，而它的 `<audio>`
处理器只转换**不含** `://` 的 src。由于 `sound` 并未注册为 scheme，一个残留在
StarDict 文件里的 `sound://` 链接就是死链。

这正是"把 MDX 转成 StarDict 后 `sound://` 用不了"的原因：音频标签不再被改写。
相反，`<audio src="relative.wav">`（无 `://`）在 StarDict 加载器里**能**用，
因为它会被改写成 `gdau://`。

实践建议：

- 若词典带有 MDX 音频，直接加载原始 MDX 即可，原生支持、`sound://` 处理无误。
- 若必须产出 StarDict，让转换工具输出 StarDict 原生的相对资源（相对路径的
  `<audio>` src，或 `snd:` 资源形式），而不是 MDX 风格的 `sound://` 链接。

## `gdlookup://localhost/word` —— 稳定的跨词典引用

与下面的 `gdau://` 不同，这种写法是**稳定且可移植**的：

- `localhost` 是 GoldenDict-ng scheme 处理中写死的常量，有意义的部分是路径里
  的词头。
- 解析时在所有已加载词典中查词，因此移动、重命名、复制词典文件都无所谓。
- 它按"内容"寻址而非按"位置"寻址，所以可以手工编写——也确实出现在真实词典中
  （包括词悦作者自制的若干程序辞典）。

词悦支持它：其词条 URL 判定接受 host 为 `localhost` 的 `gdlookup`。

### 为什么要有 `localhost`？

GoldenDict 最初的 commit `e4e5a969`（Konstantin Isakov，GoldenDict 作者）说得很直白：

> Switch to `gdlookup://localhost/word` scheme in dsl word references. This
> fixes cases with uppercased/capitalized words.
> （改用 `gdlookup://localhost/word`，修复大写/首字母大写词条的跳转。）

URL 的 **host 会被解析器强制转小写**，而 **path 不会**。`gdlookup://Word`
到达解析层就变成 `word`，大小写敏感的查词就此失效。那个假的 authority
`localhost` 存在只有一个目的：把词头推进**路径**，让大小写得以保留。

词悦撞上了同一个 bug，并用同一种方式修复。早期词悦把词头放在 host 里，于是
`entry://Abend` 到达 Dart 时成了 `abend`，而 `entry://A.D.` / `entry://tag:sumeru`
被当成 `host:port` 解析、毫无结果（`tag:sumeru` 里的 `:` 被当成端口分隔符——
这个坑最初是在做原神辞典、用到 `entry://tag:sumeru` 这类链接时踩到的）。修复
把词移进路径，写成 `gdlookup://localhost/<百分号编码>`，与 GoldenDict 的形态
完全一致、理由也完全相同。这些例子如今已是词悦里常驻的回归测试。

## `gdau://` —— 为什么兼容阅读器可以无视它

`gdau://<id>/file` 看似与 `gdlookup://` 相似，本质却不同：

- `<id>` 是词典**绝对文件路径的 MD5**（GoldenDict-ng 的 `makeDictionaryId`）。
  文件移动或换机器，它就会变。
- `<file>` 是该词典内的资源名。
- 解析时**先按这个 id 哈希定位词典**，再取资源。

因为 id 是路径派生出的哈希，`gdau://` **不可移植、也无法手工编写**——你写不出
一个在任何地方都好使的 `gdau://` 链接。而且它只会被 GoldenDict-ng 的加载器在
**运行时现生成**（MDX 把 `sound://` 改写成 `gdau://`；StarDict 把
`<audio src="rel">` 改写成 `gdau://`）。任何源词典文件里都不含 `gdau://`。

所以，一个想做 GoldenDict-ng 超集的第三方阅读器，应当支持*作者层*的约定
（`entry`、`bword`、`gdlookup://localhost/…`、`sound://`），而**无需、也不该
指望收到** `gdau://`。词悦用的是自己的音频管线（`sound://` 加一个本地 HTTP
服务，提供词典的 `res/` 与 `.mdd` 资源）。

## `#` 的处理：词悦是严格超集之处

对**锚点**（滚动定位）这部分，GoldenDict-ng 与词悦是等价的：两者都把它作为
`?gdanchor=` 查询参数而非 `#` 片段，正是为了避免 `#` 在到达处理器之前被当成
同文档片段吞掉。

差别出现在**特殊字符出现在词头本身**时：

- GoldenDict-ng 把词头**裸**塞进路径（`gdlookup://localhost/<word>`）。词里若含
  `#`（或 `?`、`/`），就会变成片段/查询/路径分隔符而截断词；其 `gdlookup` +
  片段分支进而退化成脆弱的 `window.location = url`。
- 词悦对词头**逐字节百分号编码**，于是 `#` → `%23`、`/` → `%2F`、
  `?` → `%3F` 永远不会与 URL 语法碰撞，词完整往返（测试 `a%2Fb` → `a/b`、
  `%74%61%67%3A…` → `tag:sumeru` 均为证）。词悦还会兜底救援"页面脚本没改写、
  导致 `#` 残留在片段里"的情况。

所以在"标识符内含特殊字符"这一轴上，词悦 ⊃ GoldenDict-ng。

## 小结

| Scheme | 写进词典? | 稳定/可移植? | GD-ng | 词悦 |
| --- | --- | --- | --- | --- |
| `entry://word` | 是（MDX） | 是 | 是 | 是 |
| `bword://word` | 是（Babylon） | 是 | 是 | 是 |
| `gdlookup://localhost/word` | 是（可手写） | 是（内容寻址） | 是 | 是 |
| `sound://file` | 是（MDX/Babylon） | 是 | MDX 加载器改写→`gdau` | 是（+本地服务） |
| `<audio src="rel">` | 是 | 是 | StarDict 加载器→`gdau` | 是 |
| `gdau://<id>/file` | 否（仅运行时） | 否（路径 MD5 id） | 是（内部） | 否（自有音频机制） |
| `bres`/`gico`/`gdprg`/`gdtts`/`gdinternal` | 否（仅运行时） | 否 | 是（内部） | 否（自有资源机制） |

**结论。** 要在*词典加载*层成为 GoldenDict-ng 的真正超集，就去支持那些事实
标准的"作者层"约定——`entry`、`bword`、`gdlookup://localhost/…` 和
`sound://`。`gdau`、`bres`、`gico`、`gdprg`、`gdtts`、`gdinternal` 这些 GD
内部 scheme 是运行时产物；用你自己的资源机制替代它们，而不是去解析它们。
