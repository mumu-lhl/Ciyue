import "dart:convert";

import "package:ciyue/repositories/settings.dart";
import "package:ciyue/services/ai.dart";
import "package:ciyue/models/translation_result.dart";
import "package:material_ui/material_ui.dart";

import "package:ciyue/core/http_client.dart";
import "package:ciyue/core/providers.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

abstract class TranslationService {
  Future<TranslationResult> translate(
    BuildContext context, {
    required String text,
    required String sourceLanguage,
    required String targetLanguage,
    required bool isRichOutput,
  });
}

class AITranslationService implements TranslationService {
  @override
  Future<TranslationResult> translate(
    BuildContext context, {
    required String text,
    required String sourceLanguage,
    required String targetLanguage,
    required bool isRichOutput,
    String? providerOverride,
  }) async {
    final provider = providerOverride ?? settings.aiProvider;
    final ai = AI(
      provider: provider,
      model: settings.getAiProviderConfig(provider)["model"] ?? "",
      apikey: settings.getAiProviderConfig(provider)["apiKey"] ?? "",
    );

    final sourceLangName = languageMap[sourceLanguage] ?? sourceLanguage;
    final targetLangName = languageMap[targetLanguage] ?? targetLanguage;

    final aiPrompts = ProviderScope.containerOf(
      context,
      listen: false,
    ).read(aiPromptsProvider);
    String template = aiPrompts.translatePrompt;

    if (!isRichOutput) {
      template = 'Translate this \$sourceLanguage sentence to \$targetLanguage, only return the translated text: "\$text"';
    }

    final prompt = template
        .replaceAll(r"$sourceLanguage", sourceLangName)
        .replaceAll(r"$targetLanguage", targetLangName)
        .replaceAll(r"$text", text);

    final result = await ai.request(prompt);
    return TranslationResult(text: result);
  }
}

class DeepLXTranslationService implements TranslationService {
  static const languageCodeMap = {"auto": "auto", "zh_HK": "ZH", "zh_TW": "ZH"};

  @override
  Future<TranslationResult> translate(
    BuildContext context, {
    required String text,
    required String sourceLanguage,
    required String targetLanguage,
    required bool isRichOutput,
  }) async {
    final url = settings.deeplxUrl;
    if (url == null || url.isEmpty) {
      throw Exception("DeepLX URL is not configured.");
    }

    final headers = {"Content-Type": "application/json"};
    final data = {
      "text": text,
      "source_lang":
          languageCodeMap[sourceLanguage] ?? sourceLanguage.toUpperCase(),
      "target_lang":
          languageCodeMap[targetLanguage] ?? targetLanguage.toUpperCase(),
    };

    final response = await AppHttp.post(
      url,
      headers: headers,
      data: jsonEncode(data),
    );

    if (response.statusCode == 200) {
      final body = response.data;
      final primary = body["data"];
      final alternatives = (body["alternatives"] is List<String>)
          ? body["alternatives"] as List<String>
          : const <String>[];
      return TranslationResult(text: primary, alternatives: alternatives);
    } else {
      throw Exception("Failed to translate with DeepLX: ${response.data}");
    }
  }
}

const languageMap = {
  "auto": "Auto Detect",
  "en": "English",
  "zh": "简体中文",
  "zh_HK": "繁體中文",
  "zh_TW": "正體中文",
  "ja": "Japanese",
  "ko": "Korean",
  "fr": "French",
  "de": "Deutsch",
  "es": "Español",
  "ru": "Русский",
  "hi": "Hindi",
  "bn": "Bengali",
  "ca": "Catalan",
  "nb": "Bokmål",
  "sc": "Sardinian",
  "ta": "Tamil",
  "fa": "فارسی",
  "bg": "Bulgarian",
  "vi": "Tiếng Việt",
};
