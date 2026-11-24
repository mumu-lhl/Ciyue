import "dart:async";

import "package:ciyue/services/lookup_mode.dart";
import "package:ciyue/services/translation_sources.dart";
import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:ciyue/ui/core/word_display/webview_helpers.dart";
import "package:ciyue/ui/core/word_display/word_display.dart";
import "package:ciyue/viewModels/translate_view_model.dart";
import "package:material_ui/material_ui.dart";

/// Resolves the translation sources for the popup's translate mode.
/// Indirected so tests can substitute a fake source without touching
/// the network; production always uses [TranslationSourcesConfig.resolve].
@visibleForTesting
var lookupPopupResolveSources = TranslationSourcesConfig.resolve;

/// The lookup popup page for desktop hotkey lookup (issue #909).
///
/// A plain page with no router: the popup window runs its own
/// [MaterialApp], so this page never calls `context.go/push/pop`.
/// It only renders and reports the close request through [onClose];
/// the caller owns the clipboard, the hotkey and the window.
class LookupPopupPage extends StatefulWidget {
  final String text;
  final LookupMode initialMode;
  final VoidCallback onClose;

  const LookupPopupPage({
    super.key,
    required this.text,
    required this.initialMode,
    required this.onClose,
  });

  @override
  State<LookupPopupPage> createState() => _LookupPopupPageState();
}

class _LookupPopupPageState extends State<LookupPopupPage> {
  late final TextEditingController _controller;
  late String _text;
  late LookupMode _mode;

  /// Finished translate outcomes, kept per text so flipping between Lookup
  /// and Translate does not re-send the request.
  final Map<String, _CachedTranslation> _translateCache = {};

  @override
  void initState() {
    super.initState();
    _text = widget.text;
    _mode = widget.initialMode;
    _controller = TextEditingController(text: widget.text);
  }

