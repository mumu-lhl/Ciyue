import "package:ciyue/core/app_globals.dart";
import "package:ciyue/core/providers.dart";
import "package:ciyue/services/personal_dictionary_service.dart";
import "package:ciyue/services/toast.dart";
import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:ciyue/ui/pages/settings/personal_dictionary/personal_dictionary_entries_page.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:gpt_markdown/gpt_markdown.dart";
import "package:material_ui/material_ui.dart";

/// Splits a headwords field on commas and new lines, trims each part,
/// drops empties, and de-duplicates while keeping the typed order.
List<String> parsePersonalHeadwords(String text) {
  final seen = <String>{};
  final headwords = <String>[];
  for (final part in text.split(RegExp(r"[,，\n]"))) {
    final headword = part.trim();
    if (headword.isEmpty || !seen.add(headword)) continue;
    headwords.add(headword);
  }
  return headwords;
}

class PersonalDictionaryEntryEditorPage extends ConsumerStatefulWidget {
  const PersonalDictionaryEntryEditorPage({
    super.key,
    required this.dictionaryId,
    this.articleId,
    this.service,
  });

  final int dictionaryId;

  /// Null for a new entry, the article id when editing an existing one.
  final int? articleId;

  /// Injected for widget tests; defaults to [personalDictionaryServiceProvider].
  final PersonalDictionaryService? service;

  @override
  ConsumerState<PersonalDictionaryEntryEditorPage> createState() =>
      _PersonalDictionaryEntryEditorPageState();
}

