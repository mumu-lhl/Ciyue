import "dart:ui" as ui;

import "package:ciyue/core/app_globals.dart";
import "package:ciyue/database/app/daos.dart";
import "package:ciyue/models/translation_result.dart";
import "package:ciyue/repositories/settings.dart";
import "package:ciyue/services/translation.dart";
import "package:ciyue/services/translation_sources.dart";
import "package:material_ui/material_ui.dart";

enum SourceResultStatus { loading, success, error }

/// One source's outcome in a multi-source translation run.
class SourceResult {
  final TranslationSource source;
  SourceResultStatus status = SourceResultStatus.loading;
  TranslationResult? result;
  String? error;

  SourceResult(this.source);

  bool get isLoading => status == SourceResultStatus.loading;
  bool get isError => status == SourceResultStatus.error;
}

class AiTranslateViewModel extends ChangeNotifier {
  final TextEditingController inputController = TextEditingController();
  final TranslateHistoryDao _historyDao;
  String _sourceLanguage = "auto";
  String _targetLanguage = settings.language! == "system"
      ? ui.PlatformDispatcher.instance.locale.languageCode
      : settings.language!;

  /// Per-source results of the latest run, in the user's display order.
  List<SourceResult> _results = [];
  List<SourceResult> get results => _results;

  /// Enabled sources skipped because their API key/URL is missing.
  List<TranslationSource> _skippedSources = [];
  List<TranslationSource> get skippedSources => _skippedSources;

  bool _hasTranslated = false;
  bool get hasTranslated => _hasTranslated;

  AiTranslateViewModel([TranslateHistoryDao? historyDao])
    : _historyDao = historyDao ?? translateHistoryDao {
    inputController.addListener(() {
      notifyListeners();
    });
  }

  bool get isRichOutput => settings.isRichOutput;
  String get sourceLanguage => _sourceLanguage;
  String get targetLanguage => _targetLanguage;
  bool get isLoading => _results.any((r) => r.isLoading);
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

  /// Query every enabled+configured source in parallel. Each source
  /// updates its own [SourceResult] as it finishes, so fast sources
  /// render immediately instead of waiting for the slowest one.
  Future<void> translateText(BuildContext context) async {
    final text = inputController.text.trim();
    if (text.isEmpty) return;

    if (settings.enableTranslationHistory) {
      _historyDao.addHistory(text);
    }

    final resolved = TranslationSourcesConfig.resolve();
    _skippedSources = resolved.skipped;
    _results = resolved.active.map(SourceResult.new).toList();
    _hasTranslated = true;
    notifyListeners();

    final futures = <Future<void>>[];
    for (final entry in _results) {
      futures.add(
        _runSource(context, entry, text).whenComplete(() {
          if (!_disposed) notifyListeners();
        }),
      );
    }
    await Future.wait(futures);
  }

  Future<void> _runSource(
    BuildContext context,
    SourceResult entry,
    String text,
  ) async {
    try {
      entry.result = await entry.source.translate(
        context,
        text: text,
        sourceLanguage: _sourceLanguage,
        targetLanguage: _targetLanguage,
      );
      entry.status = SourceResultStatus.success;
    } catch (e) {
      entry.error = e.toString();
      entry.status = SourceResultStatus.error;
    }
  }

  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    inputController.dispose();
    super.dispose();
  }
}