  @override
  void didUpdateWidget(covariant LookupPopupPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The host reuses this page for every lookup while the popup stays
    // open, so a new request arrives as an updated widget, not a new
    // state: adopt the new text and mode (and reset the search field).
    if (widget.text != oldWidget.text ||
        widget.initialMode != oldWidget.initialMode) {
      _text = widget.text;
      _mode = widget.initialMode;
      _controller.text = widget.text;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit(String value) {
    final word = value.trim();
    if (word.isEmpty) return;
    if (word == _text) return;
    // A new word gets a fresh decision: the mode picked for the previous
    // text (by the service or by the reader's manual switch) says nothing
    // about this one.
    setState(() {
      _text = word;
      _mode = decideLookupMode(word);
    });
  }

  @override
  Widget build(BuildContext context) {
    final locale = AppLocalizations.of(context)!;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 8, 4),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      key: const ValueKey("lookup_popup_search_field"),
                      controller: _controller,
                      // The popup shows inactive and must not steal focus.
                      autofocus: false,
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        hintText: locale.lookupPopupSearchHint,
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        suffixIcon: IconButton(
                          tooltip: locale.lookupPopupLookup,
                          icon: const Icon(Icons.search),
                          onPressed: () => _submit(_controller.text),
                        ),
                      ),
                      onSubmitted: _submit,
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    key: const ValueKey("lookup_popup_close_button"),
                    tooltip: locale.close,
                    icon: const Icon(Icons.close),
                    onPressed: widget.onClose,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
              child: SegmentedButton<LookupMode>(
                segments: [
                  ButtonSegment(
                    value: LookupMode.lookup,
                    label: Text(locale.lookupPopupLookup),
                  ),
                  ButtonSegment(
                    value: LookupMode.translate,
                    label: Text(locale.lookupPopupTranslate),
                  ),
                ],
                selected: {_mode},
                onSelectionChanged: (selection) {
                  setState(() => _mode = selection.first);
                },
              ),
            ),
            Expanded(
              child: _mode == LookupMode.lookup
                  // No router ancestor here: withFloatingWindowBackHandler
                  // tolerates a missing GoRouter (canPop is false), so
                  // WordDisplay renders directly without a bare scope.
                  // In-page navigation (dictionary links, suggestions) stays
                  // in the popup through this scope instead of touching the
                  // main window's tab or history.
                  ? PopupWordNavigationScope(
                      onOpenWord: _submit,
                      child: WordDisplay(
                        key: ValueKey("lookup_popup_word_$_text"),
                        word: _text,
                        showBackButton: false,
                        inLookupPopup: true,
                        onPopAttempt: widget.onClose,
                      ),
                    )
                  : _TranslateView(
                      key: ValueKey("lookup_popup_translate_$_text"),
                      text: _text,
                      cached: _translateCache[_text],
                      onCached: (entry) => _translateCache[_text] = entry,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _TranslateStatus { loading, success, error, noSource }

/// A finished translate outcome, cached per text at the page layer.
typedef _CachedTranslation = ({_TranslateStatus status, String? result});

class _TranslateView extends StatefulWidget {
  final String text;

  /// A finished outcome for [text], if the page already fetched it.
  final _CachedTranslation? cached;

  /// Reports a finished outcome back to the page cache.
  final ValueChanged<_CachedTranslation>? onCached;

  const _TranslateView({
    super.key,
    required this.text,
    this.cached,
    this.onCached,
  });

  @override
  State<_TranslateView> createState() => _TranslateViewState();
}

class _TranslateViewState extends State<_TranslateView> {
  _TranslateStatus _status = _TranslateStatus.loading;
  String? _result;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    final cached = widget.cached;
    if (cached != null) {
      _status = cached.status;
      _result = cached.result;
    } else {
      unawaited(_run());
    }
  }

  @override
  void didUpdateWidget(covariant _TranslateView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      final cached = widget.cached;
      if (cached != null) {
        setState(() {
          _status = cached.status;
          _result = cached.result;
        });
      } else {
        unawaited(_run());
      }
    }
  }

  /// Records a finished outcome in the page cache and shows it.
  void _finish(_TranslateStatus status, [String? result]) {
    widget.onCached?.call((status: status, result: result));
    setState(() {
      _status = status;
      _result = result;
    });
  }

  Future<void> _run() async {
    final generation = ++_generation;
    final resolved = lookupPopupResolveSources();
    if (resolved.active.isEmpty) {
      if (!mounted || generation != _generation) return;
      _finish(_TranslateStatus.noSource);
      return;
    }
    if (!mounted || generation != _generation) return;
    setState(() => _status = _TranslateStatus.loading);
    try {
      final result = await resolved.active.first.translate(
        context,
        text: widget.text,
        sourceLanguage: "auto",
        targetLanguage: resolveTranslateTargetDefault(),
      );
      if (!mounted || generation != _generation) return;
      if (result.text.trim().isEmpty) {
        _finish(_TranslateStatus.error);
        return;
      }
      _finish(_TranslateStatus.success, result.text);
    } catch (_) {
      if (!mounted || generation != _generation) return;
      _finish(_TranslateStatus.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = AppLocalizations.of(context)!;
    switch (_status) {
      case _TranslateStatus.loading:
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(locale.lookupPopupTranslating),
            ],
          ),
        );
      case _TranslateStatus.error:
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  locale.lookupPopupTranslateError,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _run,
                  child: Text(locale.lookupPopupTranslateRetry),
                ),
              ],
            ),
          ),
        );
      case _TranslateStatus.noSource:
        // There is no /translate route (the Translate page is a tab of
        // the main window), so the hint stands on its own with no button.
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              locale.lookupPopupNoTranslationSource,
              textAlign: TextAlign.center,
            ),
          ),
        );
      case _TranslateStatus.success:
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SelectableText(
                widget.text,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const Divider(height: 24),
              SelectableText(_result ?? ""),
            ],
          ),
        );
    }
  }
}
