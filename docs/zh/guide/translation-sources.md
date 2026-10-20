# 翻译源

词悦的翻译页可以同时向多个翻译源查询。所有启用的源会被并行请求，每个结果单独成卡展示——你可以把 Google、DeepL 和某个大模型对同一句话的翻译并排比较。

## 管理翻译源

打开翻译页，点右上角设置图标，即可看到**翻译源**列表：

- **开关**：逐个启用/停用翻译源，至少保留一个启用。
- **排序**：按住拖动手柄调整顺序，结果卡片按同一顺序排列。
- **配置**：需要配置的源会显示「已配置 / 未配置」。展开后填写所需字段。
- 已启用但未配置的源在翻译时会被跳过，并在结果下方给出提示。

升级后默认只启用你原来用的那个源，原有行为不变。

## 免费源（无需 API Key）

| 源 | 说明 |
| --- | --- |
| Google | Google 翻译的网页公开接口 |
| Microsoft | Microsoft Edge 翻译接口 |
| DeepL (Free) | DeepL 网页接口，可能返回多个备选译文 |
| Baidu | 百度翻译网页接口 |
| Tencent | 腾讯翻译君（TransMart）网页接口 |
| Volcengine | 火山翻译网页接口 |
| Yandex (Free) | Yandex 翻译免费接口 |

## 官方 API 源（自备 API Key）

| 源 | 需要什么 | 申请入口 |
| --- | --- | --- |
| DeepL | API Key（免费版 key 以 `:fx` 结尾，会自动使用免费端点） | [DeepL API](https://www.deepl.com/pro-api) |
| Google Cloud | Cloud Translation API Key | [Google Cloud 控制台](https://console.cloud.google.com/apis/api/translate.googleapis.com) |
| Azure | 翻译资源 Key **和**资源所在区域 | [Azure 门户](https://portal.azure.com/#create/Microsoft.CognitiveServicesTextTranslation) |
| Yandex Cloud | API Key **和**文件夹 ID | [Yandex Cloud 控制台](https://console.cloud.yandex.com/) |
| DeepLX | 你自建的 DeepLX 实例 URL | [DeepLX](https://github.com/OwO-Network/DeepLX) |

## AI 服务商作为翻译源

在**设置 → AI** 中配置过的每个 AI 服务商（OpenAI、Gemini、DeepSeek、Anthropic、OpenRouter、SiliconFlow、智谱、xAI、Ollama 等）也都是一个翻译源。判定「已配置」的标准是 AI 设置里填了模型和 API Key（Ollama 等本地服务不需要 Key）。你可以同时启用多个 AI 服务商，和机器翻译源放在一起对比效果。

## 免责声明

::: warning 请仔细阅读
标注为**免费**的翻译源调用的是各服务商网页端或客户端的公开接口，**并非**服务商提供的官方开放 API。服务商可能随时变更、限制或终止这类接口，使用它们也可能不符合相应服务商的服务条款。本应用仅将它们作为可选项提供，是否启用由您自行决定，相关风险由您自行承担。

需要 API Key 的源使用您自行申请的凭据，产生的费用、配额与合规责任由您与服务商之间解决。

您输入的翻译文本会被直接发送至您所启用的**每个**翻译源的服务器，请勿翻译您不希望第三方处理的内容。词悦本身不收集、不上传您的翻译内容。
:::

如果某个免费源突然不能用了，多半是服务商变更或封禁了接口，并不是词悦的 bug。请停用该源、改用其他源，或换成官方 API 源。
