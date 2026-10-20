import "dart:convert";
import "dart:math" as math;

import "package:ciyue/core/app_globals.dart";
import "package:ciyue/core/http_client.dart";
import "package:ciyue/models/translation_result.dart";
import "package:ciyue/repositories/settings.dart";
import "package:ciyue/services/translation.dart";
import "package:material_ui/material_ui.dart";

/// A single translation source in the multi-source system.
///
/// Implementations are protocol adapters ported from kiss-translator
/// (https://github.com/fishjar/kiss-translator), LLM sources excluded.
abstract class TranslationSource {
  const TranslationSource();

  /// Stable id used in prefs (order/enabled lists).
  String get id;

  /// Display name shown in result cards and settings.
  String get name;

  /// Whether this source needs user configuration (API key / URL)
  /// before it can run.
  bool get requiresConfig;

  /// Whether the required configuration is present.
  bool get isConfigured;

  Future<TranslationResult> translate(
    BuildContext context, {
    required String text,
    required String sourceLanguage,
    required String targetLanguage,
  });
}

/// Map Ciyue's internal language codes (`auto`, `en`, `zh`, `zh_HK`,
/// `zh_TW`, `ja`, ...) to a provider's codes. Unknown codes pass through.
String mapLang(Map<String, String> table, String code) => table[code] ?? code;

const googleLangMap = {"zh": "zh-CN", "zh_HK": "zh-TW", "zh_TW": "zh-TW"};

const microsoftLangMap = {
  "zh": "zh-Hans",
  "zh_HK": "zh-Hant",
  "zh_TW": "zh-Hant",
  "auto": "",
};

const deeplLangMap = {"zh": "ZH", "zh_HK": "ZH", "zh_TW": "ZH"};

/// DeepL uses region-specific codes for some target languages.
String deeplTargetLang(String code) {
  switch (code) {
    case "en":
      return "EN-US";
    case "pt":
      return "PT-BR";
    default:
      return mapLang(deeplLangMap, code).toUpperCase();
  }
}

String deeplSourceLang(String code) {
  if (code == "auto") return "";
  return mapLang(deeplLangMap, code).toUpperCase();
}

const baiduLangMap = {
  "zh": "zh",
  "zh_HK": "cht",
  "zh_TW": "cht",
  "ja": "jp",
  "ko": "kor",
  "fr": "fra",
  "es": "spa",
  "bg": "bul",
  "ca": "cat",
  "nb": "nor",
  "hi": "mai",
  "fa": "per",
  "ta": "tam",
  "vi": "vie",
};

const volcengineLangMap = {"zh": "zh", "zh_HK": "zh", "zh_TW": "zh-Hant"};

const yandexLangMap = {
  "zh": "zh",
  "zh_HK": "zh",
  "zh_TW": "zh",
  "nb": "no",
  "auto": "",
};

/// Google Translate free web endpoint (client=gtx), as used by
/// kiss-translator's "Google" source.
class GoogleFreeSource extends TranslationSource {
  const GoogleFreeSource();

  @override
  String get id => "google";

  @override
  String get name => "Google";

  @override
  bool get requiresConfig => false;

  @override
  bool get isConfigured => true;

  @override
  Future<TranslationResult> translate(
    BuildContext context, {
    required String text,
    required String sourceLanguage,
    required String targetLanguage,
  }) async {
    final response = await AppHttp.get(
      "https://translate.googleapis.com/translate_a/single",
      query: {
        "client": "gtx",
        "dt": "t",
        "dj": 1,
        "ie": "UTF-8",
        "sl": mapLang(googleLangMap, sourceLanguage),
        "tl": mapLang(googleLangMap, targetLanguage),
        "q": text,
      },
    );
    final body = response.data;
    final sentences = body["sentences"] as List?;
    if (sentences == null) {
      throw Exception("Unexpected Google response");
    }
    final translated = sentences
        .map((s) => (s as Map)["trans"] as String? ?? "")
        .join(" ");
    return TranslationResult(text: translated);
  }
}

/// Microsoft Edge translate endpoint (no auth), kiss-translator's
/// "Microsoft" source.
class MicrosoftFreeSource extends TranslationSource {
  const MicrosoftFreeSource();

  @override
  String get id => "microsoft";

  @override
  String get name => "Microsoft";

  @override
  bool get requiresConfig => false;

  @override
  bool get isConfigured => true;

