# 词典格式

词悦读取三类词典：**MDict**（`.mdx` / `.mdd`）、**StarDict**（`.ifo` / `.idx` /
`.dict`）与 **ZIM**（`.zim`）。它们装的是词头、HTML 或纯文本释义，以及释义引用的图片和音频。

本文说明两种格式的内部结构、词悦实际能读什么，以及如何在两者之间转换。

::: warning 一个主文件名只能有一本词典
词悦用「去掉扩展名的路径」标识词典，所以同一目录下的 `dict.mdx` 与 `dict.ifo` 会被当成
同一本，只会导入 MDX 那份。想两本都留着，就把主文件名区分开，例如 `dict-mdx.mdx` 和
`dict-stardict.ifo`。
:::

## MDict

一本 MDict 词典是一个 `.mdx` 文件加若干可选的资源文件：

| 文件 | 内容 |
| --- | --- |
| `name.mdx` | 词头与释义 |
| `name.mdd` | 图片、音频、CSS、JS |
| `name.1.mdd`、`name.2.mdd` | 更多的资源包（`1`、`2` 是文件名的一部分） |

它们的主文件名必须一致。导入时词悦只需要 `name.mdx`，但资源只有和 `.mdx` 放在同一
目录时才找得到。

::: info
MDict 本身是闭源的免费软件（Octopus Studio），格式从未公开过规范，所有开源读取器
——包括词悦用的那个——都是从文件里逆向出来的。这也是各家工具支持范围不一致的原因：
1.2 与 2.0（头部里的 `GeneratedByEngineVersion`）是大家都能读的版本；3.0 改了编码
规则，只有部分实现支持，不过用 3.0 打包的词典很少见。
:::

`.mdx` 内部依次是：4 字节的头长度、UTF-16LE 的 XML 头（`Title`、`Description`、
`Encoding`、`StyleSheet` 等）、键索引区、记录区。索引和记录都按块压缩，查一个词只
解压需要的那一块。`.mdd` 用同样的容器，只是把文件路径当作键。实际释义基本都是 HTML，
资源用相对路径引用。

词悦能读 `.mdd` 与拆分出来的 `.N.mdd`；资源不在压缩包里时会回退到 `.mdx` 同目录下的
散文件。用 LZO 压缩的 MDX 会在导入时报「不支持的压缩方式」：请用 zlib 重新压缩，或者
转成别的格式。

### 桌面上的事实标准其实是 GoldenDict-ng

