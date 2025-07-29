import "package:ciyue/repositories/ai_prompts.dart";
import "package:ciyue/repositories/settings.dart";
import "package:ciyue/services/ai.dart";
import "package:flutter/material.dart";
import "dart:convert";

import "package:dio/dio.dart";
import "package:provider/provider.dart";
import "package:translator/translator.dart";

abstract class TranslationService {
  Future<String> translate(
    BuildContext context, {
    required String text,
    required String sourceLanguage,
    required String targetLanguage,
    required bool isRichOutput,
  });
}

class AITranslationService implements TranslationService {
  @override
  Future<String> translate(
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

    return await ai.request(prompt);
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
  Future<String> translate(
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
    return translation.text;
  }
}

class DeepLXTranslationService implements TranslationService {
  final _dio = Dio();

  static const sourceLanguageCodeMap = {
    "ar": "AR",
    "bg": "BG",
    "cs": "CS",
    "da": "DA",
    "de": "DE",
    "el": "EL",
    "en": "EN",
    "es": "ES",
    "et": "ET",
    "fi": "FI",
    "fr": "FR",
    "he": "HE",
    "hu": "HU",
    "id": "ID",
    "it": "IT",
    "ja": "JA",
    "ko": "KO",
    "lt": "LT",
    "lv": "LV",
    "nb": "NB",
    "nl": "NL",
    "pl": "PL",
    "pt": "PT",
    "ro": "RO",
    "ru": "RU",
    "sk": "SK",
    "sl": "SL",
    "sv": "SV",
    "th": "TH",
    "tr": "TR",
    "uk": "UK",
    "vi": "VI",
    "zh": "ZH",
    "zh_HK": "ZH",
    "zh_TW": "ZH",
  };

  static const targetLanguageCodeMap = {
    "ar": "AR",
    "bg": "BG",
    "cs": "CS",
    "da": "DA",
    "de": "DE",
    "el": "EL",
    "en": "EN-US",
    "en_GB": "EN-GB",
    "en_US": "EN-US",
    "es": "ES",
    "es_419": "ES-419",
    "et": "ET",
    "fi": "FI",
    "fr": "FR",
    "he": "HE",
    "hu": "HU",
    "id": "ID",
    "it": "IT",
    "ja": "JA",
    "ko": "KO",
    "lt": "LT",
    "lv": "LV",
    "nb": "NB",
    "nl": "NL",
    "pl": "PL",
    "pt": "PT-BR",
    "pt_BR": "PT-BR",
    "pt_PT": "PT-PT",
    "ro": "RO",
    "ru": "RU",
    "sk": "SK",
    "sl": "SL",
    "sv": "SV",
    "th": "TH",
    "tr": "TR",
    "uk": "UK",
    "vi": "VI",
    "zh": "ZH-HANS",
    "zh_HK": "ZH-HANT",
    "zh_TW": "ZH-HANT",
  };

  @override
  Future<String> translate(
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

    final response = await _dio.post(
      url,
      data: jsonEncode({
        "text": text,
        "source_lang": sourceLanguageCodeMap[sourceLanguage] ??
            sourceLanguage.toUpperCase(),
        "target_lang": targetLanguageCodeMap[targetLanguage] ??
            targetLanguage.toUpperCase(),
      }),
    );

    if (response.statusCode == 200) {
      return response.data["data"];
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
