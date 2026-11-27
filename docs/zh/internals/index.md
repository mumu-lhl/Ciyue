# 实现与原理

词悦内部如何工作——写给想知道「为什么这样做」、而不只是「怎么做」的词典制作者与贡献者。

## 目录

- [词典链接 Scheme 原理](./dictionary-link-schemes) —— GoldenDict-ng、MDict、Babylon 各自如何处理每种 scheme，词悦在何处更进一步。
- [词形还原的实现](./word-forms) —— 词悦内置的 Hunspell 补丁、中文异体字表的设计、UTF-8 编码、NFC 归一化，以及直接测试词典。
