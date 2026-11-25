# 快速上手

## 安装

请先安装词悦——正式版与 nightly 构建见[下载](/zh/download)页，支持 Android、Windows、Linux 与 macOS。

## 下载词典

词悦不自带词典。从 Wiki 的[推荐词典](https://github.com/mumu-lhl/Ciyue/wiki#recommended-dictionaries)下载 `.mdx` / `.mdd` 文件，或者 StarDict 词典（`.ifo` / `.idx` / `.dict`），然后在 **设置 → 管理词典** 中添加。[词典格式](./dictionary-formats) 说明了这些文件各自的作用，以及两种格式之间如何转换。

离线百科类词典也可以从 [Kiwix](https://www.kiwix.org/) 获取：到 [dumps.wikimedia.org 的 kiwix/zim 目录](https://dumps.wikimedia.org/other/kiwix/zim/) 下载维基辞典、维基百科、维基文库的 `.zim` 文件。

## 云同步

在多设备间同步单词本、标签、抽认卡和历史记录。见[云同步设置](./cloud-sync)。

## Android 上的 KOReader

在 `koreader` 目录下创建 `dictionaries.lua` 文件：

```lua
{
    { "Ciyue", "Ciyue", false, "org.eu.mumulhl.ciyue", "send" }
}
```