MDict 自己用老版 IE 的 WebBrowser 控件渲染词条（IE7/8 一代，JavaScript 停在 ES5），
所以依赖 flexbox、`word-break`、`localStorage` 或 ES6 的现代 `.mdx`，在定义了这个格式的
「原版」软件里根本显示不正常。而 PC 上大家实际用的是 GoldenDict-ng，于是它——而不是
MDict——成了新词典的事实参考实现。[`pangloss`](https://lib.rs/crates/pangloss)
的文档里就写得很直接：

> 每个有实际分量的格式都对应一个具体的阅读器——Mdict 对应的就是
> goldendict-ng；其他阅读器也许能导入这种格式，但通常支持不到相同
> 的功能范围。

| 格式 | 目标阅读器 |
| --- | --- |
| Yomitan | Yomitan |
| StarDict | KOReader |
| MDict | GoldenDict-ng |
| DSL（只读） | GoldenDict-ng |

这种「照着 GoldenDict-ng 写、而不是照着 MDict 写」的痕迹随处可见。例如不少第三方
打包的 `.mdx` 里直接带着 `bword://word` 链接——`bword://` 本是 Babylon `.bgl`
格式的跳转写法，原版 MDict 根本不认；它之所以能跳，是因为 GoldenDict-ng 把
`bword://` 和 `entry://` 当作同一个 scheme 处理。换言之，连 MDict 自家格式的文件，
作者都在按 GoldenDict-ng 的行为来写链接了。

某本词典在某个软件里「排版坏了」，先确认它是照着哪个阅读器做的：作者通常按最新的引擎
写，而不是按最老的那个。

## StarDict

StarDict 是同一目录下一组同名文件：

| 文件 | 是否必需 | 内容 |
| --- | --- | --- |
| `name.ifo` | 必需 | 纯文本元信息：`bookname`、`wordcount`、`idxfilesize`、`sametypesequence` 等 |
| `name.idx` | 必需 | 词头索引 |
| `name.dict` | 必需 | 释义正文 |
| `name.syn` | 可选 | 同义词索引 |

`bookname` 就是词悦里显示的词典名。`.idx` 的每条记录是：UTF-8 词头、一个 `\0`、
4 字节大端偏移、4 字节大端长度，指向 `.dict` 中的位置；记录按字节序排序，二分查找才
能成立。`.ifo` 里写了 `idxoffsetbits=64` 的词典改用 8 字节偏移（StarDict 3.0 的布局）。

`.dict` 存放释义。有 `sametypesequence` 时，每条记录就是这些类型的字段直接拼接、不带
类型字节；没有时，每个字段前面都带一个类型字节。常见类型：

| 类型 | 含义 |
| --- | --- |
| `m` | 纯文本 |
| `h` | HTML |
| `g` | Pango 标记 |
| `x` | XDXF |
| `t` | 音标 |
| `y` | 汉语拼音 / 日文假名 |
| `r` | 资源文件列表 |
| `W` | WAV 音频 |
| `P` | 图片 |

`.idx`、`.syn`、`.dict` 都可以压缩存放：`.idx.gz` / `.syn.gz` 是普通 gzip，
`.dict.dz` 是 dictzip——同样兼容 gzip 的容器，但每块独立压缩、可随机读取，所以查词
不用整本解压。词悦三种写法都能读。

### 资源文件：`res/` 与 `res.zip`

StarDict 本身没有资源容器：图片和音频放在词典旁边的 `res/` 目录里，词条用
`res/pic.png` 或 `pic.png` 引用。

GoldenDict-ng 在这个基础上允许把同一个目录直接打成 zip，不必解压：

| 路径 | 说明 |
| --- | --- |
| `res/` | 普通目录 |
| `res.zip` | 根目录就是 `res/` 内容的压缩包 |
| `name.res.zip` | 同上，以词典名命名 |

压缩包里**不能再套一层 `res/`**——它的根目录本身就是 `res/`。词悦依次查找 `res/`、
`res.zip`、`name.res.zip`、`res/res.zip`，压缩包内 `pic.png` 和 `res/pic.png` 两种
写法都认，所以按 GoldenDict-ng 规则打包的 zip 可以直接用。

## 该选哪种

- **MDict** 压缩率更高、只有一个文件，所以公开发布的词典大多是这个格式；代价是不好
  打开，读或改都要借助工具。
- **StarDict** 是明文文件和极简的索引格式，容易查看、比较、手工修补，几乎所有的开源
  词典软件都支持。配合 `res.zip` 与 `.dict.dz`，也不会再产生成千上万个小文件。

## 格式转换

词悦本身不写这两种格式，转换要用下面的工具。

### MDict → StarDict（pyglossary）

[pyglossary](https://github.com/ilius/pyglossary) 需要 Python 3.12 或更新版本：

```bash
pip install pyglossary
pyglossary book.mdx book.ifo
```

格式按扩展名自动识别；不确定时用 `--read-format` / `--write-format` 显式指定
（`pyglossary --help` 会列出可用的名字）。常用参数：

- `--sqlite`：中间数据落在 SQLite 而不是内存里，大词典必加；
- `--no-interactive`：脚本里用，必须同时给出输入和输出文件名；
- `--remove-html-all`：去掉释义里的 HTML（需要 `lxml` 和 `beautifulsoup4`），一般
  不建议——HTML 正是排版和图片的来源。

StarDict 输出必须排序，所以 pyglossary 自己也可能切到 SQLite 模式。

### StarDict → MDict（mdict-utils）

pyglossary 能读 MDX，但不能写。反方向要用
[mdict-utils](https://github.com/zhansliu/mdict-utils) 打包它约定的纯文本：

```bash
pip install mdict-utils
mdict -a source.txt book.mdx --title "我的词典" --description "..."
```

`source.txt` 一本一词条：词头单独一行，释义紧随其后，条目之间用 `</>` 分隔。

```
word
<p>释义</p>
</>
```

pyglossary 导出的制表符文本离这个格式只差一步，写几行脚本按制表符拆分、在条目之间补
`</>` 即可。

同一个工具也适合日常检查：

```bash
mdict -m book.mdx          # 看头部信息
mdict -k book.mdx | head   # 看前几个词头
mdict -q word book.mdx     # 查一条词条
mdict -x book.mdx -d out/  # 解包词条与 .mdd 资源
```

## ZIM

**ZIM** 格式（`.zim`，openZIM）是一种开放、高压缩率的离线档案格式，最初用于离线分发维基百科（Wikipedia）、维基词典（Wiktionary）、古腾堡计划等知识库。

| 文件 | 内容 |
| --- | --- |
| `name.zim` | 单文件完整包，内置词条文章、多媒体资源、CSS、JS 与元数据 |

ZIM 是一站式的单文件词典。词悦支持自动索引词头和重定向、通过嵌入式 HTTP 服务及请求拦截提供完整的离线图片与样式、并将索引自动缓存为 `.cidx` 实现秒开。

::: info
ZIM 词典档案主要由 [Kiwix](https://www.kiwix.org/) 与 [openZIM](https://openzim.org/) 维护发布，涵盖全球数百种语言的维基百科、维基词典、Stack Exchange 等优质资源。
:::

## 常见坑

- **主文件名要一致。** 把一对文件（`.mdx` + `.mdd`）或三件套（`.ifo` + `.idx` +
  `.dict`）里的某一个改名，词典就废了；要改就一起改。
- **`res.zip` 不要套外层目录**，否则在 GoldenDict-ng 里会读不到资源。
- **转换后确认词典名。** 名字来自 MDict 头部或 StarDict 的 `bookname`，取决于转换器
  写了什么；空的会退回到文件名。
- **发音可能失效。** pyglossary 会把 MDict 的 `<a href="sound://…">` 改写成
  `<audio src="…">`，部分阅读器不渲染这种写法。转换后喇叭图标消失，通常就是它。

## 去哪里找词典

- [FreeMdict 论坛](https://forum.freemdict.com/)——MDX/StarDict 词典最大的社区，有
  格式讨论和转换经验。
- [GoldenDict-ng 的格式说明](https://xiaoyifang.github.io/goldendict-ng/dictformats/)
  ——`res.zip`、dictzip 等扩展写法的参考。

下载或转换时请遵守词典的授权条款，很多词典只允许个人使用。

## 相关

- [快速上手](./getting-started)——添加词典。
- [词形还原](./word-forms)——Hunspell 文件，与词典格式无关。
- [常见问题](./faq)——导入报错与显示问题。