  @override
  Future<TranslationResult> translate(
    BuildContext context, {
    required String text,
    required String sourceLanguage,
    required String targetLanguage,
  }) async {
    final response = await AppHttp.post(
      "https://edge.microsoft.com/translate/translatetext",
      query: {
        "from": mapLang(microsoftLangMap, sourceLanguage),
        "to": mapLang(microsoftLangMap, targetLanguage),
        "isEnterpriseClient": false,
      },
      data: jsonEncode([text]),
    );
    final body = response.data as List;
    final first = body.first as Map;
    final translations = first["translations"] as List;
    final translated = translations
        .map((t) => (t as Map)["text"] as String? ?? "")
        .join(" ");
    return TranslationResult(text: translated);
  }
}

/// Baidu Translate web endpoint (fanyi.baidu.com/transapi).
class BaiduFreeSource extends TranslationSource {
  const BaiduFreeSource();

  @override
  String get id => "baidu";

  @override
  String get name => "Baidu";

  @override
  bool get requiresConfig => false;

  @override
  bool get isConfigured => true;

  @override
  Future<TranslationResult> translate(
    BuildContext context, {
    required String text,
    required String sourceLanguage,
    required String targetLanguage,
  }) async {
    final form =
        "from=${Uri.encodeQueryComponent(mapLang(baiduLangMap, sourceLanguage))}"
        "&to=${Uri.encodeQueryComponent(mapLang(baiduLangMap, targetLanguage))}"
        "&query=${Uri.encodeQueryComponent(text)}"
        "&source=txt";
    final response = await AppHttp.post(
      "https://fanyi.baidu.com/transapi",
      headers: {
        "Content-Type": "application/x-www-form-urlencoded; charset=UTF-8",
        "User-Agent":
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
            "AppleWebKit/537.36 (KHTML, like Gecko) "
            "Chrome/110.0.0.0 Safari/537.36",
      },
      data: form,
    );
    final body = response.data;
    final type = body["type"];
    if (type == 2) {
      final data = body["data"] as List;
      final translated = data
          .map((d) => (d as Map)["dst"] as String? ?? "")
          .join(" ");
      return TranslationResult(text: translated);
    } else if (type == 1) {
      // Dictionary-style result for single words.
      final result = json.decode(body["result"] as String) as Map;
      final content = (result["content"] as List).first as Map;
      final mean = ((content["mean"] as List).first as Map)["cont"] as Map;
      return TranslationResult(text: mean.keys.first as String);
    }
    throw Exception("Unexpected Baidu response: $body");
  }
}

/// Tencent TransMart web endpoint (transmart.qq.com/api/imt).
class TencentFreeSource extends TranslationSource {
  const TencentFreeSource();

  @override
  String get id => "tencent";

  @override
  String get name => "Tencent";

  @override
  bool get requiresConfig => false;

  @override
  bool get isConfigured => true;

  @override
  Future<TranslationResult> translate(
    BuildContext context, {
    required String text,
    required String sourceLanguage,
    required String targetLanguage,
  }) async {
    final response = await AppHttp.post(
      "https://transmart.qq.com/api/imt",
      headers: {
        "Content-Type": "application/json",
        "User-Agent":
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
            "AppleWebKit/537.36 (KHTML, like Gecko) "
            "Chrome/110.0.0.0 Safari/537.36",
        "Referer": "https://transmart.qq.com/zh-CN/index",
      },
      data: jsonEncode({
        "header": {
          "fn": "auto_translation",
          "client_key":
              "browser-chrome-110.0.0-Mac OS-"
              "df4bd4c5-a65d-44b2-a40f-42f34f3535f2-1677486696487",
        },
        "type": "plain",
        "model_category": "normal",
        "source": {
          "text_list": [text],
          "lang": sourceLanguage,
        },
        "target": {"lang": targetLanguage},
      }),
    );
    final body = response.data;
    final list = body["auto_translation"] as List?;
    if (list == null || list.isEmpty) {
      throw Exception("Unexpected Tencent response");
    }
    return TranslationResult(text: list.cast<String>().join(" "));
  }
}

/// Volcengine (ByteDance) web translate endpoint (crx API).
class VolcengineFreeSource extends TranslationSource {
  const VolcengineFreeSource();

  @override
  String get id => "volcengine";

  @override
  String get name => "Volcengine";

  @override
  bool get requiresConfig => false;

  @override
  bool get isConfigured => true;

  @override
  Future<TranslationResult> translate(
    BuildContext context, {
    required String text,
    required String sourceLanguage,
    required String targetLanguage,
  }) async {
    final response = await AppHttp.post(
      "https://translate.volcengine.com/crx/translate/v1",
      data: jsonEncode({
        "source_language": mapLang(volcengineLangMap, sourceLanguage),
        "target_language": mapLang(volcengineLangMap, targetLanguage),
        "text": text,
      }),
    );
    final body = response.data;
    final translated = body["translation"] as String?;
    if (translated == null) {
      throw Exception("Unexpected Volcengine response");
    }
    return TranslationResult(text: translated);
  }
}

