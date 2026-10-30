# 词条内链接

词悦遵循 MDict 与 GoldenDict 词典已有的链接约定。本文列出支持的写法，以及
词悦额外增加的一个转义规则。

## 词条链接

| 链接 | 跳转目标 |
| --- | --- |
| `entry://word` | 词条 `word` |
| `bword://word` | 与 `entry://word` 相同（Babylon 写法） |
| `entry://word#anchor` | 词条 `word`，并滚动到 `anchor` 位置 |
| `entry://#anchor` | 当前已显示的词条，滚动到 `anchor` 位置 |
| `entry://word##anchor` | 名字就是 `word#anchor` 的词条 |

`bword://` 的行为与 `entry://` 完全一致，上表每一种写法都有对应的 `bword://`
形式。

## 词条名本身含 `#`

单个 `#` 永远用来分隔词条名与锚点。因此，词条名本身含 `#` 时必须写成两个 `#`
来转义：

| 词条名 | 写法 |
| --- | --- |
| `tag#sumeru` | `entry://tag##sumeru` |

转义与分隔可以组合使用：`entry://tag##sumeru#x` 打开词条 `tag#sumeru` 并滚动到
`x`；`entry://tag###sumeru` 则打开词条 `tag#` 并滚动到 `sumeru`。

这个转义规则是词悦特有的。GoldenDict-ng 同样在 `#` 处切分，但它没有办法定位到
名字含 `#` 的词条。

## 说明

- 锚点只负责滚动，不进入浏览历史：返回时不会再次触发滚动。
- 不含词条名的链接只滚动当前词条，不会发起查词。
- 锚点会同时匹配 `id` 与 `name` 属性，两种写法都能定位。
- 锚点属于链接所在词典的词条：同组内其他词典即使也有这个词条，也不会替它滚动。

## 音频与视频

音频引用沿用 MDict 的写法 `<a href="sound://file.mp3">…</a>`，从词典的 `.mdd`
或 StarDict 的 `res/` 资源中播放。
