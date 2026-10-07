import "dart:ui" as ui;

import "package:ciyue/core/app_globals.dart";
import "package:ciyue/database/app/app.dart";
import "package:ciyue/database/app/daos.dart";
import "package:ciyue/repositories/ai_prompts.dart";
import "package:ciyue/repositories/settings.dart";
import "package:ciyue/services/ai.dart";
import "package:material_ui/material_ui.dart";

class AIExplanationModel extends ChangeNotifier {
  final AiExplanationDao _aiExplanationDao;
  final AIPrompts? _aiPrompts;
  final AI _ai;

  String? _explanation;
  String? get explanation => _explanation;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  int _refreshKey = 0;
  int get refreshKey => _refreshKey;

  bool _mounted = true;

  AIExplanationModel({this._aiPrompts, AiExplanationDao? dao})
    : _aiExplanationDao = dao ?? AiExplanationDao(mainDatabase),
      _ai = AI(
        provider: settings.aiProvider,
        model: settings.getAiProviderConfig(settings.aiProvider)["model"] ?? "",
        apikey:
            settings.getAiProviderConfig(settings.aiProvider)["apiKey"] ?? "",
      );

  @override
  void dispose() {
    _mounted = false;
    super.dispose();
  }

  Future<void> getExplanation(String word) async {
    _isLoading = true;
    _explanation = null;
    notifyListeners();

    final cached = await _aiExplanationDao.getAiExplanation(word);

    if (!_mounted) return;

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
    final template = (_aiPrompts ?? AIPrompts()).explainPrompt;
    final prompt = template
        .replaceAll(r"$word", word)
        .replaceAll(r"$targetLanguage", targetLanguage);

    try {
      final fullExplanation = await _ai.request(prompt);
      _explanation = fullExplanation;

      final existing = await _aiExplanationDao.getAiExplanation(word);
      if (existing != null) {
        await _aiExplanationDao.updateAiExplanation(
          AiExplanation(word: word, explanation: fullExplanation),
        );
      } else {
        await _aiExplanationDao.insertAiExplanation(
          AiExplanation(word: word, explanation: fullExplanation),
        );
      }
    } catch (e) {
      _explanation = "Error: ${e.toString()}";
    } finally {
      // ignore: control_flow_in_finally
      if (!_mounted) return;
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
      AiExplanation(word: word, explanation: newExplanation),
    );

    if (!_mounted) return;
    notifyListeners();
  }
}
