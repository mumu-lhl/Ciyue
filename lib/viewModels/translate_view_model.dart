import "dart:ui" as ui;

import "package:ciyue/core/app_router.dart";
import "package:ciyue/database/app/daos.dart";
import "package:ciyue/repositories/settings.dart";
import "package:ciyue/services/translation.dart";
import "package:flutter/material.dart";
import "package:provider/provider.dart";

class AiTranslateViewModel extends ChangeNotifier {
  final TextEditingController inputController = TextEditingController();
  String _sourceLanguage = "auto";
  String _targetLanguage = settings.language! == "system"
      ? ui.PlatformDispatcher.instance.locale.languageCode
      : settings.language!;
  String _translatedText = "";
  List<String> _alternativeTexts = const [];
  bool _isLoading = false;
  bool _isError = false;

  AiTranslateViewModel() {
    inputController.addListener(() {
      notifyListeners();
    });
  }

  bool get isRichOutput => settings.isRichOutput;
  String get sourceLanguage => _sourceLanguage;
  String get targetLanguage => _targetLanguage;
  String get translatedText => _translatedText;
  List<String> get alternativeTexts => _alternativeTexts;
  bool get isLoading => _isLoading;
  bool get isError => _isError;
  String get translationProvider => settings.translationProvider;

  void setSourceLanguage(String value) {
    _sourceLanguage = value;
    notifyListeners();
  }

  void setTargetLanguage(String value) {
    _targetLanguage = value;
    notifyListeners();
  }

  void swapLanguages() {
    if (_sourceLanguage == "auto") {
      _sourceLanguage = ui.PlatformDispatcher.instance.locale.languageCode;
    }
    final temp = _sourceLanguage;
    _sourceLanguage = _targetLanguage;
    _targetLanguage = temp;
    notifyListeners();
  }

  String getLanguageName(String code) {
    return languageMap[code] ?? code;
  }

  Future<void> setTranslationProvider(String provider) async {
    await settings.setTranslationProvider(provider);
    notifyListeners();
  }

  Future<void> translateText(BuildContext context) async {
    if (inputController.text.trim().isEmpty) return;
    _isLoading = true;
    _translatedText = "";
    _alternativeTexts = const [];
    _isError = false;
    notifyListeners();

    try {
      if (settings.enableTranslationHistory) {
        Provider.of<TranslateHistoryDao>(navigatorKey.currentContext!,
                listen: false)
            .addHistory(inputController.text.trim());
      }

      TranslationService service;
      switch (settings.translationProvider) {
        case "google":
          service = GoogleTranslationService();
          break;
        case "deeplx":
          service = DeepLXTranslationService();
          break;
        default:
          service = AITranslationService();
      }

      final translationResult = await service.translate(
        context,
        text: inputController.text.trim(),
        sourceLanguage: _sourceLanguage,
        targetLanguage: _targetLanguage,
        isRichOutput: settings.isRichOutput,
      );

      _translatedText = translationResult.text;
      // _alternativeTexts = translationResult.alternatives;
      _alternativeTexts = ["Good, morning!"];
    } catch (e) {
      _translatedText = "Error: Failed to translate. $e";
      _alternativeTexts = const [];
      _isError = true;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
