import "dart:convert";

import "package:ciyue/repositories/ai_prompts.dart";
import "package:ciyue/repositories/settings.dart";
import "package:ciyue/services/ai.dart";
import "package:ciyue/models/translation_result.dart";
import "package:flutter/material.dart";

import "package:ciyue/core/http_client.dart";
import "package:provider/provider.dart";
import "package:translator/translator.dart";

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
  }) async {
    final ai = AI(
      provider: settings.aiProvider,
      model: settings.getAiProviderConfig(settings.aiProvider)["model"] ?? "",
      apikey: settings.getAiProviderConfig(settings.aiProvider)["apiKey"] ?? "",
    );

    final sourceLangName = languageMap[sourceLanguage] ?? sourceLanguage;
    final targetLangName = languageMap[targetLanguage] ?? targetLanguage;

    final aiPrompts = context.read<AIPrompts>();
    String template = aiPrompts.translatePrompt;

    if (!isRichOutput) {
      template =
          'Translate this \$sourceLanguage sentence to \$targetLanguage, only return the translated text: "\$text"';
    }

    final prompt = template
        .replaceAll(r"$sourceLanguage", sourceLangName)
        .replaceAll(r"$targetLanguage", targetLangName)
        .replaceAll(r"$text", text);

    final result = await ai.request(prompt);
    return TranslationResult(text: result);
  }
}

class GoogleTranslationService implements TranslationService {
  static const languageCodeMap = {
    "zh": "zh-cn",
    "zh_HK": "zh-tw",
    "zh_TW": "zh-tw",
  };
  final _translator = GoogleTranslator();

  @override
  Future<TranslationResult> translate(
    BuildContext context, {
    required String text,
    required String sourceLanguage,
    required String targetLanguage,
    required bool isRichOutput,
  }) async {
    final translation = await _translator.translate(
      text,
      from: sourceLanguage,
      to: languageCodeMap[targetLanguage] ?? targetLanguage,
    );
    return TranslationResult(text: translation.text);
  }
}

class DeepLXTranslationService implements TranslationService {
  static const languageCodeMap = {
    "auto": "auto",
    "zh_HK": "ZH",
    "zh_TW": "ZH",
  };

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

    final headers = {
      "Content-Type": "application/json",
    };
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
