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

/// The default target language for a fresh translate page: the app's
/// configured language, or the device locale mapped onto the
/// picker's language set — keeping Traditional Chinese variants,
/// and falling back to English for device languages the picker (and
/// several sources) don't offer instead of passing a raw code
/// through to every provider.
String resolveTranslateTargetDefault() {
  final configured = settings.language;
  if (configured != null && configured != "system") return configured;
  final locale = ui.PlatformDispatcher.instance.locale;
  var code = locale.languageCode;
  if (code == "zh" && locale.scriptCode == "Hant") {
    code = locale.countryCode == "HK" ? "zh_HK" : "zh_TW";
  }
  return languageMap.containsKey(code) ? code : "en";
}

class AiTranslateViewModel extends ChangeNotifier {
  final TextEditingController inputController = TextEditingController();
  final TranslateHistoryDao _historyDao;
  String _sourceLanguage = "auto";
  String _targetLanguage = resolveTranslateTargetDefault();

  /// Per-source results of the latest run, in the user's display order.
  List<SourceResult> _results = [];
  List<SourceResult> get results => _results;

  /// Enabled sources skipped because their API key/URL is missing.
  List<TranslationSource> _skippedSources = [];
  List<TranslationSource> get skippedSources => _skippedSources;

  bool _hasTranslated = false;
  bool get hasTranslated => _hasTranslated;

  /// Monotonic run id: completions from superseded runs must not
  /// trigger rebuilds (or any other state change) anymore.
  int _runGeneration = 0;

  /// Identity of the in-flight run, to dedupe accidental duplicate
  /// triggers (double-tap, Ctrl+Enter spam) for the same request.
  String? _activeRunKey;

  /// Last provider-detected source language (for auto-detect swaps).
  String? _detectedLanguage;

  AiTranslateViewModel([TranslateHistoryDao? historyDao])
    : _historyDao = historyDao ?? translateHistoryDao {
    // The UI only derives "is the input empty" (button enabled
    // states) from the text. Notifying on every keystroke rebuilds
    // the whole page and re-parses every result card's markdown;
    // notify only when the emptiness actually flips.
    var lastEmpty = true;
    inputController.addListener(() {
      final empty = inputController.text.isEmpty;
      if (empty != lastEmpty) {
        lastEmpty = empty;
        notifyListeners();
      }
    });
  }

  bool get isRichOutput => settings.isRichOutput;
  String get sourceLanguage => _sourceLanguage;
  String get targetLanguage => _targetLanguage;
  bool get isLoading => _results.any((r) => r.isLoading);
  String get translationProvider => settings.translationProvider;

  /// Displayed results belong to a specific text + language pair.
  /// Changing either language invalidates them — otherwise stale
  /// results sit under the new language chips and their TTS/copy
  /// actions present them as current.
  void _invalidateResults() {
    _runGeneration++;
    _results = [];
    _skippedSources = [];
    _hasTranslated = false;
  }

  void setSourceLanguage(String value) {
    if (value == _sourceLanguage) return;
    _sourceLanguage = value;
    _invalidateResults();
    notifyListeners();
  }

  void setTargetLanguage(String value) {
    if (value == _targetLanguage) return;
    _targetLanguage = value;
    _invalidateResults();
    notifyListeners();
  }

  void swapLanguages() {
    // With auto-detect, swap against the language the providers
    // actually detected for the current text; without a detection,
    // fall back to the default target language.
    final from = _sourceLanguage == "auto"
        ? (_detectedLanguage ?? resolveTranslateTargetDefault())
        : _sourceLanguage;
    final newSource = _targetLanguage;
    var newTarget = from;
    if (newTarget == newSource) {
      // The common default state (auto + target already equals the
      // detected/default language) would swap into a useless
      // same-language pair and look like a no-op. Use the opposite
      // pole instead.
      newTarget = newSource == "en" ? "zh" : "en";
    }
    _sourceLanguage = newSource;
    _targetLanguage = newTarget;
    _invalidateResults();
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

    // Ignore an accidental duplicate trigger for the exact same
    // request while it is still running — a second fan-out would
    // bill every paid source twice. A changed text or language pair
    // is a new request and always runs.
    final runKey = "$text\u0000$_sourceLanguage\u0000$_targetLanguage";
    if (isLoading && runKey == _activeRunKey) return;
    _activeRunKey = runKey;
    final generation = ++_runGeneration;

    final resolved = TranslationSourcesConfig.resolve();
    _skippedSources = resolved.skipped;
    _results = resolved.active.map(SourceResult.new).toList();
    _hasTranslated = true;
    notifyListeners();

    // Capture this run's parameters and entries: if the user changes
    // a language mid-flight, _invalidateResults supersedes this run
    // (generation guard silences its completions) — it must not start
    // calling sources with the new language under the old run's key.
    final entries = _results;
    final runSource = _sourceLanguage;
    final runTarget = _targetLanguage;

    if (settings.enableTranslationHistory && resolved.active.isNotEmpty) {
      try {
        await _historyDao.addHistory(text);
      } catch (_) {
        // History is best-effort; its failure must not break (or
        // surface as an unhandled error over) the translation.
      }
    }
    // The history write yielded: if the page went away meanwhile,
    // don't hand a defunct context to the sources.
    if (_disposed || !context.mounted) return;

    final futures = <Future<void>>[];
    for (final entry in entries) {
      futures.add(
        _runSource(context, entry, text, runSource, runTarget).whenComplete(() {
          if (!_disposed && generation == _runGeneration) {
            notifyListeners();
          }
        }),
      );
    }
    await Future.wait(futures);
  }

  Future<void> _runSource(
    BuildContext context,
    SourceResult entry,
    String text,
    String sourceLanguage,
    String targetLanguage,
  ) async {
    try {
      final result = await entry.source.translate(
        context,
        text: text,
        sourceLanguage: sourceLanguage,
        targetLanguage: targetLanguage,
      );
      if (result.text.trim().isEmpty) {
        // A provider returning an empty body is a failure, not a
        // successful blank card with working copy/TTS buttons.
        entry.error = "Returned an empty translation";
        entry.status = SourceResultStatus.error;
        return;
      }
      entry.result = result;
      entry.status = SourceResultStatus.success;
      final detected = result.detectedLanguage;
      if (detected != null) _detectedLanguage = detected;
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
