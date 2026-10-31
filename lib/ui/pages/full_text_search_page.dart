import "dart:async";

import "package:ciyue/core/providers.dart";
import "package:ciyue/models/dictionary_lookup.dart";
import "package:ciyue/repositories/dictionary.dart";
import "package:ciyue/services/full_text_index_store.dart";
import "package:ciyue/services/full_text_search.dart";
import "package:ciyue/services/full_text_search_service.dart";
import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "package:material_ui/material_ui.dart";
import "package:path/path.dart" as p;

/// Searches inside dictionary definitions, across the active dictionary
/// group. Indexes are built lazily in the background on first use; a
/// dictionary still building simply contributes no results until ready.
class FullTextSearchPage extends ConsumerStatefulWidget {
  final String initialQuery;

  const FullTextSearchPage({super.key, this.initialQuery = ""});

  @override
  ConsumerState<FullTextSearchPage> createState() => _FullTextSearchPageState();
}

class _FullTextSearchPageState extends ConsumerState<FullTextSearchPage> {
  static const _searchDebounce = Duration(milliseconds: 300);

  late final TextEditingController _controller;
  Timer? _debounce;
  int _searchGen = 0;
  List<FullTextHit>? _results;
  bool _searching = false;

  /// Key of the last search run: query + ready dictionary ids. When the
  /// ready set changes (a build finishes), the search re-runs so results
  /// from the newly ready dictionary appear without retyping.
  String _lastSearchKey = "";

