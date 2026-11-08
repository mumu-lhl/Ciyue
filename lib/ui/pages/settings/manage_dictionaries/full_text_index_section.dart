import "package:ciyue/core/app_globals.dart";
import "package:ciyue/core/providers.dart";
import "package:ciyue/models/dictionary_lookup.dart";
import "package:ciyue/repositories/dictionary.dart";
import "package:ciyue/services/full_text_search_service.dart";
import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:material_ui/material_ui.dart";

String _formatBytes(int bytes) {
  if (bytes < 1024) return "$bytes B";
  final kibibytes = bytes / 1024;
  if (kibibytes < 1024) return "${kibibytes.toStringAsFixed(1)} KB";
  final mebibytes = kibibytes / 1024;
  if (mebibytes < 1024) return "${mebibytes.toStringAsFixed(1)} MB";
  return "${(mebibytes / 1024).toStringAsFixed(1)} GB";
}

/// Full-text search index status and management for one dictionary: build,
/// rebuild, delete, and the on-disk size. The dictionary instance is only
/// used for its id, type, and path — building opens its own reader.
///
/// Shared by the dictionary properties page and the index overview page;
/// [title] replaces the row label ("Full-text search index") with, for
/// example, the dictionary's name.
class FullTextIndexSection extends ConsumerStatefulWidget {
  final String path;
  final int id;
  final String? title;

  const FullTextIndexSection({
    super.key,
    required this.path,
    required this.id,
    this.title,
  });

  @override
  ConsumerState<FullTextIndexSection> createState() =>
      _FullTextIndexSectionState();
}

class _FullTextIndexSectionState extends ConsumerState<FullTextIndexSection> {
  LoadedDictionary? _dictionary;
  int? _sizeBytes;
  int? _sizeForIndexed;

  @override
  void initState() {
    super.initState();
    _resolveDictionary();
  }

  Future<void> _resolveDictionary() async {
    final type = await dictionaryListDao.getType(widget.id);
    if (!mounted) return;
    setState(() {
      _dictionary = createLoadedDictionary(path: widget.path, type: type);
    });
  }

  void _maybeLoadSize(FullTextSearchService service, FullTextIndexState state) {
    if (state.status != FullTextIndexStatus.ready) return;
    if (_sizeForIndexed == state.indexed) return;
    _sizeForIndexed = state.indexed;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final size = await service.indexSizeBytes(widget.id);
      if (!mounted || _sizeForIndexed != state.indexed) return;
      setState(() => _sizeBytes = size);
    });
  }

  Future<void> _confirmDeleteIndex(FullTextSearchService service) async {
    final l10n = AppLocalizations.of(context)!;
    final confirm =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(l10n.confirmDelete),
            content: Text(l10n.confirmDeleteMessage(l10n.fullTextIndex)),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(l10n.cancel),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(l10n.delete),
              ),
            ],
          ),
        ) ??
        false;
    if (confirm && mounted) {
      await service.dropDictionary(widget.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dictionary = _dictionary;
    if (dictionary == null) return const SizedBox.shrink();
    final service = ref.watch(fullTextSearchServiceProvider);
    final l10n = AppLocalizations.of(context)!;
    final state = service.stateFor(widget.id);
    _maybeLoadSize(service, state);

    final actions = <Widget>[];
    switch (state.status) {
      case FullTextIndexStatus.notBuilt:
        actions.add(
          TextButton(
            onPressed: () => service.ensureBuilt(dictionary),
            child: Text(l10n.buildFullTextIndex),
          ),
        );
      case FullTextIndexStatus.building:
        actions.add(
          IconButton(
            icon: const Icon(Icons.close),
            tooltip: l10n.cancel,
            onPressed: () => service.cancelBuild(widget.id),
          ),
        );
      case FullTextIndexStatus.ready:
        actions.addAll([
          TextButton(
            onPressed: () => service.rebuildDictionary(dictionary),
            child: Text(l10n.rebuildFullTextIndex),
          ),
          TextButton(
            onPressed: () => _confirmDeleteIndex(service),
            child: Text(l10n.deleteFullTextIndex),
          ),
        ]);
      case FullTextIndexStatus.failed:
        actions.addAll([
          TextButton(
            onPressed: () => service.ensureBuilt(dictionary),
            child: Text(l10n.retry),
          ),
          TextButton(
            onPressed: () => _confirmDeleteIndex(service),
            child: Text(l10n.deleteFullTextIndex),
          ),
        ]);
    }

    final subtitle = switch (state.status) {
      FullTextIndexStatus.notBuilt => Text(l10n.fullTextIndexNotBuilt),
      FullTextIndexStatus.building => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("${l10n.buildingFullTextIndex} ${state.indexed}/${state.total}"),
          const SizedBox(height: 4),
          LinearProgressIndicator(value: state.progress),
        ],
      ),
      FullTextIndexStatus.failed => Text(l10n.fullTextIndexFailed),
      FullTextIndexStatus.ready => Text(
        _sizeBytes == null
            ? "${state.indexed}/${state.total}"
            : "${state.indexed}/${state.total} · ${_formatBytes(_sizeBytes!)}",
      ),
    };

    return ListTile(
      title: Text(widget.title ?? l10n.fullTextIndex),
      subtitle: subtitle,
      trailing: Row(mainAxisSize: MainAxisSize.min, children: actions),
    );
  }
}
