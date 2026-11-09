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
就会全部列出。

## 怎么开启

1. **设置 → Hunspell** —— 打开「启用词形还原与变体查找」；
2. 导入 `.aff` + `.dic`：选择包含这些文件的文件夹，每种语言一对，应用不内置任何文件；
3. 选择查找模式（见下）。多数人真正想要的是**补充（Supplement）**。

词干查询在独立的 isolate 里执行，开启后不会拖慢界面。

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

## 中文：简体、繁体与异体字

中文没有词形变化，所以中文的 `.dic` 用 `st:` 干另一件事：记录**哪些字是同一个字的
另一种写法**。Ciyue 会**按词、也按字**去读这张表，因此用一种写法输入的查询，能够
命中用另一种写法立的词条。

### `.aff` 保持空壳

```text
SET UTF-8
LANG zh
FLAG long
```

不需要别的：没有词缀规则，也没有复合词设置。此时 Hunspell 就是一张「写法 → 各种
写法」的哈希表，这已经够用。

### 一个字一行，两个方向都写

```text
闲 st:閒
闲 st:閑
閒 st:闲
閑 st:闲
适 st:適
適 st:适
```

两个方向必须都写。`闲 st:閒` 只把 `闲` 指向 `閒`；没有 `閒 st:闲`，反向的
`閒适` → `闲适` 就查不到。单字条目还是「混写」能成立的原因——混写本身不必进表，
因为组合是查询时算出来的：

| 输入 | 从上面这张表展开出的写法 |
| --- | --- |
| `闲适` | `闲适`、`閒適`\*、`閑适`、`閒适`、`闲適`、`閑適` |

\* 来自词级条目，见下一节。其余几个都是按字组合出来的，例如 `闲適` 不需要单独写一行。

### 逐字转换不够时，一个词写一行

```text
闲适 st:閒適
```

词级条目**先于**按字组合被读取，所以制表人指定的那个写法排在前面——哪怕它替换的
字数比按字组合更多。它也是表达「非逐字对应」映射的唯一方式：干/乾/幹、发/髮/發
这类分化，或者繁体写法与简体字数不同的词。

### 这个功能不做什么

- **它是精确查找，不是前缀。** `st:` 映射的是整词，所以输入 `木红` 不会提示一个
  以 `木紅毬` 立目的词条；把 `木红球`（或 `木紅毬`）输完，按字展开才会生效。
  逐键的建议列表仍然按你输入的前缀去查。
- **只有表里覆盖到的写法才可达。** 表里没有的字保持原样——展开只复用 `.dic` 已
  声明的内容，不会自己发明映射。
- **查找模式决定了异体写法什么时候生效。** 「补充」模式下精确词条和它的各种写法
  并列显示；「后备」模式下，只有该词典查不到原样拼写时才会去试那些写法。

### 怎么生成这张表

1. 导出你实际在用的词典的词头。表最好按真实词头生成，因为 `st:` 右侧指向的词条
   如果在任何词典里都不存在，查过去依然是空；
2. 把每个词头转换成标准形——OpenCC `t2s` 是个不错的起点，然后手工校正一对多的
   字（`发` → `髮` / `發`、`干` → `乾` / `幹`）；
3. **每一对两个方向都写**，并补上异体字表里的单字对：

   ```python
   lines.append(f"{variant} st:{standard}")
   lines.append(f"{standard} st:{variant}")
   ```

4. 把结果和上面的空壳 `.aff` 放在一起导入。按一套词典生成的表只认识那套词典的
   词汇，要加入新词典，重新生成一次最省事。

## 编码：`.dic` 用组合形式（NFC）

Ciyue 在把查询交给 Hunspell 之前，会统一归一化到 **NFC**——键盘输入、网页内容
和上面列出的几套词表本来就是这种形式。你自建的 `.dic` 没有这个保证，而
Hunspell 只按字节比较、从不归一化：用分离形式（`e` + U+0301 而不是 `é`）写出来
的词表一条也匹配不上。

症状很隐蔽：词典词条照常显示，但词形永远还原不出来，看上去和「功能没开」一样。
转换一次即可：

```bash
python3 -c "import sys,unicodedata; p=sys.argv[1]; t=open(p,encoding='utf-8').read(); open(p,'w',encoding='utf-8').write(unicodedata.normalize('NFC',t))" de_DE.dic
```

`.aff` 那边帮不上忙：`MAP` 和 `REP` 只作用于 `suggest()`，而唯一能改写输入的
`ICONV` 依赖词表作者主动写。所以归一化放在查询路径上，而不是交给词典。

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

**在命令行里测日文会不对劲。** `hunspell -m`（CLI）在分析时会丢掉汉字部分，
例如 `美味しかった` 会被报成 `しかった st:しかる`；而 Ciyue 和 GoldenDict 用的
库 API 会正确返回 `st:美味しい`。**测试请写一小段 C++ 代码直接调用 Hunspell 的
API，别用命令行的 `hunspell`**——现成的测试程序见下方「测试 Hunspell 词典」。

## 测试 Hunspell 词典

英文和德文用命令行就够了：

```bash
hunspell -d ./en_US -s <<< "hoped"        # -> hope
hunspell -d ./de_DE -s <<< "abgekämpft"   # -> abkämpfen
```

日文才是需要直接调用库的情况：命令行和库在这里行为不一致，想知道一对
`.aff`/`.dic` 实际返回什么，最可靠的办法是直接调用 `analyze()` —— 也就是
Ciyue 和 GoldenDict 用的那个函数。

<details>
<summary>测试程序（C++，约 20 行）</summary>

```cpp
#include <hunspell/hunspell.hxx>
#include <iostream>
#include <vector>
#include <string>

int main(int argc, char * argv[]) {
    if (argc < 4) {
        std::cerr << "Usage: " << argv[0]
                  << " <aff_file> <dic_file> <word>" << std::endl;
        return 1;
    }

    // 创建 Hunspell 实例（传入 .aff 和 .dic 路径）
    Hunspell hunspell(argv[1], argv[2]);

    // 调用 analyze —— GoldenDict 用的就是这个函数；hunspell -m 也调它，
    // 只是命令行那层的输出会把汉字丢掉
    std::vector<std::string> results = hunspell.analyze(argv[3]);

    for (const auto & line : results) {
        std::cout << line << std::endl;
    }

    return 0;
}
```

编译并运行：

```bash
# Debian/Ubuntu
sudo apt install libhunspell-dev
# macOS
brew install hunspell

g++ test_analyze.cpp -o test_analyze $(pkg-config --cflags --libs hunspell)
./test_analyze ja_JP.aff ja_JP.dic 美味しかった
```

输出用的是 Hunspell 自己的格式，例如 `st:美味しい fl:XQ fl:Ta`，其中 `st:` 就是
词形还原会用到的词干。

</details>

## 相关

- [常见问题](./faq) —— 词典与显示相关的问题。
- [快速上手](./getting-started) —— 添加词典。