  /// Dictionaries this page session already asked to build, so a failed
  /// build is retried only from its retry button, not on every rebuild.
  final Set<int> _autoStarted = {};

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialQuery);
    _controller.addListener(_onQueryChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onQueryChanged() {
    _debounce?.cancel();
    _debounce = Timer(_searchDebounce, () {
      if (mounted) _runSearch();
    });
  }

  String _dictionaryTitle(LoadedDictionary dictionary) {
    try {
      final title = dictionary.title;
      if (title.isNotEmpty) return title;
    } catch (_) {
      // Title is late-initialized; a dictionary that never loaded metadata
      // has none yet.
    }
    return p.basename(dictionary.path);
  }

  List<LoadedDictionary> _dictionaries() {
    return [for (final id in dictManager.dictIds) dictManager.dicts[id]]
        .whereType<LoadedDictionary>()
        .toList(growable: false);
  }

  Future<void> _runSearch() async {
    final gen = ++_searchGen;
    final query = _controller.text.trim();
    if (query.isEmpty) {
      if (!mounted) return;
      setState(() {
        _results = null;
        _searching = false;
      });
      return;
    }
    setState(() => _searching = true);
    final service = ref.read(fullTextSearchServiceProvider);
    final readyIds = _dictionaries()
        .where(
          (d) => service.stateFor(d.id).status == FullTextIndexStatus.ready,
        )
        .map((d) => d.id)
        .join(",");
    _lastSearchKey = "$query|$readyIds";
    final hits = await service.search(query);
    if (!mounted || gen != _searchGen) return;
    setState(() {
      _results = hits;
      _searching = false;
    });
  }

  void _maybeStartBuilds(
    FullTextSearchService service,
    List<LoadedDictionary> dictionaries,
  ) {
    for (final dictionary in dictionaries) {
      if (_autoStarted.contains(dictionary.id)) continue;
      if (service.stateFor(dictionary.id).status !=
          FullTextIndexStatus.notBuilt) {
        continue;
      }
      _autoStarted.add(dictionary.id);
      unawaited(service.ensureBuilt(dictionary));
    }
  }

  void _maybeRerunSearch(
    FullTextSearchService service,
    List<LoadedDictionary> dictionaries,
  ) {
    final query = _controller.text.trim();
    if (query.isEmpty) return;
    final readyIds = dictionaries
        .where(
          (d) => service.stateFor(d.id).status == FullTextIndexStatus.ready,
        )
        .map((d) => d.id)
        .join(",");
    if ("$query|$readyIds" == _lastSearchKey) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _runSearch();
    });
  }

  @override
  Widget build(BuildContext context) {
    // Rebuilds when the group changes or an index build reports progress.
    ref.watch(dictManagerModelProvider);
    final service = ref.watch(fullTextSearchServiceProvider);
    final l10n = AppLocalizations.of(context)!;
    final dictionaries = _dictionaries();

    _maybeStartBuilds(service, dictionaries);
    _maybeRerunSearch(service, dictionaries);

    final query = _controller.text.trim();
    final pending = dictionaries.where(
      (d) => service.stateFor(d.id).status != FullTextIndexStatus.ready,
    );

    Widget statusRow(LoadedDictionary dictionary) {
      final state = service.stateFor(dictionary.id);
      final title = _dictionaryTitle(dictionary);
      switch (state.status) {
        case FullTextIndexStatus.building:
          return ListTile(
            title: Text(title),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "${l10n.buildingFullTextIndex} "
                  "${state.indexed}/${state.total}",
                ),
                const SizedBox(height: 4),
                LinearProgressIndicator(value: state.progress),
              ],
            ),
            trailing: IconButton(
              icon: const Icon(Icons.close),
              tooltip: l10n.cancel,
              onPressed: () => service.cancelBuild(dictionary.id),
            ),
          );
        case FullTextIndexStatus.failed:
          return ListTile(
            title: Text(title),
            subtitle: Text(l10n.fullTextIndexFailed),
            trailing: TextButton(
              onPressed: () => service.ensureBuilt(dictionary),
              child: Text(l10n.retry),
            ),
          );
        case FullTextIndexStatus.notBuilt:
          return ListTile(
            title: Text(title),
            trailing: TextButton(
              onPressed: () {
                _autoStarted.add(dictionary.id);
                service.ensureBuilt(dictionary);
              },
              child: Text(l10n.buildFullTextIndex),
            ),
          );
        case FullTextIndexStatus.ready:
          return const SizedBox.shrink();
      }
    }

    final sections = <Widget>[];
    if (_results != null) {
      final grouped = <int, List<FullTextHit>>{};
      for (final hit in _results!) {
        grouped.putIfAbsent(hit.dictionaryId, () => []).add(hit);
      }
      for (final entry in grouped.entries) {
        final dictionary = dictManager.dicts[entry.key];
        final header = dictionary == null ? null : _dictionaryTitle(dictionary);
        if (header != null) {
          sections.add(
            Padding(
              padding: const EdgeInsetsDirectional.only(
                start: 16,
                top: 12,
                bottom: 4,
              ),
              child: Text(
                header,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.secondary
                      .withValues(alpha: 0.7),
                ),
              ),
            ),
          );
        }
        for (final hit in entry.value) {
          sections.add(
            ListTile(
              title: Text(hit.headword),
              subtitle: _SnippetText(marked: hit.snippet),
              onTap: () {
                context.push(
                  "/word/${Uri.encodeComponent(hit.headword)}"
                  "?dictId=${hit.dictionaryId}",
                );
              },
            ),
          );
        }
      }
    }

    final showHint = query.isEmpty && _results == null;
    final showNoResult =
        query.isNotEmpty &&
        !_searching &&
        _results != null &&
        _results!.isEmpty;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.fullTextSearch)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _controller,
              autofocus: widget.initialQuery.isEmpty,
              decoration: InputDecoration(
                hintText: l10n.search,
                prefixIcon: const Icon(Icons.search),
                suffixIcon: query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => _controller.clear(),
                      ),
                border: const OutlineInputBorder(),
              ),
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _runSearch(),
            ),
          ),
          // One scrollable list for everything below the field: with many
          // dictionaries pending, fixed status rows above an Expanded
          // list would overflow the column.
          Expanded(
            child: ListView(
              children: [
                ...pending.map(statusRow),
                if (_searching)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                if (showHint)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      l10n.fullTextSearchHint,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.secondary
                            .withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                if (showNoResult)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(l10n.noResult),
                  ),
                ...sections,
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SnippetText extends StatelessWidget {
  final String marked;

  const _SnippetText({required this.marked});

  @override
  Widget build(BuildContext context) {
    final segments = parseSnippet(marked);
    final defaultStyle = DefaultTextStyle.of(context).style;
    final matchStyle = defaultStyle.copyWith(
      fontWeight: FontWeight.bold,
      color: Theme.of(context).colorScheme.primary,
    );
    return RichText(
      maxLines: 3,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(
        style: defaultStyle,
        children: [
          for (final segment in segments)
            TextSpan(
              text: segment.text,
              style: segment.isMatch ? matchStyle : null,
            ),
        ],
      ),
    );
  }
}