/// Yandex Translate free endpoint (translate.yandex.net, android srv).
class YandexFreeSource extends TranslationSource {
  const YandexFreeSource();

  @override
  String get id => "yandexFree";

  @override
  String get name => "Yandex (Free)";

  @override
  bool get requiresConfig => false;

  @override
  bool get isConfigured => true;

  @override
  Future<TranslationResult> translate(
    BuildContext context, {
    required String text,
    required String sourceLanguage,
    required String targetLanguage,
  }) async {
    final random = math.Random();
    final idBuffer = StringBuffer();
    for (var i = 0; i < 32; i++) {
      idBuffer.write(random.nextInt(16).toRadixString(16));
    }
    final response = await AppHttp.post(
      "https://translate.yandex.net/api/v1/tr.json/translate",
      query: {
        "id": "${idBuffer.toString()}-0-0",
        "srv": "android",
        "source_lang": mapLang(yandexLangMap, sourceLanguage),
        "target_lang": mapLang(yandexLangMap, targetLanguage),
        "text": text,
      },
    );
    final body = response.data;
    final list = body["text"] as List?;
    if (list == null || list.isEmpty) {
      throw Exception("Unexpected Yandex response: $body");
    }
    return TranslationResult(text: list.first as String);
  }
}

/// DeepL free web endpoint (www2.deepl.com JSON-RPC, iOS client
/// impersonation + timestamp signature, as in kiss-translator).
/// Returns up to 3 alternative translations when available.
class DeepLFreeSource extends TranslationSource {
  const DeepLFreeSource();

  static int _requestId = 10000;

  @override
  String get id => "deeplFree";

  @override
  String get name => "DeepL (Free)";

  @override
  bool get requiresConfig => false;

  @override
  bool get isConfigured => true;

  @override
  Future<TranslationResult> translate(
    BuildContext context, {
    required String text,
    required String sourceLanguage,
    required String targetLanguage,
  }) async {
    // DeepL anti-bot check: the timestamp must be divisible by the
    // number of "i" characters in the text (+1).
    final iCount = "i".allMatches(text).length + 1;
    var timestamp = DateTime.now().millisecondsSinceEpoch;
    timestamp = timestamp + (iCount - (timestamp % iCount));
    _requestId++;

    final to = deeplTargetLang(targetLanguage);
    final body = {
      "jsonrpc": "2.0",
      "method": "LMT_handle_texts",
      "params": {
        "splitting": "newlines",
        "lang": {
          "target_lang": to,
          "source_lang_user_selected": deeplSourceLang(sourceLanguage),
        },
        "commonJobParams": {
          "wasSpoken": false,
          "transcribe_as": "",
          if (targetLanguage == "zh") "regionalVariant": "zh-Hans",
          if (targetLanguage == "zh_TW" || targetLanguage == "zh_HK")
            "regionalVariant": "zh-Hant",
        },
        "id": _requestId,
        "timestamp": timestamp,
        "texts": [
          {"text": text, "requestAlternatives": 3},
        ],
      },
    };

    final response = await AppHttp.post(
      "https://www2.deepl.com/jsonrpc",
      headers: {
        "Content-Type": "application/json",
        "Accept": "*/*",
        "x-app-os-name": "iOS",
        "x-app-os-version": "16.3.0",
        "Accept-Language": "en-US,en;q=0.9",
        "x-app-device": "iPhone13,2",
        "User-Agent": "DeepL-iOS/2.9.1 iOS 16.3.0 (iPhone13,2)",
        "x-app-build": "510265",
        "x-app-version": "2.9.1",
      },
      data: jsonEncode(body),
    );
    final result = (response.data as Map)["result"] as Map?;
    final texts = result?["texts"] as List?;
    if (texts == null || texts.isEmpty) {
      throw Exception("Unexpected DeepL response");
    }
    final first = texts.first as Map;
    final alternatives = (first["alternatives"] as List? ?? [])
        .map((a) => (a as Map)["text"] as String? ?? "")
        .where((t) => t.isNotEmpty)
        .toList();
    return TranslationResult(
      text: first["text"] as String,
      alternatives: alternatives,
    );
  }
}

/// DeepL official API (api-free.deepl.com / api.deepl.com).
/// Free keys end with ":fx" and use the free endpoint.
class DeepLSource extends TranslationSource {
  const DeepLSource();