class _PersonalDictionaryEntryEditorPageState
    extends ConsumerState<PersonalDictionaryEntryEditorPage> {
  late final PersonalDictionaryService _service;
  final _headwordsController = TextEditingController();
  final _bodyController = TextEditingController();

  bool _isPreview = false;
  bool _isLoading = false;
  bool _isSaving = false;
  bool _loadFailed = false;
  bool _notFound = false;
  bool _allowPop = false;
  String? _headwordsError;
  String? _bodyError;

  /// Field contents as last loaded or saved: leaving with anything else
  /// unsaved asks first.
  String _initialHeadwords = "";
  String _initialBody = "";

  bool get _isNewEntry => widget.articleId == null;

  bool get _isDirty =>
      _headwordsController.text != _initialHeadwords ||
      _bodyController.text != _initialBody;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? ref.read(personalDictionaryServiceProvider);
    // The PopScope's canPop only refreshes when this page rebuilds, and
    // typing into a TextField rebuilds just the field — without a listener
    // the back gesture would keep the stale "no changes" value and pop
    // without asking.
    _headwordsController.addListener(_onFieldsChanged);
    _bodyController.addListener(_onFieldsChanged);
    _checkDictionary();
  }

  void _onFieldsChanged() {
    if (mounted) setState(() {});
  }

  /// A deep link can point at a dictionary that no longer exists; that is
  /// a not-found page, not an empty entry list that only fails at save.
  Future<void> _checkDictionary() async {
    final exists = await _service.dictionaryExists(widget.dictionaryId);
    if (!mounted) return;
    if (!exists) {
      setState(() => _notFound = true);
      return;
    }
    if (!_isNewEntry) _loadEntry();
  }

  /// Asks before discarding unsaved changes. Returns after the user picks
  /// an action; the page only pops once [_allowPop] is set.
  Future<void> _confirmDiscard() async {
    final l10n = AppLocalizations.of(context)!;
    final discard = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.personalDictionaryDiscardChanges),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.personalDictionaryDiscard),
          ),
        ],
      ),
    );
    if (discard != true || !mounted) return;
    setState(() => _allowPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).pop();
    });
  }

  @override
  void dispose() {
    _headwordsController.removeListener(_onFieldsChanged);
    _bodyController.removeListener(_onFieldsChanged);
    _headwordsController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _loadEntry() async {
    setState(() {
      _isLoading = true;
      _loadFailed = false;
    });
    try {
      // The contract has no get-by-article lookup; the entry is found in
      // the dictionary's entry list.
      final entries = await _service.listEntries(widget.dictionaryId);
      final entry = entries.firstWhere((e) => e.articleId == widget.articleId);
      if (!mounted) return;
      setState(() {
        _headwordsController.text = entry.headwords.join(", ");
        _bodyController.text = entry.body;
        _initialHeadwords = _headwordsController.text;
        _initialBody = _bodyController.text;
        _isLoading = false;
      });
    } catch (e, stackTrace) {
      talker.error(
        "Failed to load personal entry ${widget.articleId}",
        e,
        stackTrace,
      );
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadFailed = true;
      });
    }
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context)!;
    final headwords = parsePersonalHeadwords(_headwordsController.text);
    final body = _bodyController.text.trim();

    setState(() {
      _headwordsError = headwords.isEmpty
          ? l10n.personalDictionaryHeadwordsEmpty
          : null;
      _bodyError = body.isEmpty ? l10n.personalDictionaryBodyEmpty : null;
    });
    if (_headwordsError != null || _bodyError != null) return;

    // A headword owned by another entry is an inline field error, not a
    // raw exception toast; the entry being edited keeps its own headwords.
    final conflict = await _service.findConflictingHeadword(
      widget.dictionaryId,
      headwords,
      exceptArticleId: _isNewEntry ? null : widget.articleId,
    );
    if (!mounted) return;
    if (conflict != null) {
      setState(() {
        _headwordsError = l10n.personalDictionaryHeadwordAlreadyExists(
          conflict,
        );
      });
      return;
    }
    setState(() => _headwordsError = null);

    setState(() => _isSaving = true);
    try {
      if (_isNewEntry) {
        await _service.createEntry(
          widget.dictionaryId,
          headwords: headwords,
          body: body,
        );
      } else {
        await _service.updateEntry(
          widget.articleId!,
          headwords: headwords,
          body: body,
        );
      }
    } catch (e, stackTrace) {
      talker.error("Failed to save personal entry", e, stackTrace);
      if (mounted) {
        setState(() => _isSaving = false);
        ToastService.show(
          l10n.personalDictionaryOperationFailed,
          context,
          type: ToastType.error,
        );
      }
      return;
    }

    if (!mounted) return;
    _allowPop = true;
    ToastService.show(l10n.personalDictionaryEntrySaved, context);
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    if (_notFound) return const PersonalDictionaryNotFoundPage();

    return PopScope(
      canPop: !_isDirty || _allowPop,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _isDirty) _confirmDiscard();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            _isNewEntry
                ? l10n.personalDictionaryNewEntry
                : l10n.personalDictionaryEditEntry,
          ),
          actions: [
            IconButton(
              icon: Icon(
                _isPreview ? Icons.edit_outlined : Icons.preview_outlined,
              ),
              tooltip: _isPreview
                  ? l10n.personalDictionaryEdit
                  : l10n.personalDictionaryPreview,
              onPressed: () {
                setState(() => _isPreview = !_isPreview);
              },
            ),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilledButton(
                onPressed: _isSaving || _isLoading ? null : _save,
                child: Text(l10n.save),
              ),
            ),
          ],
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _loadFailed
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.error_outline_rounded,
                            size: 40,
                            color: theme.colorScheme.error,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            l10n.personalDictionaryLoadFailed,
                            style: theme.textTheme.titleMedium,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          FilledButton(
                            onPressed: _loadEntry,
                            child: Text(l10n.retry),
                          ),
                        ],
                      ),
                    ),
                  )
                : _isPreview
                ? SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: SelectionArea(
                      child: GptMarkdown(_bodyController.text),
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        TextField(
                          controller: _headwordsController,
                          decoration: InputDecoration(
                            labelText: l10n.personalDictionaryHeadwords,
                            hintText: l10n.personalDictionaryHeadwordsHint,
                            errorText: _headwordsError,
                            border: const OutlineInputBorder(),
                          ),
                          minLines: 1,
                          maxLines: 3,
                          textInputAction: TextInputAction.next,
                        ),
                        const SizedBox(height: 16),
                        Expanded(
                          child: TextField(
                            controller: _bodyController,
                            decoration: InputDecoration(
                              labelText: l10n.personalDictionaryBody,
                              hintText: l10n.personalDictionaryBodyHint,
                              errorText: _bodyError,
                              border: const OutlineInputBorder(),
                              alignLabelWithHint: true,
                            ),
                            maxLines: null,
                            expands: true,
                            textAlignVertical: TextAlignVertical.top,
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
