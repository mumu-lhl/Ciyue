import "dart:ui" as ui;

import "package:ciyue/core/app_globals.dart";
import "package:ciyue/database/app/app.dart";
import "package:ciyue/database/app/daos.dart";
import "package:ciyue/models/ai_explanation_data.dart";
import "package:ciyue/repositories/ai_prompts.dart";
import "package:ciyue/repositories/settings.dart";
import "package:ciyue/services/ai.dart";
import "package:genkit/genkit.dart";
import "package:material_ui/material_ui.dart";

class AIExplanationModel extends ChangeNotifier {
  final AiExplanationDao _aiExplanationDao;
  final AIPrompts? _aiPrompts;
  final AI _ai;

  String? _explanation;
  String? get explanation => _explanation;

  /// The current explanation parsed as structured data, when
  /// structured mode is on and the text parsed. Null means the view
  /// renders [explanation] as markdown (legacy cache entries, manual
  /// edits, or a model response that was not valid JSON).
  AiExplanationData? _structured;
  AiExplanationData? get structured => _structured;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  int _refreshKey = 0;
  int get refreshKey => _refreshKey;

  bool _mounted = true;
  CancellationController? _streamController;

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
    _streamController?.cancel();
    super.dispose();
  }

  /// Interprets explanation [text] (cached or freshly fetched) for
  /// display. Returns false only when markdown mode is on but the
  /// text is structured JSON — showing it raw would dump JSON on the
  /// user, so the caller treats it as a cache miss and refetches.
  bool _applyContent(String text) {
    final parsed = AiExplanationData.tryParse(text);
    if (settings.aiExplainStructured) {
      // Null when the text is a legacy markdown entry or a malformed
      // response: the view then falls back to markdown rendering.
      _structured = parsed;
      _explanation = text;
      return true;
    }
    if (parsed != null) {
      return false;
    }
    _structured = null;
    _explanation = text;
    return true;
  }

  Future<void> getExplanation(String word) async {
    // Cancel any in-flight stream from a previous word.
    _streamController?.cancel();
    _isLoading = true;
    _explanation = null;
    _structured = null;
    notifyListeners();

    final cached = await _aiExplanationDao.getAiExplanation(word);

    if (!_mounted) return;

    if (cached != null && _applyContent(cached.explanation)) {
      _isLoading = false;
      notifyListeners();
      return;
    }

    await _fetchFromAI(word);
  }

  Future<void> refreshExplanation(String word) async {
    _streamController?.cancel();
    _isLoading = true;
    _explanation = null;
    _structured = null;
    notifyListeners();

    await _fetchFromAI(word, forceRefresh: true);
  }

  Future<void> _fetchFromAI(String word, {bool forceRefresh = false}) async {
    final targetLanguage = settings.language! == "system"
        ? ui.PlatformDispatcher.instance.locale.languageCode
        : settings.language!;
    final structuredMode = settings.aiExplainStructured;
    final prompts = _aiPrompts ?? AIPrompts();
    final template = structuredMode
        ? prompts.explainStructuredPrompt
        : prompts.explainPrompt;
    final prompt = template
        .replaceAll(r"$word", word)
        .replaceAll(r"$targetLanguage", targetLanguage);

    final controller = CancellationController();
    _streamController = controller;

    final buffer = StringBuffer();
    try {
      await for (final chunk in _ai.requestStream(
        prompt,
        cancel: controller.token,
      )) {
        if (!_mounted) return;
        // Ignore chunks from a cancelled (superseded) stream.
        if (controller.isCancelled) return;
        buffer.write(chunk);
        // Structured responses are partial JSON while streaming and
        // cannot be shown; they are published whole on completion.
        if (!structuredMode) {
          _explanation = buffer.toString();
          _isLoading = false;
          notifyListeners();
        }
      }
      final fullExplanation = buffer.toString();
      if (fullExplanation.isEmpty) {
        // A stream that completes without producing anything must
        // not leave a silently blank explanation.
        _explanation = "Error: The AI provider returned an empty response.";
        return;
      }
      if (!_applyContent(fullExplanation)) {
        // The markdown prompt was used but the model answered with
        // JSON anyway: show it as text rather than refetching.
        _structured = null;
        _explanation = fullExplanation;
      }

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
      // Cancelled streams throw CancelledException; don't show as error.
      if (e is CancelledException) return;
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
    // A manual edit may or may not still be valid structured data.
    _structured = settings.aiExplainStructured
        ? AiExplanationData.tryParse(newExplanation)
        : null;
    await _aiExplanationDao.updateAiExplanation(
      AiExplanation(word: word, explanation: newExplanation),
    );

    if (!_mounted) return;
    notifyListeners();
  }
}
