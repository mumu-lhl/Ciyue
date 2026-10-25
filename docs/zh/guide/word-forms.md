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

能还原出几个原形，完全取决于你用的 Hunspell 文件——一个形式真有多个词干时，
就会全部列出。

## 怎么开启

1. **设置 → Hunspell** —— 打开「启用词形还原与变体查找」；
2. 导入 `.aff` + `.dic`：选择包含这些文件的文件夹，每种语言一对，应用不内置任何文件；
3. 选择查找模式（见下）。多数人真正想要的是**补充（Supplement）**。

词干查询在独立的 isolate 里执行，开启后不会拖慢界面。

## 后备 vs 补充

| 查询 | 后备（默认） | 补充 |
| --- | --- | --- |
| `rims` | 只显示 `RIMS` 这条词条 | `RIMS` + `rim` |
| `hoped` | 只显示 `hoped` 这条词条 | `hoped` + `hope` |

**后备**的意思是：只有当某本词典没有精确词条时，才去尝试词干。所以一旦词典里
恰好有 `RIMS` 或 `hoped`，原形就永远不会被查出来。**补充**则始终把词干和精确
词条并列显示，这也是 GoldenDict 的行为。

如果同一个词在一种模式下能查到、另一种查不到，先检查这个开关。

## 去哪找 Hunspell 文件

系统（例如Debian）自带的Hunspell词典文件通常只为拼写检查设计，**没有手写的 `st:` 条目**，不规则变形根本无法还原。可用的维护版本：

- 英文：<https://github.com/yx-wh/hunspell_en_US> —— 修正了错误的后缀标签、补齐
  词干链接与派生标签，并扩充了词表。
- 德文：<https://github.com/yx-wh/hunspell_de_DE> —— 为可分动词的分词、`zu`
  不定式补了 2,000 多条 `st:`。
- 日文：<https://github.com/yx-wh/hunspell_ja_JP> —— 由于日文通常无需拼写检查，需要单独为日文设计Hunspell词典文件。这个版本在Gary原始版本的基础上增加了混书形式到汉字的还原（例如「まん延」→「蔓延」）、补充了一些动词的活用、补充了半角假名。


## 常见问题

**打开后毫无变化。** 按顺序检查三件事：开关、是否导入了 `.aff`/`.dic`、当前查找
模式。在「后备」模式下，有精确命中的词看起来和没开这个功能一模一样。

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
