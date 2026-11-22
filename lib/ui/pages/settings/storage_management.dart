import "dart:io";
import "dart:math" as math;

import "package:ciyue/core/providers.dart";
import "package:ciyue/services/storage_usage.dart";
import "package:ciyue/services/toast.dart";
import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:ciyue/utils.dart";
import "package:ciyue/viewModels/storage_usage.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "package:material_ui/material_ui.dart";

/// Telegram-style storage management: a donut chart of how much space
/// each category uses, one selectable row per category, and a single
/// clear button for the selected caches. Visible on every platform and
/// flavor. On common-flavor Android the old file browser stays
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
          personalDictionaryEstimates: () => loadPersonalDictionaryEstimates(
            ref.read(personalDictionaryServiceProvider),
          ),
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
              _buildDonutSection(theme, locale),
              const SizedBox(height: 12),
              _buildCategoriesCard(theme, locale),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _viewModel.selectedClearableBytes > 0
                    ? () => _confirmAndClearSelected(context)
                    : null,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text(
                  "${locale.storageClearCache} "
                  "${formatBytes(_viewModel.selectedClearableBytes)}",
                ),
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

  Widget _buildDonutSection(ThemeData theme, AppLocalizations locale) {
    final formattedTotal = formatBytes(_viewModel.totalBytes);
    final split = formattedTotal.lastIndexOf(" ");
    final totalValue = split >= 0
        ? formattedTotal.substring(0, split)
        : formattedTotal;
    final totalUnit = split >= 0 ? formattedTotal.substring(split + 1) : "";
    return Column(
      children: [
        const SizedBox(height: 8),
        _StorageDonut(
          usages: _viewModel.usages,
          totalBytes: _viewModel.totalBytes,
          totalValue: totalValue,
          totalUnit: totalUnit,
        ),
        const SizedBox(height: 16),
        Text(locale.storageUsage, style: theme.textTheme.titleLarge),
        if (_viewModel.hasUnknownSizes) ...[
          const SizedBox(height: 4),
          Text(
            locale.storageTotalExcludesUnknown,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
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
        itemBuilder: (context, index) {
          final usage = usages[index];
          final tile = _buildCategoryTile(theme, locale, usage);
          // The database file is shared by every personal dictionary, so
          // the category cannot be split exactly; the per-dictionary
          // content estimates go under it as a breakdown instead.
          if (usage.kind != StorageCategoryKind.database ||
              _viewModel.personalDictionaryEstimates.isEmpty) {
            return tile;
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [tile, _buildPersonalDictionaryBreakdown(theme, locale)],
          );
        },
      ),
    );
  }

  /// Per-dictionary breakdown under the database category: each personal
  /// dictionary's estimated content size with its entry count, plus the
  /// note that the numbers are estimates sharing one database file.
  Widget _buildPersonalDictionaryBreakdown(
    ThemeData theme,
    AppLocalizations locale,
  ) {
    final estimates = _viewModel.personalDictionaryEstimates;
    return Padding(
      padding: const EdgeInsets.fromLTRB(52, 2, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            locale.storagePersonalDictionaries,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          for (final estimate in estimates)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      estimate.title,
                      style: theme.textTheme.bodyMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    "${formatBytes(estimate.estimatedBytes)} · ${locale.personalDictionaryEntryCount(estimate.entryCount)}",
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 4),
          Text(
            locale.storagePersonalDictionarySizeEstimated,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryTile(
    ThemeData theme,
    AppLocalizations locale,
    StorageUsage usage,
  ) {
    final bytes = usage.bytes;
    final color = _colorForKind(usage.kind);
    final subtitle = _subtitleForKind(usage.kind, locale);
    final total = _viewModel.totalBytes;
    final share = bytes != null && total > 0 ? bytes / total : null;
    final navigates = switch (usage.kind) {
      StorageCategoryKind.dictionaries ||
      StorageCategoryKind.audioPacks => true,
      _ => false,
    };
    return ListTile(
      leading: usage.clearable
          ? _SelectionCircle(
              color: color,
              selected: _viewModel.isSelected(usage.kind),
            )
          : _KindCircle(color: color, icon: _iconForKind(usage.kind)),
      title: Row(
        children: [
          Flexible(
            child: Text(
              _titleForKind(usage.kind, locale),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (share != null) ...[
            const SizedBox(width: 6),
            Text(
              _percentLabel(share),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
      subtitle: subtitle == null ? null : Text(subtitle),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            bytes == null ? locale.storageSizeUnknown : formatBytes(bytes),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: bytes == null
                  ? theme.colorScheme.onSurfaceVariant
                  : theme.colorScheme.primary,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (navigates) ...[
            const SizedBox(width: 4),
            Icon(
              Icons.chevron_right_rounded,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ],
      ),
      onTap: usage.clearable
          ? () => _viewModel.toggleSelection(usage.kind)
          : switch (usage.kind) {
              StorageCategoryKind.dictionaries => () => context.push(
                "/settings/dictionaries",
              ),
              StorageCategoryKind.audioPacks => () => context.push(
                "/settings/audio",
              ),
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

  Future<void> _confirmAndClearSelected(BuildContext context) async {
    final locale = AppLocalizations.of(context)!;
    final confirmed = await _showClearConfirmDialog(
      context,
      locale.storageClearConfirmMessage(
        formatBytes(_viewModel.selectedClearableBytes),
      ),
    );
    if (confirmed && context.mounted) {
      await _viewModel.clearSelectedCache();
      if (context.mounted) {
        await ToastService.show(locale.storageCleared, context);
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

/// The donut chart at the top of the storage page: one segment per
/// measurable category, the total in the center. Drawn with a
/// [CustomPainter] so the page needs no chart dependency.
class _StorageDonut extends StatelessWidget {
  const _StorageDonut({
    required this.usages,
    required this.totalBytes,
    required this.totalValue,
    required this.totalUnit,
  });

  final List<StorageUsage> usages;
  final int totalBytes;
  final String totalValue;
  final String totalUnit;

  static const _size = 240.0;
  static const _strokeWidth = 36.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final segments = <_DonutSegment>[];
    for (final usage in usages) {
      final bytes = usage.bytes ?? 0;
      if (bytes <= 0 || totalBytes <= 0) continue;
      final share = bytes / totalBytes;
      segments.add(
        _DonutSegment(
          sweep: share * math.pi * 2,
          color: _colorForKind(usage.kind),
          // Tiny slices have no room for a label on the arc, like
          // Telegram's donut.
          label: share >= 0.07 ? _percentLabel(share) : null,
        ),
      );
    }
    return SizedBox(
      width: _size,
      height: _size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size(_size, _size),
            painter: _StorageDonutPainter(
              segments: segments,
              ringColor: theme.colorScheme.surfaceContainerHighest,
              labelStyle: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                totalValue,
                style: theme.textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (totalUnit.isNotEmpty)
                Text(
                  totalUnit,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DonutSegment {
  const _DonutSegment({required this.sweep, required this.color, this.label});

  final double sweep;
  final Color color;
  final String? label;
}

class _StorageDonutPainter extends CustomPainter {
  _StorageDonutPainter({
    required this.segments,
    required this.ringColor,
    this.labelStyle,
  });

  final List<_DonutSegment> segments;
  final Color ringColor;
  final TextStyle? labelStyle;

  static const _strokeWidth = _StorageDonut._strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - _strokeWidth) / 2;
    final ringPaint = Paint()
      ..color = ringColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = _strokeWidth;
    canvas.drawCircle(center, radius, ringPaint);
    if (segments.isEmpty) return;
    // A small gap between segments, like Telegram's donut.
    const gap = 0.02;
    var start = -math.pi / 2;
    for (final segment in segments) {
      var sweep = segment.sweep;
      if (segments.length > 1) sweep -= gap;
      if (sweep < 0) sweep = 0;
      if (sweep > 0) {
        final paint = Paint()
          ..color = segment.color
          ..style = PaintingStyle.stroke
          ..strokeWidth = _strokeWidth;
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: radius),
          start,
          sweep,
          false,
          paint,
        );
        if (segment.label != null) {
          final mid = start + sweep / 2;
          final labelOffset = Offset(
            center.dx + math.cos(mid) * radius,
            center.dy + math.sin(mid) * radius,
          );
          final textPainter = TextPainter(
            text: TextSpan(text: segment.label, style: labelStyle),
            textDirection: TextDirection.ltr,
          )..layout();
          textPainter.paint(
            canvas,
            labelOffset - Offset(textPainter.width / 2, textPainter.height / 2),
          );
        }
      }
      start += segment.sweep;
    }
  }

  @override
  bool shouldRepaint(_StorageDonutPainter oldDelegate) {
    if (segments.length != oldDelegate.segments.length) return true;
    for (var i = 0; i < segments.length; i++) {
      if (segments[i].sweep != oldDelegate.segments[i].sweep ||
          segments[i].color != oldDelegate.segments[i].color ||
          segments[i].label != oldDelegate.segments[i].label) {
        return true;
      }
    }
    return ringColor != oldDelegate.ringColor;
  }
}

/// The check circle on a clearable row: filled with the category color
/// and a white check when the row is selected for clearing, an outline
/// in the category color when it is not.
class _SelectionCircle extends StatelessWidget {
  const _SelectionCircle({required this.color, required this.selected});

  final Color color;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? color : Colors.transparent,
        border: selected ? null : Border.all(color: color, width: 2),
      ),
      child: selected
          ? const Icon(Icons.check, size: 18, color: Colors.white)
          : null,
    );
  }
}

/// The leading circle on a size-only row: the category color with its
/// icon, marking a row that is not selectable for clearing.
class _KindCircle extends StatelessWidget {
  const _KindCircle({required this.color, required this.icon});

  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      child: Icon(icon, size: 16, color: Colors.white),
    );
  }
}

/// Percentage of the measured total, rounded. A non-empty slice under
/// 1% reads "<1%" instead of rounding to "0%".
String _percentLabel(double share) {
  if (share > 0 && share < 0.01) return "<1%";
  return "${(share * 100).round()}%";
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

/// One fixed color per category (Telegram-like palette), shared by the
/// donut segments and the row circles. Fixed rather than theme-derived
/// so the segments stay distinct in both light and dark themes.
Color _colorForKind(StorageCategoryKind kind) {
  return switch (kind) {
    StorageCategoryKind.dictionaries => const Color(0xFF26A69A),
    StorageCategoryKind.fullTextIndex => const Color(0xFFFF7043),
    StorageCategoryKind.dictionaryIndexCache => const Color(0xFF42A5F5),
    StorageCategoryKind.pronunciationCache => const Color(0xFF66BB6A),
    StorageCategoryKind.otherCache => const Color(0xFF9E9E9E),
    StorageCategoryKind.database => const Color(0xFFAB47BC),
    StorageCategoryKind.audioPacks => const Color(0xFFEC407A),
    StorageCategoryKind.chatImages => const Color(0xFF26C6DA),
  };
}