  @override
  String get id => "deepl";

  @override
  String get name => "DeepL";

  @override
  bool get requiresConfig => true;

  @override
  bool get isConfigured => (settings.deeplApiKey ?? "").isNotEmpty;

  @override
  Future<TranslationResult> translate(
    BuildContext context, {
    required String text,
    required String sourceLanguage,
    required String targetLanguage,
  }) async {
    final key = settings.deeplApiKey!;
    final host = key.endsWith(":fx")
        ? "https://api-free.deepl.com"
        : "https://api.deepl.com";
    final source = deeplSourceLang(sourceLanguage);
    final response = await AppHttp.post(
      "$host/v2/translate",
      headers: {
        "Content-Type": "application/json",
        "Authorization": "DeepL-Auth-Key $key",
      },
      data: jsonEncode({
        "text": [text],
        "target_lang": deeplTargetLang(targetLanguage),
        if (source.isNotEmpty) "source_lang": source,
      }),
    );
    final translations = (response.data as Map)["translations"] as List;
    return TranslationResult(
      text: (translations.first as Map)["text"] as String,
    );
  }
}

/// Google Cloud Translation API (requires API key).
class GoogleCloudSource extends TranslationSource {
  const GoogleCloudSource();

  @override
  String get id => "googleCloud";

  @override
  String get name => "Google Cloud";

  @override
  bool get requiresConfig => true;

  @override
  bool get isConfigured => (settings.googleCloudApiKey ?? "").isNotEmpty;

  @override
  Future<TranslationResult> translate(
    BuildContext context, {
    required String text,
    required String sourceLanguage,
    required String targetLanguage,
  }) async {
    final response = await AppHttp.post(
      "https://translation.googleapis.com/language/translate/v2",
      headers: {
        "Content-Type": "application/json",
        "X-Goog-Api-Key": settings.googleCloudApiKey!,
      },
      data: jsonEncode({
        "q": [text],
        "target": mapLang(googleLangMap, targetLanguage),
        "format": "text",
        if (sourceLanguage != "auto")
          "source": mapLang(googleLangMap, sourceLanguage),
      }),
    );
    final translations =
        ((response.data as Map)["data"] as Map)["translations"] as List;
    return TranslationResult(
      text: (translations.first as Map)["translatedText"] as String,
    );
  }
}

/// Microsoft Azure Translator (requires key + region).
class AzureSource extends TranslationSource {
  const AzureSource();

  @override
  String get id => "azure";

  @override
  String get name => "Azure";

  @override
  bool get requiresConfig => true;

  @override
  bool get isConfigured =>
      (settings.azureApiKey ?? "").isNotEmpty &&
      (settings.azureRegion ?? "").isNotEmpty;

  @override
  Future<TranslationResult> translate(
    BuildContext context, {
    required String text,
    required String sourceLanguage,
    required String targetLanguage,
  }) async {
    final from = mapLang(microsoftLangMap, sourceLanguage);
    final response = await AppHttp.post(
      "https://api.cognitive.microsofttranslator.com/translate",
      query: {
        "api-version": "3.0",
        if (from.isNotEmpty) "from": from,
        "to": mapLang(microsoftLangMap, targetLanguage),
      },
      headers: {
        "Content-Type": "application/json",
        "Ocp-Apim-Subscription-Key": settings.azureApiKey!,
        "Ocp-Apim-Subscription-Region": settings.azureRegion!,
      },
      data: jsonEncode([
        {"Text": text},
      ]),
    );
    final body = response.data as List;
    final translations = (body.first as Map)["translations"] as List;
    return TranslationResult(
      text: (translations.first as Map)["text"] as String,
    );
  }
}

/// Yandex Cloud Translate API (requires API key + folder id).
class YandexCloudSource extends TranslationSource {
  const YandexCloudSource();

  @override
  String get id => "yandex";

  @override
  String get name => "Yandex Cloud";

  @override
  bool get requiresConfig => true;

  @override
  bool get isConfigured =>
      (settings.yandexApiKey ?? "").isNotEmpty &&
      (settings.yandexFolderId ?? "").isNotEmpty;

  @override
  Future<TranslationResult> translate(
    BuildContext context, {
    required String text,
    required String sourceLanguage,
    required String targetLanguage,
  }) async {
    final response = await AppHttp.post(
      "https://translate.api.cloud.yandex.net/translate/v2/translate",
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Api-Key ${settings.yandexApiKey!}",
      },
      data: jsonEncode({
        "folderId": settings.yandexFolderId!,
        "texts": [text],
        "targetLanguageCode": mapLang(yandexLangMap, targetLanguage),
        if (sourceLanguage != "auto")
          "sourceLanguageCode": mapLang(yandexLangMap, sourceLanguage),
      }),
    );
    final translations = (response.data as Map)["translations"] as List;
    return TranslationResult(
      text: (translations.first as Map)["text"] as String,
    );
  }
}

