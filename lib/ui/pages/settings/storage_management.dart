import "dart:io";

import "package:ciyue/core/providers.dart";
import "package:ciyue/services/storage_usage.dart";
import "package:ciyue/services/toast.dart";
import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:ciyue/utils.dart";
import "package:ciyue/viewModels/storage_usage.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "package:material_ui/material_ui.dart";

/// Telegram-style storage management: how much space each category uses,
/// with actions to delete what can be rebuilt. Visible on every platform
/// and flavor. On common-flavor Android the old file browser stays
/// available as a sub-page (see [FileManagerPage]).
class StorageManagementPage extends ConsumerStatefulWidget {
  const StorageManagementPage({super.key, this.viewModel});

  final StorageUsageViewModel? viewModel;

  @override
  ConsumerState<StorageManagementPage> createState() =>
      _StorageManagementPageState();
}

class _StorageManagementPageState extends ConsumerState<StorageManagementPage> {
  late final StorageUsageViewModel _viewModel;
  late final bool _ownsViewModel;

  @override
  void initState() {
    super.initState();
    _ownsViewModel = widget.viewModel == null;
    _viewModel =
        widget.viewModel ??
        StorageUsageViewModel(
          onClearFullTextIndex: () =>
              ref.read(fullTextSearchServiceProvider).clearAllIndexes(),
        );
  }

  @override
  void dispose() {
    if (_ownsViewModel) _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locale = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(locale.manageStorage)),
      body: ListenableBuilder(
        listenable: _viewModel,
        builder: (context, child) {
          // The spinner and the error screen are only for the first
          // load: once the list is showing, a refresh (for example
          // after a clear) updates it in place instead of blanking it.
          if (_viewModel.isLoading && _viewModel.usages.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(locale.storageMeasuring),
                ],
              ),
            );
          }
          if (_viewModel.errorMessage != null && _viewModel.usages.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_viewModel.errorMessage!),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _viewModel.refresh,
                    child: Text(locale.retry),
                  ),
                ],
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            children: [
              _buildTotalCard(theme, locale),
              const SizedBox(height: 12),
              _buildCategoriesCard(theme, locale),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _viewModel.clearableBytes > 0
                    ? () => _confirmAndClearAll(context)
                    : null,
                child: Text(locale.storageClearAllCache),
              ),
              if (Platform.isAndroid && !isFullFlavor()) ...[
                const SizedBox(height: 12),
                _buildFileManagerCard(theme, locale),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildTotalCard(ThemeData theme, AppLocalizations locale) {
    return _buildCard(
      theme,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  locale.storageTotalUsed,
                  style: theme.textTheme.titleMedium,
                ),
                Text(
                  formatBytes(_viewModel.totalBytes),
                  style: theme.textTheme.titleMedium,
                ),
              ],
            ),
            if (_viewModel.hasUnknownSizes) ...[
              const SizedBox(height: 4),
              Text(
                locale.storageTotalExcludesUnknown,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 12),
            _buildUsageBar(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildUsageBar(ThemeData theme) {
    final segments = _viewModel.usages
        .where((usage) => (usage.bytes ?? 0) > 0)
        .toList(growable: false);
    if (segments.isEmpty) {
      return Container(
        height: 8,
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(4),
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: SizedBox(
        height: 8,
        child: Row(
          children: [
            for (final usage in segments)
              Flexible(
                flex: usage.bytes! < 1 ? 1 : usage.bytes!,
                child: Container(color: _colorForKind(usage.kind, theme)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoriesCard(ThemeData theme, AppLocalizations locale) {
    final usages = _viewModel.usages;
    return _buildCard(
      theme,
      clip: true,
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: usages.length,
        separatorBuilder: (context, index) => Divider(
          height: 1,
          indent: 52,
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.25),
        ),
        itemBuilder: (context, index) =>
            _buildCategoryTile(theme, locale, usages[index]),
      ),
    );
  }

  Widget _buildCategoryTile(
    ThemeData theme,
    AppLocalizations locale,
    StorageUsage usage,
  ) {
    final bytes = usage.bytes;
    final canClear = usage.clearable && (bytes ?? 0) > 0;
    final subtitle = _subtitleForKind(usage.kind, locale);
    return ListTile(
      leading: Icon(_iconForKind(usage.kind)),
      title: Text(_titleForKind(usage.kind, locale)),
      subtitle: subtitle == null ? null : Text(subtitle),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(bytes == null ? locale.storageSizeUnknown : formatBytes(bytes)),
          if (canClear)
            TextButton(
              onPressed: () => _confirmAndClear(context, usage),
              child: Text(locale.storageClearCache),
            ),
        ],
      ),
      onTap: switch (usage.kind) {
        StorageCategoryKind.dictionaries => () => context.push(
          "/settings/dictionaries",
        ),
        StorageCategoryKind.audioPacks => () => context.push("/settings/audio"),
        _ => null,
      },
    );
  }

  Widget _buildFileManagerCard(ThemeData theme, AppLocalizations locale) {
    return _buildCard(
      theme,
      child: ListTile(
        leading: const Icon(Icons.folder),
        title: Text(locale.storageFileManager),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () => context.push("/settings/storage_management/file_manager"),
      ),
    );
  }

  Future<void> _confirmAndClear(
    BuildContext context,
    StorageUsage usage,
  ) async {
    final locale = AppLocalizations.of(context)!;
    final confirmed = await _showClearConfirmDialog(
      context,
      locale.storageClearConfirmMessage(formatBytes(usage.bytes ?? 0)),
    );
    if (confirmed && context.mounted) {
      await _viewModel.clearCategory(usage.kind);
      if (context.mounted) {
        ToastService.show(locale.storageCleared, context);
      }
    }
  }

  Future<void> _confirmAndClearAll(BuildContext context) async {
    final locale = AppLocalizations.of(context)!;
    final confirmed = await _showClearConfirmDialog(
      context,
      locale.storageClearConfirmMessage(formatBytes(_viewModel.clearableBytes)),
    );
    if (confirmed && context.mounted) {
      await _viewModel.clearAllCache();
      if (context.mounted) {
        ToastService.show(locale.storageCleared, context);
      }
    }
  }

  Future<bool> _showClearConfirmDialog(
    BuildContext context,
    String message,
  ) async {
    final locale = AppLocalizations.of(context)!;
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(locale.storageClearConfirmTitle),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(locale.cancel),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(locale.delete),
              ),
            ],
          ),
        ) ??
        false;
  }

  Widget _buildCard(
    ThemeData theme, {
    required Widget child,
    bool clip = false,
  }) {
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerLow,
      clipBehavior: clip ? Clip.antiAlias : Clip.none,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: child,
    );
  }
}

