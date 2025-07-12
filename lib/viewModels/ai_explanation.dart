import "dart:ui" as ui;

import "package:ciyue/core/app_globals.dart";
import "package:ciyue/core/app_router.dart";
import "package:ciyue/database/app/app.dart";
import "package:ciyue/database/app/daos.dart";
import "package:ciyue/repositories/ai_prompts.dart";
import "package:ciyue/repositories/settings.dart";
import "package:ciyue/services/ai.dart";
import "package:flutter/material.dart";
import "package:provider/provider.dart";

class AIExplanationModel extends ChangeNotifier {
  final AiExplanationDao _aiExplanationDao;
  final AI _ai;

  String? _explanation;
  String? get explanation => _explanation;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  int _refreshKey = 0;
  int get refreshKey => _refreshKey;

  AIExplanationModel()
      : _aiExplanationDao = AiExplanationDao(mainDatabase),
        _ai = AI(
          provider: settings.aiProvider,
          model:
              settings.getAiProviderConfig(settings.aiProvider)["model"] ?? "",
          apikey:
              settings.getAiProviderConfig(settings.aiProvider)["apiKey"] ?? "",
        );

  Future<void> getExplanation(String word) async {
    _isLoading = true;
    _explanation = null;
    notifyListeners();

    final cached = await _aiExplanationDao.getAiExplanation(word);
    if (cached != null) {
      _explanation = cached.explanation;
      _isLoading = false;
      notifyListeners();
      return;
    }

    await _fetchFromAI(word);
  }

  Future<void> refreshExplanation(String word) async {
    _isLoading = true;
    _explanation = null;
    notifyListeners();

    await _fetchFromAI(word, forceRefresh: true);
  }

  Future<void> _fetchFromAI(String word, {bool forceRefresh = false}) async {
    final targetLanguage = settings.language! == "system"
        ? ui.PlatformDispatcher.instance.locale.languageCode
        : settings.language!;
    final template =
        Provider.of<AIPrompts>(navigatorKey.currentContext!, listen: false)
            .explainPrompt;
    final prompt = template
        .replaceAll(r"$word", word)
        .replaceAll(r"$targetLanguage", targetLanguage);

    try {
      final fullExplanation = await _ai.request(prompt);
      _explanation = fullExplanation;

      final existing = await _aiExplanationDao.getAiExplanation(word);
      if (existing != null) {
        await _aiExplanationDao.updateAiExplanation(
            AiExplanation(word: word, explanation: fullExplanation));
      } else {
        await _aiExplanationDao.insertAiExplanation(
            AiExplanation(word: word, explanation: fullExplanation));
      }
    } catch (e) {
      _explanation = "Error: ${e.toString()}";
    } finally {
      _isLoading = false;

      if (forceRefresh) {
        _refreshKey++;
      }

      notifyListeners();
    }
  }

  Future<void> updateExplanation(String word, String newExplanation) async {
    _explanation = newExplanation;
    await _aiExplanationDao.updateAiExplanation(
        AiExplanation(word: word, explanation: newExplanation));
    notifyListeners();
  }
}
