import "package:ciyue/repositories/settings.dart";
import "package:ciyue/services/translation_sources.dart";
import "package:material_ui/material_ui.dart";

class AiTranslateSettingsViewModel extends ChangeNotifier {
  late final TextEditingController deeplxUrlController;
  late final TextEditingController deeplApiKeyController;
  late final TextEditingController googleCloudApiKeyController;
  late final TextEditingController azureApiKeyController;
  late final TextEditingController azureRegionController;
  late final TextEditingController yandexApiKeyController;
  late final TextEditingController yandexFolderIdController;

  /// Source ids in display order; enabled set.
  List<String> sourceOrder = TranslationSourcesConfig.loadOrder();
  Set<String> enabledSources = TranslationSourcesConfig.loadEnabled().toSet();

  AiTranslateSettingsViewModel() {
    deeplxUrlController = TextEditingController(text: settings.deeplxUrl ?? "");
    deeplApiKeyController = TextEditingController(
      text: settings.deeplApiKey ?? "",
    );
    googleCloudApiKeyController = TextEditingController(
      text: settings.googleCloudApiKey ?? "",
    );
    azureApiKeyController = TextEditingController(
      text: settings.azureApiKey ?? "",
    );
    azureRegionController = TextEditingController(
      text: settings.azureRegion ?? "",
    );
    yandexApiKeyController = TextEditingController(
      text: settings.yandexApiKey ?? "",
    );
    yandexFolderIdController = TextEditingController(
      text: settings.yandexFolderId ?? "",
    );
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

  Future<void> setSourceEnabled(String id, bool enabled) async {
    if (enabled) {
      enabledSources.add(id);
    } else {
      // Keep at least one source enabled.
      if (enabledSources.length <= 1) return;
      enabledSources.remove(id);
    }
    await TranslationSourcesConfig.saveEnabled(enabledSources.toList());
    notifyListeners();
  }

  Future<void> reorderSources(int oldIndex, int newIndex) async {
    final order = List<String>.of(sourceOrder);
    final item = order.removeAt(oldIndex);
    order.insert(newIndex, item);
    sourceOrder = order;
    await TranslationSourcesConfig.saveOrder(order);
    notifyListeners();
  }

  Future<void> setDeeplApiKey(String value) async {
    await settings.setDeeplApiKey(value);
    notifyListeners();
  }

  Future<void> setGoogleCloudApiKey(String value) async {
    await settings.setGoogleCloudApiKey(value);
    notifyListeners();
  }

  Future<void> setAzureApiKey(String value) async {
    await settings.setAzureApiKey(value);
    notifyListeners();
  }

  Future<void> setAzureRegion(String value) async {
    await settings.setAzureRegion(value);
    notifyListeners();
  }

  Future<void> setYandexApiKey(String value) async {
    await settings.setYandexApiKey(value);
    notifyListeners();
  }

  Future<void> setYandexFolderId(String value) async {
    await settings.setYandexFolderId(value);
    notifyListeners();
  }

  @override
  void dispose() {
    deeplxUrlController.dispose();
    deeplApiKeyController.dispose();
    googleCloudApiKeyController.dispose();
    azureApiKeyController.dispose();
    azureRegionController.dispose();
    yandexApiKeyController.dispose();
    yandexFolderIdController.dispose();
    super.dispose();
  }
}