IconData _iconForKind(StorageCategoryKind kind) {
  return switch (kind) {
    StorageCategoryKind.dictionaries => Icons.book,
    StorageCategoryKind.fullTextIndex => Icons.search,
    StorageCategoryKind.dictionaryIndexCache => Icons.table_rows,
    StorageCategoryKind.pronunciationCache => Icons.audiotrack,
    StorageCategoryKind.otherCache => Icons.cached,
    StorageCategoryKind.database => Icons.storage,
    StorageCategoryKind.audioPacks => Icons.library_music,
    StorageCategoryKind.chatImages => Icons.image,
  };
}

String _titleForKind(StorageCategoryKind kind, AppLocalizations locale) {
  return switch (kind) {
    StorageCategoryKind.dictionaries => locale.storageDictionaries,
    StorageCategoryKind.fullTextIndex => locale.fullTextIndex,
    StorageCategoryKind.dictionaryIndexCache =>
      locale.storageDictionaryIndexCache,
    StorageCategoryKind.pronunciationCache => locale.storagePronunciationCache,
    StorageCategoryKind.otherCache => locale.storageOtherCache,
    StorageCategoryKind.database => locale.storageAppDatabase,
    StorageCategoryKind.audioPacks => locale.storageAudioPacks,
    StorageCategoryKind.chatImages => locale.storageChatImages,
  };
}

String? _subtitleForKind(StorageCategoryKind kind, AppLocalizations locale) {
  return switch (kind) {
    StorageCategoryKind.fullTextIndex ||
    StorageCategoryKind.dictionaryIndexCache =>
      locale.storageRebuildsAutomatically,
    StorageCategoryKind.pronunciationCache => locale.storageDownloadsAgain,
    _ => null,
  };
}

Color _colorForKind(StorageCategoryKind kind, ThemeData theme) {
  return switch (kind) {
    StorageCategoryKind.dictionaries => theme.colorScheme.primary,
    StorageCategoryKind.fullTextIndex => theme.colorScheme.secondary,
    StorageCategoryKind.dictionaryIndexCache => theme.colorScheme.tertiary,
    StorageCategoryKind.pronunciationCache => Colors.orange,
    StorageCategoryKind.otherCache => theme.colorScheme.outline,
    StorageCategoryKind.database => Colors.blue,
    StorageCategoryKind.audioPacks => Colors.purple,
    StorageCategoryKind.chatImages => Colors.teal,
  };
}
