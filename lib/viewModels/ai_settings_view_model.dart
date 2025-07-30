import "package:ciyue/core/app_globals.dart";
import "package:ciyue/repositories/ai_prompts.dart";
import "package:ciyue/repositories/settings.dart";
import "package:ciyue/services/ai.dart";
import "package:ciyue/viewModels/home.dart";
import "package:flutter/material.dart";

class AISettingsViewModel with ChangeNotifier {
  late String _provider;
  late String _model;
  late String _apiKey;
  final AIPrompts _aiPrompts;
  final HomeModel _homeModel;

  AISettingsViewModel(this._aiPrompts, this._homeModel) {
    _provider = settings.aiProvider;
    if (ModelProviderManager.modelProviders[_provider] == null) {
      _provider = ModelProviderManager.modelProviders.values.first.name;
      settings.aiProvider = _provider;
      prefs.setString("aiProvider", _provider);
    }

    final config = settings.getAiProviderConfig(_provider);
    _model = config["model"]!;
    _apiKey = config["apiKey"]!;

    final currentProvider = ModelProviderManager.modelProviders[_provider]!;
    if (!currentProvider.models.any((m) => m.originName == _model) &&
        !currentProvider.allowCustomModel) {
      _model = currentProvider.models[0].originName;
      _saveAiProviderConfig();
    }
  }

  String get provider => _provider;
  String get model => _model;
  String get apiKey => _apiKey;
  bool get explainWord => settings.aiExplainWord;
  AIPrompts get aiPrompts => _aiPrompts;

  void _saveAiProviderConfig() {
    settings.saveAiProviderConfig(_provider, _model, _apiKey);
    notifyListeners();
  }

  void setProvider(String newProvider) {
    _provider = newProvider;
    settings.aiProvider = newProvider;
    prefs.setString("aiProvider", newProvider);

    final config = settings.getAiProviderConfig(_provider);
    _model = config["model"]!;
    final currentProvider = ModelProviderManager.modelProviders[_provider] ??
        ModelProviderManager.modelProviders.values.first;
    if (!currentProvider.models.any((m) => m.originName == _model) &&
        !currentProvider.allowCustomModel) {
      _model = currentProvider.models[0].originName;
    }
    _apiKey = config["apiKey"]!;
    notifyListeners();
  }

  void setModel(String newModel) {
    _model = newModel;
    _saveAiProviderConfig();
  }

  void setApiKey(String newApiKey) {
    _apiKey = newApiKey;
    _saveAiProviderConfig();
  }

  void setExplainWord(bool value) {
    settings.aiExplainWord = value;
    prefs.setBool("aiExplainWord", value);
    _homeModel.update();
    notifyListeners();
  }

  void setAiAPIUrl(String apiUrl) {
    settings.setAiAPIUrl(apiUrl);
    notifyListeners();
  }
}
