import "package:ciyue/repositories/settings.dart";
import "package:flutter/material.dart";

class AiTranslateSettingsViewModel extends ChangeNotifier {
  late final TextEditingController deeplxUrlController;

  AiTranslateSettingsViewModel() {
    deeplxUrlController = TextEditingController(text: settings.deeplxUrl ?? "");
  }

  String get translationProvider => settings.translationProvider;
  bool get isRichOutput => settings.isRichOutput;
  bool get enableTranslationHistory => settings.enableTranslationHistory;

  Future<void> setEnableTranslationHistory(bool value) async {
    await settings.setEnableTranslationHistory(value);
    notifyListeners();
  }

  Future<void> setTranslationProvider(String provider) async {
    await settings.setTranslationProvider(provider);
    notifyListeners();
  }

  Future<void> setDeeplxUrl(String url) async {
    await settings.setDeeplxUrl(url);
    notifyListeners();
  }

  Future<void> setRichOutput(bool value) async {
    await settings.setRichOutput(value);
    notifyListeners();
  }

  @override
  void dispose() {
    deeplxUrlController.dispose();
    super.dispose();
  }
}
