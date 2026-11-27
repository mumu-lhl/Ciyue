# 词形还原（Hunspell）

词形还原会把变形词追溯到原形：查 `hoped` 也能找到 `hope`，查
`reconstructiveness` 也能找到 `reconstruct`。

这个功能**默认关闭**，且需要外部的 Hunspell 文件。原因是词形还原发生在
「引擎层」而不是词典内容里：不需要往 `.mdx` 里塞变形表，只要你能找到某种语言的
Hunspell `.aff`/`.dic`，那种语言就能用。

## 能做什么

| 查询 | 结果 |
| --- | --- |
| `hoped` | `hoped`（精确词条）+ `hope`（原形） |
| `rims` | `RIMS`（精确词条）+ `rim`（原形） |
| `fällt`（德） | `fällt` + `fallen` / `fällen` |
| `abgekämpft`（德） | `abkämpfen` |
| `かって`（日） | `かって（勝手）` / `かう（買う）` / `かつ（勝つ）` / `かる（狩る）` |
| `闲适`（中） | `闲适`（精确词条）+ 词表里声明的各种写法，例如 `閒適` |

能还原出几个原形，完全取决于你用的 Hunspell 文件——一个形式真有多个词干时，
就会全部列出。这其中有些是词悦自己的改动：原版 Hunspell 会丢掉一部分，
见[「词悦使用的 Hunspell」](../internals/word-forms)。

## 怎么开启

1. **设置 → Hunspell** —— 打开「启用词形还原与变体查找」；
2. 导入 `.aff` + `.dic`：选择包含这些文件的文件夹，每种语言一对，应用不内置任何文件；
3. 选择查找模式（见下）。对多数人来说更有用的是**补充（Supplement）**模式。

词干查询在后台执行，开启后不会拖慢界面。

## 编码

词悦把查询词以 UTF-8 传给 Hunspell，并把结果按 UTF-8 解码；这一层不会在编码之间做转换。因此 `.aff` 必须声明 `SET UTF-8`，`.dic` 也必须实际以 UTF-8 保存。

旧编码的词典仍然能导入，纯 ASCII 词也可能正常，但带重音或西里尔字母的词会还原不出来。一些老的 GoldenDict 资源就有这个问题，例如 “better morphologies” 1.0 里的 `es_ES` 是 ISO-8859-1、`ru_RU` 是 KOI8-R。导入前请把两个文件一起转成 UTF-8：

```bash
# 以 ISO-8859-1 为例；实际请用原 SET 行声明的编码
iconv -f ISO-8859-1 -t UTF-8 es_ES.aff | sed 's/^SET .*/SET UTF-8/' > es_ES.aff.utf8
iconv -f ISO-8859-1 -t UTF-8 es_ES.dic > es_ES.dic.utf8
```

确认几个非 ASCII 词能查后，再替换原文件。`SET UTF-8` 要用大写，也不要加 BOM。GitHub raw 返回的是仓库里提交的原始字节，所以仓库里要存转换后的 UTF-8 文件。

## 兜底 vs 补充

| 查询 | 兜底（默认） | 补充 |
| --- | --- | --- |
| `rims` | 只显示 `RIMS` 这条词条 | `RIMS` + `rim` |
| `hoped` | 只显示 `hoped` 这条词条 | `hoped` + `hope` |

**兜底**的意思是：只有当某本词典没有精确词条时，才去尝试还原词干。所以一旦词典里
恰好有 `RIMS` 或 `hoped` 做词条，原形就永远不会被查出来。**补充**则始终把词干和精确
词条并列显示，这也是 GoldenDict 的行为。

如果同一个词在一种模式下能查到、另一种查不到，先检查这个开关。

## 去哪找 Hunspell 文件

系统（例如Debian）自带的Hunspell词典文件通常只为拼写检查设计，**没有手写的 `st:` 条目**，不规则变形根本无法还原。可用的维护版本：

- 英文：<https://github.com/yx-wh/hunspell_en_US> —— 修正了错误的后缀标签、补齐
  词干链接与派生标签，并扩充了词表。
- 德文：<https://github.com/yx-wh/hunspell_de_DE> —— 为可分动词的分词、`zu`
  不定式补了 2,000 多条 `st:`。
- 日文：<https://github.com/yx-wh/hunspell_ja_JP> —— 由于日文通常无需拼写检查，需要单独为日文设计Hunspell词典文件。这个版本在Gary原始版本的基础上增加了混书形式到汉字的还原（例如「まん延」→「蔓延」）、补充了一些动词的活用、补充了半角假名。
- 中文：<https://github.com/yx-wh/hunspell_zh_CN> —— 空壳 `.aff` 加一份从多部中文词典生成的 `st:` 表。仓库发布的 `zh_CN.dic` 是精简版，词悦和 GoldenDict-ng 用它就够；既不按字组合、也不走 OpenCC 的读取器，需要用仓库里的脚本自行生成全量表。

## 常见问题

**打开后毫无变化。** 按顺序检查三件事：开关、是否导入了 `.aff`/`.dic`、当前查找
模式。在「兜底」模式下，有精确命中的词看起来和没开这个功能一模一样。

**查 `hoped` 还会出 `hop`。** 系统（如Debian）自带Hunspell词典文件上挂着 `hop/D` 标签，而这套 `.aff`
不做辅音双写，于是 `hop + ed` 也生成了 `hoped`（正确形式应是 `hopped`）。换用
上面修正过的英文词典即可，或者自己把 `hop` 上的 `D` 去掉。

**德语 `fällt` 只出一个原形。** `fallen` 和 `fällen` 的第三人称单数都是 `fällt`，
但 Hunspell 只能报出 `.dic` 里声明过的内容；没有对应 `st:` 条目的词典就会少给。

**`abzukämpfen` / `abgekämpft` 还原不出来。** 可分动词的 `zu` 和 `ge` 是中缀，
Hunspell 剥不掉，必须用 `st:` 显式标注，见上面的德文词典。

**一个拼写写了两条 `st:`，只回来一个原形。** 如果 `.dic` 把同一个词写了两遍、
`st:` 不同、又都没挂 flag，原版构建只返回第一个：它的 `stem()` 只取一条分析记
录里的第一个 `st:` 字段；词悦打过补丁的版本两条都会保留，见
[「词悦使用的 Hunspell」](../internals/word-forms)。

## 相关

- [词形还原的实现](../internals/word-forms) —— 词悦内置的 Hunspell 补丁、中文异体字表的设计、NFC 归一化，以及直接测试词典。
- [常见问题](./faq) —— 词典与显示相关的问题。
- [快速上手](./getting-started) —— 添加词典。
