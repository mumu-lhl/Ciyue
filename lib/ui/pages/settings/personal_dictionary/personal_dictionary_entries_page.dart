import "dart:async";

import "package:ciyue/core/app_globals.dart";
import "package:ciyue/core/providers.dart";
import "package:ciyue/services/personal_dictionary_service.dart";
import "package:ciyue/services/toast.dart";
import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:ciyue/ui/pages/settings/personal_dictionary/personal_dictionary_io.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "package:material_ui/material_ui.dart";

class PersonalDictionaryEntriesPage extends ConsumerStatefulWidget {
  const PersonalDictionaryEntriesPage({
    super.key,
    required this.dictionaryId,
    this.title,
    this.service,
  });

  final int dictionaryId;

  /// Display name of the dictionary, shown in the app bar when provided.
  final String? title;

  /// Injected for widget tests; defaults to [personalDictionaryServiceProvider].
  final PersonalDictionaryService? service;

  @override
  ConsumerState<PersonalDictionaryEntriesPage> createState() =>
      _PersonalDictionaryEntriesPageState();
}

class _PersonalDictionaryEntriesPageState
    extends ConsumerState<PersonalDictionaryEntriesPage> {
  late final PersonalDictionaryService _service;
  final _searchController = TextEditingController();
  Timer? _debounceTimer;

  Future<List<PersonalEntry>>? _entriesFuture;
  String _query = "";

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? ref.read(personalDictionaryServiceProvider);
    _reload();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _reload() {
    setState(() {
      _entriesFuture = _service.listEntries(
        widget.dictionaryId,
        query: _query.isEmpty ? null : _query,
      );
    });
  }

  void _onSearchChanged(String value) {
    // Cancellable debounce, like the search bar's suggestion queries: a new
    // keystroke cancels the pending timer so the query for the old text is
    // never even started.
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      _query = value.trim();
      _reload();
    });
  }

  String get _entriesRoute =>
      "/settings/personal_dictionary/${widget.dictionaryId}";

  Future<void> _openEditor({int? articleId}) async {
    final saved = await context.push<bool>(
      articleId == null
          ? "$_entriesRoute/entry/new"
          : "$_entriesRoute/entry/$articleId",
    );
    if (saved == true && mounted) _reload();
  }

  Future<void> _deleteEntry(PersonalEntry entry) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.delete),
        content: Text(entry.headwords.join(", ")),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.close),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.confirm),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _service.deleteEntry(entry.articleId);
    } catch (e, stackTrace) {
      talker.error(
        "Failed to delete personal entry ${entry.articleId}",
        e,
        stackTrace,
      );
      if (mounted) {
        ToastService.show(e.toString(), context, type: ToastType.error);
      }
      return;
    }

    if (!mounted) return;
    ToastService.show(l10n.personalDictionaryEntryDeleted, context);
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final title = widget.title ?? l10n.personalDictionaryEntries;

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          PopupMenuButton<String>(
            tooltip: l10n.more,
            onSelected: (value) {
              if (value == "import") {
                importPersonalDictionaryDsl(
                  context,
                  _service,
                  widget.dictionaryId,
                ).then((_) {
                  if (mounted) _reload();
                });
              } else if (value == "export") {
                exportPersonalDictionaryDsl(
                  context,
                  _service,
                  widget.dictionaryId,
                  title,
                );
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: "import",
                child: Text(l10n.personalDictionaryImportDsl),
              ),
              PopupMenuItem(
                value: "export",
                child: Text(l10n.personalDictionaryExportDsl),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: l10n.personalDictionaryAddEntry,
        onPressed: () => _openEditor(),
        child: const Icon(Icons.add_rounded),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: l10n.personalDictionarySearchHint,
                    prefixIcon: const Icon(Icons.search_rounded),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onChanged: _onSearchChanged,
                ),
              ),
              Expanded(
                child: FutureBuilder<List<PersonalEntry>>(
                  future: _entriesFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return Center(
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
                              const SizedBox(height: 4),
                              Text(
                                snapshot.error.toString(),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              FilledButton(
                                onPressed: _reload,
                                child: Text(l10n.retry),
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                    final entries = snapshot.data ?? const [];
                    if (entries.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.surfaceContainerHigh,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.auto_stories_outlined,
                                  size: 40,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                              const SizedBox(height: 20),
                              Text(
                                l10n.personalDictionaryNoEntries,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                l10n.personalDictionaryAddEntry,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                    return ListView.builder(
                      padding: EdgeInsets.only(
                        bottom: MediaQuery.viewPaddingOf(context).bottom,
                      ),
                      itemCount: entries.length,
                      itemBuilder: (context, index) {
                        final entry = entries[index];
                        final preview = entry.body
                            .split("\n")
                            .firstWhere(
                              (line) => line.trim().isNotEmpty,
                              orElse: () => "",
                            );
                        return Card(
                          key: ValueKey(entry.articleId),
                          elevation: 0,
                          color: theme.colorScheme.surfaceContainerLow,
                          margin: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          child: ListTile(
                            title: Text(
                              entry.headwords.join(", "),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: preview.isEmpty
                                ? null
                                : Text(
                                    preview,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline_rounded),
                              tooltip: l10n.delete,
                              onPressed: () => _deleteEntry(entry),
                            ),
                            onTap: () =>
                                _openEditor(articleId: entry.articleId),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