/// Adapters wrapping the pre-existing services (AI / DeepLX) so every
/// source shares one interface.
class AiSource extends TranslationSource {
  const AiSource();

  @override
  String get id => "ai";

  @override
  String get name => "AI";

  @override
  bool get requiresConfig => false;

  @override
  bool get isConfigured => true;

  @override
  Future<TranslationResult> translate(
    BuildContext context, {
    required String text,
    required String sourceLanguage,
    required String targetLanguage,
  }) {
    return AITranslationService().translate(
      context,
      text: text,
      sourceLanguage: sourceLanguage,
      targetLanguage: targetLanguage,
      isRichOutput: settings.isRichOutput,
    );
  }
}

class DeepLXSource extends TranslationSource {
  const DeepLXSource();

  @override
  String get id => "deeplx";

  @override
  String get name => "DeepLX";

  @override
  bool get requiresConfig => true;

  @override
  bool get isConfigured => (settings.deeplxUrl ?? "").isNotEmpty;

  @override
  Future<TranslationResult> translate(
    BuildContext context, {
    required String text,
    required String sourceLanguage,
    required String targetLanguage,
  }) {
    return DeepLXTranslationService().translate(
      context,
      text: text,
      sourceLanguage: sourceLanguage,
      targetLanguage: targetLanguage,
      isRichOutput: settings.isRichOutput,
    );
  }
}

/// All available sources, in default display order.
const List<TranslationSource> allTranslationSources = [
  AiSource(),
  GoogleFreeSource(),
  MicrosoftFreeSource(),
  DeepLFreeSource(),
  BaiduFreeSource(),
  TencentFreeSource(),
  VolcengineFreeSource(),
  YandexFreeSource(),
  DeepLXSource(),
  DeepLSource(),
  GoogleCloudSource(),
  AzureSource(),
  YandexCloudSource(),
];

TranslationSource? translationSourceById(String id) {
  for (final s in allTranslationSources) {
    if (s.id == id) return s;
  }
  return null;
}

/// User's multi-source configuration: which sources are enabled and in
/// what order results appear. Stored as JSON lists in prefs.
class TranslationSourcesConfig {
  static const _orderKey = "translationSourceOrder";
  static const _enabledKey = "translationSourcesEnabled";

  /// Source ids in display order (all known sources).
  static List<String> loadOrder() {
    final defaults = allTranslationSources.map((s) => s.id).toList();
    try {
      final raw = prefs.getString(_orderKey);
      if (raw == null) return defaults;
      final saved = (json.decode(raw) as List).cast<String>();
      // Keep saved order, append any new sources at the end.
      final ordered = saved.where((id) => defaults.contains(id)).toList();
      for (final id in defaults) {
        if (!ordered.contains(id)) ordered.add(id);
      }
      return ordered;
    } catch (_) {
      return defaults;
    }
  }

  /// Enabled source ids. Defaults to the legacy single provider so
  /// existing users see no behavior change.
  static List<String> loadEnabled() {
    try {
      final raw = prefs.getString(_enabledKey);
      if (raw == null) {
        final legacy = settings.translationProvider;
        return [if (translationSourceById(legacy) != null) legacy else "ai"];
      }
      final saved = (json.decode(raw) as List).cast<String>();
      return saved.where((id) => translationSourceById(id) != null).toList();
    } catch (_) {
      return ["ai"];
    }
  }

  static Future<void> saveOrder(List<String> order) async {
    await prefs.setString(_orderKey, json.encode(order));
  }

  static Future<void> saveEnabled(List<String> enabled) async {
    await prefs.setString(_enabledKey, json.encode(enabled));
  }

  /// Sources to query, in display order: enabled and configured.
  /// Unconfigured key sources are returned separately so the UI can
  /// hint at why they were skipped.
  static ({List<TranslationSource> active, List<TranslationSource> skipped})
  resolve() {
    final order = loadOrder();
    final enabled = loadEnabled().toSet();
    final active = <TranslationSource>[];
    final skipped = <TranslationSource>[];
    for (final id in order) {
      if (!enabled.contains(id)) continue;
      final source = translationSourceById(id)!;
      if (source.isConfigured) {
        active.add(source);
      } else {
        skipped.add(source);
      }
    }
    return (active: active, skipped: skipped);
  }
}
