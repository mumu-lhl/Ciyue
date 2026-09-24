import "package:ciyue/core/app_globals.dart";
import "package:ciyue/models/ai/ai.dart";
import "package:ciyue/repositories/ai_prompts.dart";
import "package:ciyue/repositories/settings.dart";
import "package:ciyue/services/ai.dart";
import "package:ciyue/viewModels/home.dart";
import "package:material_ui/material_ui.dart";

class AISettingsViewModel with ChangeNotifier {
  late String _provider;
  final AIPrompts _aiPrompts;
  final HomeModel _homeModel;

  late final TextEditingController apiKeyController;
  late final TextEditingController modelController;
  late final TextEditingController apiUrlController;

  bool _isFetchingModels = false;
  bool get isFetchingModels => _isFetchingModels;

  String? _fetchError;
  String? get fetchError => _fetchError;

  List<ModelInfo> get currentModels =>
      ModelProviderManager.getModels(_provider);

  AISettingsViewModel(this._aiPrompts, this._homeModel) {
    apiKeyController = TextEditingController();
    modelController = TextEditingController();
    apiUrlController = TextEditingController();

    _provider = settings.aiProvider;
    if (ModelProviderManager.modelProviders[_provider] == null) {
      _provider = ModelProviderManager.modelProviders.values.first.name;
      settings.aiProvider = _provider;
      prefs.setString("aiProvider", _provider);
    }

    final config = settings.getAiProviderConfig(_provider);
    modelController.text = config["model"] ?? "";
    apiKeyController.text = config["apiKey"] ?? "";
    apiUrlController.text = settings.aiAPIUrl;

    final currentProvider = ModelProviderManager.modelProviders[_provider]!;
    final availableModels = currentModels;
    if (!availableModels.any((m) => m.originName == modelController.text) &&
        !currentProvider.allowCustomModel &&
        availableModels.isNotEmpty) {
      modelController.text = availableModels[0].originName;
      _saveAiProviderConfig();
    }
  }

  String get provider => _provider;
  String get model => modelController.text;
  String get apiKey => apiKeyController.text;
  bool get explainWord => settings.aiExplainWord;
  AIPrompts get aiPrompts => _aiPrompts;

  void _saveAiProviderConfig() {
    settings.saveAiProviderConfig(
      _provider,
      modelController.text,
      apiKeyController.text,
    );
    notifyListeners();
  }

  void setProvider(String newProvider) {
    _provider = newProvider;
    settings.aiProvider = newProvider;
    prefs.setString("aiProvider", newProvider);

    final config = settings.getAiProviderConfig(_provider);
    modelController.text = config["model"] ?? "";
    final currentProvider =
        ModelProviderManager.modelProviders[_provider] ??
        ModelProviderManager.modelProviders.values.first;
    final availableModels = ModelProviderManager.getModels(_provider);
    if (!availableModels.any((m) => m.originName == modelController.text) &&
        !currentProvider.allowCustomModel &&
        availableModels.isNotEmpty) {
      modelController.text = availableModels[0].originName;
    }
    apiKeyController.text = config["apiKey"] ?? "";

    if (ModelProviderManager.modelProviders[_provider]!.allowCustomAPIUrl) {
      apiUrlController.text = settings.aiAPIUrl;
    }

    notifyListeners();
  }

  void setModel(String newModel) {
    if (modelController.text != newModel) modelController.text = newModel;
    _saveAiProviderConfig();
  }

  void setApiKey(String newApiKey) {
    if (apiKeyController.text != newApiKey) apiKeyController.text = newApiKey;
    _saveAiProviderConfig();
  }

  void setExplainWord(bool value) {
    settings.aiExplainWord = value;
    prefs.setBool("aiExplainWord", value);
    _homeModel.update();
    notifyListeners();
  }

  void setAiAPIUrl(String apiUrl) {
    if (apiUrlController.text != apiUrl) apiUrlController.text = apiUrl;
    settings.setAiAPIUrl(apiUrl);
    notifyListeners();
  }

  Future<bool> fetchModels() async {
    _isFetchingModels = true;
    _fetchError = null;
    notifyListeners();

    try {
      final models = await ModelProviderManager.fetchModels(
        provider: _provider,
        apiKey: apiKeyController.text,
        customApiUrl: apiUrlController.text,
      );

      if (models.isNotEmpty) {
        await settings.saveFetchedModels(_provider, models);
        final currentModelText = modelController.text;
        if (!models.any((m) => m.originName == currentModelText) &&
            !ModelProviderManager.modelProviders[_provider]!.allowCustomModel) {
          modelController.text = models.first.originName;
          _saveAiProviderConfig();
        }
      }
      _isFetchingModels = false;
      notifyListeners();
      return true;
    } catch (e) {
      talker.error("Failed to fetch models for $_provider", e);
      _fetchError = e.toString().replaceFirst("Exception: ", "");
      _isFetchingModels = false;
      notifyListeners();
      return false;
    }
  }

  @override
  void dispose() {
    apiKeyController.dispose();
    modelController.dispose();
    apiUrlController.dispose();
    super.dispose();
  }
}
