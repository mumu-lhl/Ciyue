# Translation

Ciyue's translation page translates text between languages. Unlike a traditional single-engine translator, it can ask **many sources at once** — free web services, official APIs, and AI providers — and shows each answer as its own card, so you can compare how Google, DeepL, and an LLM each render the same sentence and pick the best one.

## Using translation

1. Open the translation page and type or paste the text.
2. Pick the source and target languages (the source defaults to auto-detect), or tap the swap button to exchange them.
3. Tap **Translate**. Every enabled source is queried in parallel; cards fill in as answers arrive, fastest first. On desktop, press `Ctrl+Enter` to translate.
4. Each card offers **read aloud** and **copy** actions. Some sources (such as DeepL Free) also return alternative translations, shown as chips under the main result — tap one to copy it.

A failed source only marks its own card; the other results are unaffected.

## Managing sources

Open the translation settings from the translation page to find the source list:

- **Toggle** each source on or off. At least one source must stay enabled.
- **Drag** a source by its handle to reorder it; result cards follow the same order.
- Sources that need configuration show **Configured** / **Not configured**. Expand one to fill in the required fields.
- Enabled sources that are not configured are skipped during translation, with a hint shown under the results.

By default only the provider you used before is enabled, so upgrading does not change your existing behavior.

## Free sources (no API key)

| Source | Notes |
| --- | --- |
| Google | Public web endpoint of Google Translate |
| Microsoft | Microsoft Edge translate endpoint |
| DeepL (Free) | DeepL web endpoint; may return alternative translations |
| Baidu | Baidu Translate web endpoint |
| Tencent | Tencent TransMart web endpoint |
| Volcengine | Volcengine web endpoint |
| Yandex (Free) | Yandex Translate free endpoint |

## Official API sources (your own API key)

| Source | What you need | Where to get it |
| --- | --- | --- |
| DeepL | API key (free keys end with `:fx` and automatically use the free endpoint) | [DeepL API](https://www.deepl.com/pro-api) |
| Google Cloud | Cloud Translation API key | [Google Cloud Console](https://console.cloud.google.com/apis/api/translate.googleapis.com) |
| Azure | Translator key **and** the resource's region | [Azure Portal](https://portal.azure.com/#create/Microsoft.CognitiveServicesTextTranslation) |
| Yandex Cloud | API key **and** folder ID | [Yandex Cloud Console](https://console.cloud.yandex.com/) |
| DeepLX | URL of your own DeepLX instance | [DeepLX](https://github.com/OwO-Network/DeepLX) |

## AI providers as translation sources

Every AI provider configured in **Settings → AI** (OpenAI, Gemini, DeepSeek, Anthropic, OpenRouter, SiliconFlow, Zhipu, xAI, Ollama, and others) is also a translation source. A provider counts as configured when it has a model and an API key in AI Settings (local providers such as Ollama do not need a key). You can enable several AI providers alongside the machine-translation sources and compare their output. AI results are rendered as markdown, which works well with the rich output mode in the translation settings.

## Disclaimer

::: warning Please read
The sources labelled **free** call the public web or client endpoints of the respective services. They are **not** official open APIs. A provider may change, restrict, or shut down such an endpoint at any time, and using it may not comply with the provider's terms of service. These sources are provided as options only; whether to enable them is your decision, and you use them at your own risk.

Sources that require an API key use credentials you obtain yourself. Any fees, quotas, and compliance obligations are between you and the provider.

The text you translate is sent directly to the servers of **every source you enable**. Do not translate content you are not comfortable sharing with those third parties. Ciyue itself does not collect or upload your translation content.
:::

If a free source suddenly stops working, it most likely means the provider changed or blocked the endpoint — not a bug in Ciyue. Disable that source and rely on the others, or switch to an official API source.
