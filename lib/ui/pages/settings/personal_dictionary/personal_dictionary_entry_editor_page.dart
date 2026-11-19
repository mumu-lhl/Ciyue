import "package:ciyue/core/app_globals.dart";
import "package:ciyue/core/providers.dart";
import "package:ciyue/services/personal_dictionary_service.dart";
import "package:ciyue/services/toast.dart";
import "package:ciyue/src/generated/i18n/app_localizations.dart";
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
  String? _headwordsError;
  String? _bodyError;

  bool get _isNewEntry => widget.articleId == null;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? ref.read(personalDictionaryServiceProvider);
    if (!_isNewEntry) _loadEntry();
  }

  @override
  void dispose() {
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
        ToastService.show(e.toString(), context, type: ToastType.error);
      }
      return;
    }

    if (!mounted) return;
    ToastService.show(l10n.personalDictionaryEntrySaved, context);
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
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
    );
  }
}
